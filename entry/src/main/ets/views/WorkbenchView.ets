import { AppTheme, LINE_HEIGHT } from '../theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HomeSnapshotService } from '../data/HomeSnapshotService';
import { HomeSnapshot } from '../model/HomeSnapshot';
import { BodyReading, HomeSummary, formatHitRate, todayLabel } from '../model/HomeModel';
import { NoteListItem } from '../note/NoteListItem';
import { AgendaItem, AgendaKind, buildAgenda } from '../home/AgendaMapper';
import { HomeLayoutStore } from '../settings/HomeLayoutStore';
import { HomeBlockKind, homeBlockTitle, normalizeBlockOrder } from '../model/HomeBlock';
import { TabKey } from '../navigation/TabItems';
import {
  activeTab,
  requestTabRefresh,
  subscribeTabRefresh,
  unsubscribeTabRefresh
} from '../app/TabRefreshBus';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';
import { setBackHandler } from '../app/BackGuard';
import { ROUTES } from '../navigation/Routes';
import {
  NoteDetailParams,
  NoteEditParams,
  PlanNodeParams,
  PredictionDetailParams,
  PredictionSettleParams,
  RelationDetailParams
} from '../navigation/RouteParams';
import { AgendaCard } from './dashboard/AgendaCard';
import { RecentNotesCard } from './dashboard/RecentNotesCard';
import { ModuleRail, ModuleStatus } from './dashboard/ModuleRail';
import { ReadingCard } from '../components/ReadingCard';
import { SectionCard } from '../components/SectionCard';
import { WelcomeCard } from '../components/WelcomeCard';
import { ReviewPromptPanel } from '../components/ReviewPromptPanel';
import { QuickCaptureBar } from '../components/QuickCaptureBar';
import { HomeQuickMenuPanel } from '../components/HomeQuickMenuPanel';
import { appHealth, isDatabaseUnsupported } from '../app/AppHealth';
import { consumeJsonIssues } from '../db/SafeJson';
import { DbHelper } from '../db/DbHelper';
import { DebugFaults } from '../app/DebugFaults';
import { previewStore } from '../preview/PreviewStore';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { PREVIEW_RELATION_ITEMS } from '../preview/PreviewData';
import { PREVIEW_BANNER } from '../preview/PreviewMode';
import { OnboardingStore } from '../settings/OnboardingStore';
import { SettingsStore } from '../settings/SettingsStore';
import { AppSettings, defaultAppSettings } from '../settings/AppSettings';
import { shouldEnterSubtraction, WriteSample } from '../analysis/meta/SubtractionMode';
import { PlanItem } from '../model/PlanItem';
import { PlanNode } from '../model/PlanNode';
import { PlanNodeStatus } from '../model/PlanStatus';
import { ReviewPeriod } from '../review';
import { formatClock } from '../analysis/time/DateTime';

const ONE_MINUTE_MS = 60000;

/** Placeholder readings used when the reading query fails, so the block never renders empty. */
function placeholderReadings(): BodyReading[] {
  return [
    { label: '睡眠', value: '--', unit: ' 小时' },
    { label: '运动', value: '--', unit: ' 次' },
    { label: '速记', value: '--', unit: ' 条' }
  ];
}

/**
 * Workbench tab: a fixed date-and-time header, one small button that opens the layout panel, and
 * the six sortable blocks in one vertical list. The identity band, the settings shortcut and the
 * whole-page slide were removed; settings now live behind the panel and inside the mine tab.
 */
