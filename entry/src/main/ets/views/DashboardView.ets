import { BodyReading, HomeSummary, formatHitRate, todayLabel } from '../model/HomeModel';
import { HomeDataService } from '../data/HomeDataService';
import { ReadingCard } from '../components/ReadingCard';
import { SectionCard } from '../components/SectionCard';
import { NoteListItem } from '../note/NoteListItem';
import {
  NoteDetailParams,
  NoteEditParams,
  NoteListParams,
  PlanNodeParams,
  PredictionDetailParams,
  PredictionListParams,
  PredictionSettleParams,
  RelationDetailParams
} from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { AppTheme } from '../theme/AppTheme';
import { ReviewPeriod } from '../review';
import { ReviewPromptPanel } from '../components/ReviewPromptPanel';
import { WelcomeCard } from '../components/WelcomeCard';
import { OnboardingStore } from '../settings/OnboardingStore';
import { PREVIEW_BANNER } from '../preview/PreviewMode';
import { previewStore } from '../preview/PreviewStore';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { PREVIEW_RELATION_ITEMS } from '../preview/PreviewData';
import { subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';
import { RecentNotesCard } from './dashboard/RecentNotesCard';
import { AgendaCard } from './dashboard/AgendaCard';
import { ModuleRail, ModuleStatus } from './dashboard/ModuleRail';
import { QuickNoteService } from '../note/QuickNoteService';
import { NoteDepth, NoteDraft } from '../note/NoteDraft';
import { SecurityLevel } from '../model/SecurityLevel';
import { SettingsStore } from '../settings/SettingsStore';
import { AppSettings, defaultAppSettings } from '../settings/AppSettings';
import { shouldEnterSubtraction, WriteSample } from '../analysis/meta/SubtractionMode';
import { PlanItem } from '../model/PlanItem';
import { PlanNode } from '../model/PlanNode';
import { PlanNodeStatus, PlanStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { PredictionService } from '../prediction';
import { RelationService } from '../relation';
import { AgendaItem, AgendaKind, AgendaResult, buildAgenda } from '../home/AgendaMapper';

/** Home workbench: today's agenda first, then traces, module status and the readings. */
@ComponentV2
export struct DashboardView {
  @Require @Param pathStack: NavPathStack;
  /** Owner-scoped scroller so the host can jump to a section. */
  @Param scroller: Scroller = new Scroller();
  @Local today: string = todayLabel();
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
  @Local dataService: HomeDataService | null = null;
  private lastPushAt: number = 0;
  @Local dataVersion: number = 0;
  @Local isLoading: boolean = true;
  @Local loadFailed: boolean = false;
  @Local isPreview: boolean = false;
  @Local showWelcome: boolean = false;
  @Local readingsVisible: boolean = false;
  @Local captureText: string = '';
  @Local capturing: boolean = false;
  @Local promptVisible: boolean = true;
  @Local appSettings: AppSettings = defaultAppSettings();
  @Local promptRefusals: number = 0;
  @Local subtractionExited: boolean = false;
  @Local sessionWrites: WriteSample[] = [];
  private refreshListener: (() => void) | null = null;

  async aboutToAppear(): Promise<void> {
    this.loadSettings();
    if (this.refreshListener === null) {
      this.refreshListener = () => {
        this.refresh();
      };
      subscribeHomeRefresh(this.refreshListener);
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showWelcome = true;
      this.loadPreview();
      return;
    }
    try {
      const onboarding = await OnboardingStore.open(context);
      this.showWelcome = !(await onboarding.isSeen());
    } catch (error) {
      this.showWelcome = true;
    }
    try {
      this.dataService = await HomeDataService.open(context);
      await this.refresh();
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '数据加载失败，已切换到演示数据' });
    }
  }

  aboutToDisappear(): void {
    if (this.refreshListener !== null) {
      unsubscribeHomeRefresh(this.refreshListener);
      this.refreshListener = null;
    }
  }

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
    this.applyAgenda(buildAgenda({
      plans: planPreviewStore.list(),
      nodes: nodes,
      items: items,
      predictions: previewStore.listPredictions(null),
      relations: PREVIEW_RELATION_ITEMS,
      todayNotes: this.recentNotes
    }));
    this.applyPlanCounts(nodes);
    this.dataVersion += 1;
    this.isLoading = false;
    this.loadFailed = false;
  }

  async refresh(): Promise<void> {
    this.loadSettings();
    if (this.isPreview) {
      this.loadPreview();
      return;
    }
    if (this.dataService === null) {
      this.isLoading = false;
      return;
    }
    this.isLoading = true;
    try {
      this.readings = await this.dataService.loadReadings();
      this.recentNotes = await this.dataService.loadRecentNotes(20);
      this.summary = await this.dataService.loadSummary();
      await this.loadAgenda();
      this.dataVersion += 1;
      this.loadFailed = false;
    } catch (error) {
      this.loadFailed = true;
      this.getUIContext().getPromptAction().showToast({ message: '数据加载失败，请稍后重试' });
    } finally {
      this.isLoading = false;
    }
  }

  /** Reads plans, predictions and relations through their services; the mapper does the rest. */
  private async loadAgenda(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const planService = await PlanService.open(context);
    const plans = await planService.listPlans();
    const nodes: PlanNode[] = [];
    const items: PlanItem[] = [];
    for (const plan of plans) {
      if (plan.status !== PlanStatus.ACTIVE) {
        continue;
      }
      const planNodes = await planService.listNodes(plan.id);
      for (const node of planNodes) {
        nodes.push(node);
        const nodeItems = await planService.listItems(node.id);
        for (const item of nodeItems) {
          items.push(item);
        }
      }
    }
    const predictionService = await PredictionService.open(context);
    const predictions = await predictionService.list(null);
    const relationService = await RelationService.open(context);
    const relations = await relationService.list(null);
    this.applyAgenda(buildAgenda({
      plans: plans,
      nodes: nodes,
      items: items,
      predictions: predictions,
      relations: relations,
      todayNotes: this.recentNotes
    }));
    this.applyPlanCounts(nodes);
  }

  private applyAgenda(result: AgendaResult): void {
    this.agenda = result.items;
    this.agendaPending = result.pendingCount;
    this.agendaReply = result.replyCount;
  }

  private applyPlanCounts(nodes: PlanNode[]): void {
    this.planNodeCount = nodes.length;
    this.planOpenCount = nodes.filter((node: PlanNode) => node.status === PlanNodeStatus.OPEN).length;
  }

  private moduleStatuses(): ModuleStatus[] {
    return [
      {
        icon: $r('sys.symbol.calendar'),
        title: '计划',
        value: `${this.planOpenCount} / ${this.planNodeCount}`,
        caption: '开放 / 总节点',
        tone: AppTheme.color.evPractice,
        route: ROUTES.PLAN
      },
      {
        icon: $r('sys.symbol.scope'),
        title: '预测',
        value: `${this.summary.pendingPredictions}`,
        caption: '待结算',
        tone: AppTheme.color.evTime,
        route: ROUTES.PREDICTION_LIST
      },
      {
        icon: $r('sys.symbol.person_2'),
        title: '关系',
        value: `${this.agendaReply}`,
        caption: '待回应',
        tone: AppTheme.color.evPublic,
        route: ROUTES.RELATION
      },
      {
        icon: $r('sys.symbol.diagnostic_analytics'),
        title: '看板',
        value: formatHitRate(this.summary.hitRate, this.summary.settledPredictions),
        caption: '预测命中率',
        tone: AppTheme.color.evOther,
        route: ROUTES.ANALYTICS
      }
    ];
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

  private startFromWelcome(): void {
    this.dismissWelcome();
    this.openNoteEditor();
  }

  private guardedPush(name: string, param: Object | null, onPop: () => void): void {
    const now = Date.now();
    if (now - this.lastPushAt < 600) {
      return;
    }
    this.lastPushAt = now;
    this.pathStack.pushPathByName(name, param, onPop);
  }

  private async loadSettings(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const store = await SettingsStore.open(context);
    this.appSettings = await store.load();
  }

  /** Recent writes as subtraction-mode samples; session captures carry their real kinds. */
  private recentWrites(): WriteSample[] {
    const fromList: WriteSample[] = this.recentNotes.map((note: NoteListItem): WriteSample => {
      return { kind: 'scene', chars: note.summary.length, hour: new Date(note.timestamp).getHours() };
    });
    return this.sessionWrites.concat(fromList);
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

  /** Saving a single line completes the first layer's minimal form without leaving home. */
  private async saveCapture(): Promise<void> {
    const text = this.captureText.trim();
    if (text.length === 0 || this.capturing) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.capturing = true;
    try {
      const service = await QuickNoteService.open(context);
      const draft: NoteDraft = {
        templateId: null,
        title: '',
        content: text,
        entries: [],
        tags: [],
        relatedRelationIds: [],
        level: SecurityLevel.LOCAL_ONLY,
        materials: [{ kind: 'scene', text: text }],
        depth: NoteDepth.QUICK,
        timestamp: Date.now()
      };
      await service.save(draft);
      const hour = new Date().getHours();
      this.sessionWrites = this.sessionWrites.concat([
        { kind: 'scene', chars: text.length, hour: hour }
      ]);
      // Writing a scene or feeling naturally exits subtraction mode.
      this.subtractionExited = true;
      this.promptRefusals = 0;
      this.captureText = '';
      this.refresh();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.capturing = false;
    }
  }

  private openNoteEditor(): void {
    const params: NoteEditParams = { templateId: null };
    this.guardedPush(ROUTES.NOTE_EDIT, params, () => {
      this.refresh();
    });
  }

  private openNoteList(): void {
    const params: NoteListParams = { filterType: '' };
    this.guardedPush(ROUTES.NOTE_LIST, params, () => {
      this.refresh();
    });
  }

  private openNoteDetail(noteId: string): void {
    const params: NoteDetailParams = { noteId: noteId };
    this.guardedPush(ROUTES.NOTE_DETAIL, params, () => {
      this.refresh();
    });
  }

  private openPredictionList(): void {
    const params: PredictionListParams = { status: null };
    this.guardedPush(ROUTES.PREDICTION_LIST, params, () => {
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

  private openModule(route: string): void {
    if (route === ROUTES.PREDICTION_LIST) {
      this.openPredictionList();
      return;
    }
    this.guardedPush(route, null, () => {
      this.refresh();
    });
  }

  @Builder
  masthead() {
    Row({ space: AppTheme.spacing.s8 }) {
      Column({ space: AppTheme.spacing.s2 }) {
        Text(this.today)
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.color.text)
        Text(`${this.agendaPending} 件待处置 · ${this.agendaReply} 条待回应`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(20)
        .fontColor([AppTheme.color.primary])
        .accessibilityText('打开设置')
        .onClick(() => {
          this.guardedPush(ROUTES.SETTINGS, null, () => {
          });
        })
      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(20)
        .fontColor([AppTheme.color.primary])
        .accessibilityText('刷新首页数据')
        .onClick(() => {
          this.refresh();
        })
    }
    .width('100%')
    .padding({
      left: AppTheme.spacing.s16,
      right: AppTheme.spacing.s16,
      top: AppTheme.spacing.s12,
      bottom: AppTheme.spacing.s8
    })
    .alignItems(VerticalAlign.Center)
  }

  /** The writable surface: one input box; saving completes the first layer without leaving home. */
  @Builder
  writeHero() {
    SectionCard({ contentPadding: AppTheme.spacing.s12 }) {
      Column({ space: AppTheme.spacing.s6 }) {
        TextArea({ placeholder: '此刻发生了什么', text: this.captureText })
          .id('home_capture_input')
          .fontSize(AppTheme.font.bodyStrong)
          .height(56)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.captureText = value;
          })
        Row({ space: AppTheme.spacing.s8 }) {
          Text('一句现场、一种感受、一个身体信号都可以。不必解释。')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Row({ space: AppTheme.spacing.s4 }) {
            Text(this.capturing ? '保存中' : '保存')
              .id('home_capture_save')
              .fontSize(AppTheme.font.body)
              .fontColor(Color.White)
              .padding({
                left: AppTheme.spacing.s12,
                right: AppTheme.spacing.s12,
                top: AppTheme.spacing.s6,
                bottom: AppTheme.spacing.s6
              })
              .backgroundColor(this.captureText.trim().length > 0 ?
                AppTheme.color.primary : AppTheme.color.primaryDisabled)
              .borderRadius(AppTheme.radius.sm)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
              .onClick(() => {
                this.saveCapture();
              })
            SymbolGlyph($r('sys.symbol.chevron_forward'))
              .fontSize(14)
              .fontColor([AppTheme.color.textSecondary])
              .id('home_open_editor')
              .onClick(() => {
                this.openNoteEditor();
              })
          }
        }
        .width('100%')
      }
      .id('home_write_hero')
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  readingsSection() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s6 }) {
        Row() {
          Text('身体读数')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
          Blank()
          Text(this.readingsVisible ? '隐藏' : '显示')
            .id('home_readings_toggle')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.readingsVisible = !this.readingsVisible;
            })
        }
        .width('100%')

        if (this.readingsVisible) {
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
      }
      .width('100%')
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
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
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
      }

      if (this.isPreview) {
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
      }

      if (this.isLoading) {
        this.loadingView()
      } else {
        Column() {
          this.masthead()
          Scroll(this.scroller) {
            Column({ space: AppTheme.spacing.s12 }) {
              if (this.showWelcome) {
                WelcomeCard({
                  onStart: () => {
                    this.startFromWelcome();
                  },
                  onDismiss: () => {
                    this.dismissWelcome();
                  }
                })
              }

              this.writeHero()

              AgendaCard({
                items: this.agenda,
                onOpen: (item: AgendaItem) => {
                  this.openAgenda(item);
                }
              })
                .id('home_section_agenda')

              RecentNotesCard({
                notes: this.recentNotes,
                dataVersion: this.dataVersion,
                onOpenAll: () => {
                  this.openNoteList();
                },
                onNoteTap: (noteId: string) => {
                  this.openNoteDetail(noteId);
                },
                onWrite: () => {
                  this.openNoteEditor();
                }
              })
                .id('home_section_recent_notes')

              if (!this.isSubtraction()) {
                ModuleRail({
                  modules: this.moduleStatuses(),
                  onOpen: (route: string) => {
                    this.openModule(route);
                  }
                })
                  .id('home_section_modules')
              }

              this.readingsSection()

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
                  .id('home_section_review_prompt')
              }
            }
            .width('100%')
            .padding({
              left: AppTheme.spacing.s16,
              right: AppTheme.spacing.s16,
              top: AppTheme.spacing.s4,
              bottom: AppTheme.spacing.s24
            })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}