@ComponentV2
export struct WorkbenchView {
  @Require @Param pathStack: NavPathStack;
  /** Cross-tab jumps raised by the blocks; the shell performs the actual switch. */
  @Event onSwitchTab: (key: TabKey) => void = () => {
  };
  @Local today: string = todayLabel();
  @Local clock: string = formatClock(Date.now());
  @Local order: HomeBlockKind[] = normalizeBlockOrder([]);
  @Local sortMode: boolean = false;
  @Local panelVisible: boolean = false;
  @Local readings: BodyReading[] = [];
  @Local recentNotes: NoteListItem[] = [];
  @Local summary: HomeSummary = {
    totalNotes: 0, todayNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0, hitRate: 0,
    unreviewedDecisions: 0, totalAnchors: 0, totalRelations: 0
  };
  @Local agenda: AgendaItem[] = [];
  @Local agendaPending: number = 0;
  @Local agendaReply: number = 0;
  @Local planOpenCount: number = 0;
  @Local planNodeCount: number = 0;
  @Local dataVersion: number = 0;
  @Local isLoading: boolean = true;
  @Local loadFailed: boolean = false;
  /** True when only part of the snapshot loaded; the banner stays softer than a hard failure. */
  @Local dataPartial: boolean = false;
  @Local isPreview: boolean = false;
  @Local dbBlocked: boolean = false;
  @Local dbMessage: string = '';
  @Local dataNotice: string = '';
  @Local encryptionNotice: string = '';
  @Local showWelcome: boolean = false;
  @Local promptVisible: boolean = true;
  @Local appSettings: AppSettings = defaultAppSettings();
  @Local promptRefusals: number = 0;
  @Local subtractionExited: boolean = false;
  private snapshotService: HomeSnapshotService | null = null;
  private layoutStore: HomeLayoutStore | null = null;
  private clockTimer: number = -1;
  private tabListener: (() => void) | null = null;
  private backHandler: (() => boolean) | null = null;
  private lastPushAt: number = 0;
  private loadToken: number = 0;

  aboutToAppear(): void {
    this.startClock();
    this.loadSettings();
    this.loadLayout();
    this.loadWelcome();
    if (this.tabListener === null) {
      this.tabListener = () => {
        this.onTabActivated();
      };
      subscribeTabRefresh(TabKey.WORKBENCH, this.tabListener);
    }
    if (this.backHandler === null) {
      this.backHandler = () => {
        return this.handleBack();
      };
      setBackHandler(this.backHandler);
    }
    this.openSnapshot();
  }

  aboutToDisappear(): void {
    if (this.tabListener !== null) {
      unsubscribeTabRefresh(TabKey.WORKBENCH, this.tabListener);
      this.tabListener = null;
    }
    if (this.backHandler !== null) {
      setBackHandler(null);
      this.backHandler = null;
    }
    if (this.clockTimer >= 0) {
      clearInterval(this.clockTimer);
      this.clockTimer = -1;
    }
  }

  /** Minute timer: the header stays correct without any data reload. */
  private startClock(): void {
    this.updateClock();
    if (this.clockTimer < 0) {
      this.clockTimer = setInterval(() => {
        this.updateClock();
      }, ONE_MINUTE_MS);
    }
  }

  private updateClock(): void {
    this.today = todayLabel();
    this.clock = formatClock(Date.now());
  }

  private onTabActivated(): void {
    if (activeTab() !== TabKey.WORKBENCH) {
      return;
    }
    // A panel left open while another tab was shown does not reappear on return.
    this.panelVisible = false;
    this.sortMode = false;
    // Settings can change while this tab is hidden; reload so subtraction and monitor rules follow.
    this.loadSettings();
    this.updateClock();
    this.refresh();
  }

  /** Page-level back: close the panel or leave sort mode before the app exits. */
  private handleBack(): boolean {
    if (activeTab() !== TabKey.WORKBENCH) {
      return false;
    }
    if (this.panelVisible) {
      this.setPanel(false);
      return true;
    }
    if (this.sortMode) {
      this.exitSortMode();
      return true;
    }
    return false;
  }

  private async loadLayout(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      this.layoutStore = await HomeLayoutStore.open(context);
      this.order = await this.layoutStore.load();
    } catch (error) {
      this.order = normalizeBlockOrder([]);
    }
  }

  private async loadSettings(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const store = await SettingsStore.open(context);
      this.appSettings = await store.load();
    } catch (error) {
    }
  }

  private async loadWelcome(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const onboarding = await OnboardingStore.open(context);
      this.showWelcome = !(await onboarding.isSeen());
    } catch (error) {
      this.showWelcome = true;
    }
  }

  private async openSnapshot(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.snapshotService = await HomeSnapshotService.open(context);
      await this.refresh();
    } catch (error) {
      const failure = error as BusinessError;
      const code: number = failure.code ?? 0;
      if (isDatabaseUnsupported(code)) {
        this.loadPreview();
        return;
      }
      appHealth.markFailed(failure.message ?? '');
      this.dbMessage = failure.message ?? '';
      this.dbBlocked = true;
      this.isLoading = false;
    }
  }

  /** Previewer and capability-missing runs keep the whole workbench usable with demo data. */
  private loadPreview(): void {
    this.isPreview = true;
    this.readings = previewStore.previewReadings();
    this.recentNotes = previewStore.recentNotes(20);
    this.summary = previewStore.homeSummary();
    const primary = planPreviewStore.primary();
    const nodes: PlanNode[] = primary === null ? [] : planPreviewStore.nodes(primary.id);
    const items: PlanItem[] = [];
    for (const node of nodes) {
      for (const item of planPreviewStore.listItems(node.id)) {
        items.push(item);
      }
    }
    const agenda = buildAgenda({
      plans: planPreviewStore.list(),
      nodes: nodes,
      items: items,
      predictions: previewStore.listPredictions(null),
      relations: PREVIEW_RELATION_ITEMS,
      todayNotes: this.recentNotes
    });
    this.agenda = agenda.items;
    this.agendaPending = agenda.pendingCount;
    this.agendaReply = agenda.replyCount;
    this.planNodeCount = nodes.length;
    this.planOpenCount = nodes.filter((node: PlanNode) => node.status === PlanNodeStatus.OPEN).length;
    this.dataVersion += 1;
    this.isLoading = false;
    this.loadFailed = false;
    this.dataPartial = false;
    this.dbBlocked = false;
  }

  async refresh(): Promise<void> {
    if (this.dbBlocked) {
      return;
    }
    if (this.isPreview) {
      this.loadPreview();
      return;
    }
    if (this.snapshotService === null) {
      this.isLoading = false;
      return;
    }
    const token = ++this.loadToken;
    this.isLoading = true;
    try {
      const snapshot: HomeSnapshot = await this.snapshotService.load();
      if (token !== this.loadToken) {
        return;
      }
      this.applySnapshot(snapshot);
      this.loadFailed = false;
      this.dataPartial = snapshot.partial;
      this.dataNotice = consumeJsonIssues() > 0 ? '部分记录格式异常，已跳过' : '';
      const context = this.getUIContext().getHostContext();
      this.encryptionNotice = context !== undefined &&
        (DbHelper.usesPlaintextFallback() || DebugFaults.encryptionFallback(context)) ?
        '数据库未能加密，记录以明文保存在本机；建议更新系统或重装应用' : '';
      appHealth.markReady();
    } catch (error) {
      if (token !== this.loadToken) {
        return;
      }
      this.loadFailed = true;
      this.getUIContext().getPromptAction().showToast({ message: '数据加载失败，请稍后重试' });
    } finally {
      if (token === this.loadToken) {
        this.isLoading = false;
      }
    }
  }

  private applySnapshot(snapshot: HomeSnapshot): void {
    this.readings = snapshot.readings.length > 0 ? snapshot.readings : placeholderReadings();
    this.recentNotes = snapshot.recentNotes;
    this.summary = snapshot.summary;
    this.agenda = snapshot.agenda;
    this.agendaPending = snapshot.agendaPending;
    this.agendaReply = snapshot.agendaReply;
    this.planOpenCount = snapshot.planOpenCount;
    this.planNodeCount = snapshot.planNodeCount;
    this.dataVersion += 1;
  }

  private retryDatabase(): void {
    appHealth.reset();
    this.snapshotService = null;
    this.dbBlocked = false;
    this.dbMessage = '';
    this.isLoading = true;
    this.openSnapshot();
  }

  private exitApplication(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      (context as common.UIAbilityContext).terminateSelf();
    }
  }

  private dismissWelcome(): void {
    this.showWelcome = false;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    OnboardingStore.open(context).then((store: OnboardingStore) => {
      store.markSeen().catch(() => {
      });
    }).catch(() => {
    });
  }

  private afterCapture(): void {
    this.subtractionExited = true;
    this.promptRefusals = 0;
    notifyHomeRefresh();
    this.refresh();
    requestTabRefresh(TabKey.PREDICTION);
  }

  /** Recent writes as subtraction-mode samples; only the visible notes are considered. */
  private recentWrites(): WriteSample[] {
    return this.recentNotes.map((note: NoteListItem): WriteSample => {
      return { kind: 'scene', chars: note.summary.length, hour: new Date(note.timestamp).getHours() };
    });
  }

  /** Subtraction mode: demo switch, or the end-side heuristic when enabled. */
  private isSubtraction(): boolean {
    if (this.subtractionExited) {
      return false;
    }
    if (this.appSettings.subtractionDemo) {
      return true;
    }
    if (!this.appSettings.subtractionEnabled) {
      return false;
    }
    return shouldEnterSubtraction({
      writes: this.recentWrites(),
      prompts: { shown: this.promptRefusals + 1, refused: this.promptRefusals }
    });
  }

  private reviewPromptHint(): string {
    if (this.appSettings.monitorPaused) {
      return '提示已暂停，可在设置中恢复';
    }
    if (this.isSubtraction()) {
      return '当前处于减法模式，提示暂时收起';
    }
    return '本期提示已收起';
  }

  private guardedPush(name: string, param: Object | null, onPop: () => void): void {
    const now = Date.now();
    if (now - this.lastPushAt < 600) {
      return;
    }
    this.lastPushAt = now;
    this.pathStack.pushPathByName(name, param, onPop);
  }

  private openNoteEditor(): void {
    const params: NoteEditParams = { templateId: null };
    this.guardedPush(ROUTES.NOTE_EDIT, params, () => {
      this.refresh();
    });
  }

  private openNoteDetail(noteId: string): void {
    const params: NoteDetailParams = { noteId: noteId };
    this.guardedPush(ROUTES.NOTE_DETAIL, params, () => {
      this.refresh();
    });
  }

  private openPredictionDetail(predictionId: string): void {
    const params: PredictionDetailParams = { predictionId: predictionId };
    this.guardedPush(ROUTES.PREDICTION_DETAIL, params, () => {
      this.refresh();
    });
  }

  private openPredictionSettle(predictionId: string): void {
    const params: PredictionSettleParams = { predictionId: predictionId };
    this.guardedPush(ROUTES.PREDICTION_SETTLE, params, () => {
      this.refresh();
    });
  }

  private openRelationDetail(relationId: string): void {
    const params: RelationDetailParams = { relationId: relationId };
    this.guardedPush(ROUTES.RELATION_DETAIL, params, () => {
      this.refresh();
    });
  }

  private openPlanNode(nodeId: string): void {
    const params: PlanNodeParams = { nodeId: nodeId };
    this.guardedPush(ROUTES.PLAN_NODE, params, () => {
      this.refresh();
    });
  }

  private openAgenda(item: AgendaItem): void {
    if (item.kind === AgendaKind.NOTE_TODAY) {
      this.openNoteDetail(item.targetId);
      return;
    }
    if (item.kind === AgendaKind.PLAN_NODE) {
      this.openPlanNode(item.targetId);
      return;
    }
    if (item.kind === AgendaKind.PREDICTION_SETTLE) {
      this.openPredictionSettle(item.targetId);
      return;
    }
    if (item.kind === AgendaKind.RELATION_REPLY) {
      this.openRelationDetail(item.targetId);
      return;
    }
    this.openPredictionDetail(item.targetId);
  }

  /** Detail pages push; the two prediction cards switch to the prediction tab instead. */
  private openModule(module: ModuleStatus): void {
    if (module.tabKey !== null) {
      this.onSwitchTab(module.tabKey);
      return;
    }
    this.guardedPush(module.route, null, () => {
      this.refresh();
    });
  }

  private moduleStatuses(): ModuleStatus[] {
    return [
      {
        icon: $r('sys.symbol.calendar'),
        title: '计划',
        value: `${this.planOpenCount} / ${this.planNodeCount}`,
        caption: '开放 / 总节点',
        tone: AppTheme.color.evPractice,
        route: ROUTES.PLAN,
        tabKey: null
      },
      {
        icon: $r('sys.symbol.scope'),
        title: '预测',
        value: `${this.summary.pendingPredictions}`,
        caption: '待结算',
        tone: AppTheme.color.evTime,
        route: '',
        tabKey: TabKey.PREDICTION
      },
      {
        icon: $r('sys.symbol.person_2'),
        title: '关系',
        value: `${this.agendaReply}`,
        caption: '待回应',
        tone: AppTheme.color.evPublic,
        route: ROUTES.RELATION,
        tabKey: null
      },
      {
        icon: $r('sys.symbol.diagnostic_analytics'),
        title: '命中率',
        value: formatHitRate(this.summary.hitRate, this.summary.settledPredictions),
        caption: '预测命中率',
        tone: AppTheme.color.evOther,
        route: '',
        tabKey: TabKey.PREDICTION
      }
    ];
  }

  /** Opens the panel with a short rise; the scrim and the panel share the same animated flag. */
  private setPanel(visible: boolean): void {
    this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.panelVisible = visible;
    });
  }

  private enterSortMode(): void {
    this.setPanel(false);
    this.sortMode = true;
  }

  private exitSortMode(): void {
    this.sortMode = false;
    this.persistOrder();
  }

  private async resetOrder(): Promise<void> {
    if (this.layoutStore === null) {
      this.order = normalizeBlockOrder([]);
      this.persistOrder();
      return;
    }
    this.order = await this.layoutStore.reset();
  }

  /** Saves the current order immediately; the store is opened on demand if the first read failed. */
  private persistOrder(): void {
    const order = this.order;
    if (this.layoutStore !== null) {
      this.layoutStore.save(order).catch(() => {
      });
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    HomeLayoutStore.open(context).then((store: HomeLayoutStore) => {
      this.layoutStore = store;
      // Read the current order, not the snapshot taken before the store opened.
      store.save(this.order).catch(() => {
      });
    }).catch(() => {
    });
  }

  /** Reorders the in-memory list and stores it at once, so a restart keeps the new order. */
  private moveBlock(from: number, to: number): void {
    if (from === to || from < 0 || to < 0 || from >= this.order.length || to >= this.order.length) {
      return;
    }
    const next: HomeBlockKind[] = this.order.slice();
    const moved = next.splice(from, 1);
    next.splice(to, 0, moved[0]);
    this.order = next;
    this.persistOrder();
  }

  @Builder
  timeHeader() {
    Row({ space: AppTheme.spacing.s8 }) {
      Text(this.today)
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.color.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
      Text(this.clock)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
        .flexShrink(0)

      Blank()

      Stack() {
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(18)
          .fontColor([AppTheme.color.primary])
      }
      .id('home_menu_button')
      .width(36)
      .height(36)
      .backgroundColor(AppTheme.color.tint)
      .borderRadius(AppTheme.radius.lg)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
      .accessibilityText('打开首页面板：自定义顺序与设置')
      .onClick(() => {
        this.setPanel(true);
      })
    }
    .width('100%')
    .padding({
      left: AppTheme.spacing.s20,
      right: AppTheme.spacing.s16,
      top: AppTheme.spacing.s12,
      bottom: AppTheme.spacing.s8
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  sortToolbar() {
    Row({ space: AppTheme.spacing.s8 }) {
      Text('长按区块并拖动调整顺序')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .layoutWeight(1)

      Text('恢复默认')
        .id('home_sort_reset')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.primary)
        .padding({
          left: AppTheme.spacing.s8,
          right: AppTheme.spacing.s8,
          top: AppTheme.spacing.s4,
          bottom: AppTheme.spacing.s4
        })
        .onClick(() => {
          this.resetOrder();
        })

      Text('完成')
        .id('home_sort_done')
        .fontSize(AppTheme.font.body)
        .fontColor(Color.White)
        .padding({
          left: AppTheme.spacing.s12,
          right: AppTheme.spacing.s12,
          top: AppTheme.spacing.s6,
          bottom: AppTheme.spacing.s6
        })
        .backgroundColor(AppTheme.color.primary)
        .borderRadius(AppTheme.radius.sm)
        .onClick(() => {
          this.exitSortMode();
        })
    }
    .width('100%')
    .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s16, bottom: AppTheme.spacing.s8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  readingsBlock() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s6 }) {
        Text('身体读数')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')

        Grid() {
          ForEach(this.readings, (reading: BodyReading) => {
            GridItem() {
              ReadingCard({ reading: reading })
            }
          }, (reading: BodyReading) => `${reading.label}_${this.dataVersion}`)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsGap(0)
        .columnsGap(0)
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  reviewPromptBlock() {
    if (this.promptVisible && !this.appSettings.monitorPaused && !this.isSubtraction()) {
      ReviewPromptPanel({
        period: ReviewPeriod.WEEK,
        onDismiss: () => {
          this.promptVisible = false;
        },
        onRefuse: () => {
          this.promptRefusals += 1;
        }
      })
    } else {
      SectionCard() {
        Column({ space: AppTheme.spacing.s2 }) {
          Text('复盘提示')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
          Text(this.reviewPromptHint())
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  @Builder
  blockContent(kind: HomeBlockKind) {
    if (kind === HomeBlockKind.QUICK_CAPTURE) {
      QuickCaptureBar({
        placeholder: '此刻发生了什么',
        hint: '一句现场、一种感受、一个身体信号都可以。不必解释。',
        onSaved: () => {
          this.afterCapture();
        }
      })
    } else if (kind === HomeBlockKind.AGENDA) {
      AgendaCard({
        items: this.agenda,
        onOpen: (item: AgendaItem) => {
          this.openAgenda(item);
        }
      })
    } else if (kind === HomeBlockKind.RECENT_NOTES) {
      RecentNotesCard({
        notes: this.recentNotes,
        dataVersion: this.dataVersion,
        onOpenAll: () => {
          this.onSwitchTab(TabKey.LOGS);
        },
        onNoteTap: (noteId: string) => {
          this.openNoteDetail(noteId);
        },
        onWrite: () => {
          this.openNoteEditor();
        }
      })
    } else if (kind === HomeBlockKind.MODULE_STATUS) {
      ModuleRail({
        modules: this.moduleStatuses(),
        onOpen: (module: ModuleStatus) => {
          this.openModule(module);
        }
      })
    } else if (kind === HomeBlockKind.READINGS) {
      this.readingsBlock()
    } else {
      this.reviewPromptBlock()
    }
  }

  /** Sort mode adds a title label above each block so the order is readable while dragging. */
  @Builder
  sortableBlock(kind: HomeBlockKind) {
    Column({ space: AppTheme.spacing.s6 }) {
      Row({ space: AppTheme.spacing.s6 }) {
        Text(homeBlockTitle(kind))
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
        Blank()
      }
      .width('100%')

      this.blockContent(kind)
    }
    .width('100%')
  }

  @Builder
  normalList() {
    List({ space: AppTheme.spacing.s12 }) {
      if (this.showWelcome) {
        ListItem() {
          WelcomeCard({
            onStart: () => {
              this.dismissWelcome();
              this.openNoteEditor();
            },
            onDismiss: () => {
              this.dismissWelcome();
            }
          })
        }
      }
      ForEach(this.order, (kind: HomeBlockKind) => {
        ListItem() {
          this.blockContent(kind)
        }
      }, (kind: HomeBlockKind) => kind)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .padding({
      left: AppTheme.spacing.s16,
      right: AppTheme.spacing.s16,
      top: AppTheme.spacing.s4,
      bottom: AppTheme.spacing.s24
    })
  }

  /** Only this branch enables drag sorting, so long presses in normal mode never reorder. */
  @Builder
  sortList() {
    List({ space: AppTheme.spacing.s12 }) {
      ForEach(this.order, (kind: HomeBlockKind) => {
        ListItem() {
          this.sortableBlock(kind)
        }
      }, (kind: HomeBlockKind) => kind)
        .onMove((from: number, to: number) => {
          this.moveBlock(from, to);
        })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .padding({
      left: AppTheme.spacing.s16,
      right: AppTheme.spacing.s16,
      top: AppTheme.spacing.s4,
      bottom: AppTheme.spacing.s24
    })
  }

  @Builder
  statusBanner() {
    if (this.loadFailed) {
      Row({ space: AppTheme.spacing.s8 }) {
        Text('本地数据暂不可用，当前仅展示界面')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.warning)
          .layoutWeight(1)
        Text('重试')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.refresh();
          })
      }
      .width('100%')
      .padding({
        left: AppTheme.spacing.s20,
        right: AppTheme.spacing.s20,
        top: AppTheme.spacing.s6,
        bottom: AppTheme.spacing.s6
      })
      .backgroundColor(AppTheme.color.warningSurface)
    } else if (this.isPreview) {
      Text(PREVIEW_BANNER)
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.primaryDeep)
        .width('100%')
        .padding({
          left: AppTheme.spacing.s20,
          right: AppTheme.spacing.s20,
          top: AppTheme.spacing.s6,
          bottom: AppTheme.spacing.s6
        })
        .backgroundColor(AppTheme.color.tint)
    } else if (this.encryptionNotice.length > 0) {
      Text(this.encryptionNotice)
        .fontSize(AppTheme.font.caption)
        .lineHeight(LINE_HEIGHT.caption)
        .fontColor(AppTheme.color.danger)
        .width('100%')
        .padding({
          left: AppTheme.spacing.s20,
          right: AppTheme.spacing.s20,
          top: AppTheme.spacing.s6,
          bottom: AppTheme.spacing.s2
        })
    } else if (this.dataPartial) {
      Row({ space: AppTheme.spacing.s8 }) {
        Text('部分数据未读取，已展示可用内容')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.warning)
          .layoutWeight(1)
        Text('重试')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.refresh();
          })
      }
      .width('100%')
      .padding({
        left: AppTheme.spacing.s20,
        right: AppTheme.spacing.s20,
        top: AppTheme.spacing.s6,
        bottom: AppTheme.spacing.s2
      })
    } else if (this.dataNotice.length > 0) {
      Text(this.dataNotice)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.warning)
        .width('100%')
        .padding({
          left: AppTheme.spacing.s20,
          right: AppTheme.spacing.s20,
          top: AppTheme.spacing.s6,
          bottom: AppTheme.spacing.s2
        })
    }
  }

  @Builder
  loadingView() {
    Column({ space: AppTheme.spacing.s12 }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(AppTheme.color.primary)
      Text('加载中...')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.textSecondary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  blockedBody() {
    Column({ space: AppTheme.spacing.s12 }) {
      Text('数据库打不开')
        .fontSize(AppTheme.font.headline)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.color.text)
      Text('记录仍保存在本机。可以先重试；一直失败时请重启应用。备份与导出需要数据库打开后才能使用。')
        .fontSize(AppTheme.font.bodyStrong)
        .lineHeight(LINE_HEIGHT.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
        .textAlign(TextAlign.Center)
      if (this.dbMessage.length > 0) {
        Text(this.dbMessage)
          .fontSize(AppTheme.font.caption)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(AppTheme.color.textMuted)
          .textAlign(TextAlign.Center)
      }
      Text('重试')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(Color.White)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
        .backgroundColor(AppTheme.color.primary)
        .borderRadius(AppTheme.radius.lg)
        .onClick(() => {
          this.retryDatabase();
        })
      Text('退出应用')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
        .padding({ top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
        .onClick(() => {
          this.exitApplication();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: AppTheme.spacing.s24, right: AppTheme.spacing.s24 })
    .backgroundColor(AppTheme.color.page)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.dbBlocked) {
          this.blockedBody()
        } else {
          this.statusBanner()
          this.timeHeader()
          if (this.sortMode) {
            this.sortToolbar()
          }
          if (this.isLoading && this.dataVersion === 0) {
            this.loadingView()
          } else if (this.sortMode) {
            this.sortList()
          } else {
            this.normalList()
          }
        }
      }
      .width('100%')
      .height('100%')

      HomeQuickMenuPanel({
        visible: this.panelVisible,
        onClose: () => {
          this.setPanel(false);
        },
        onCustomize: () => {
          this.enterSortMode();
        },
        onSettings: () => {
          this.setPanel(false);
          this.guardedPush(ROUTES.SETTINGS, null, () => {
            this.refresh();
          });
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}