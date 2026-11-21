import { AppTheme } from '../theme/AppTheme';
import { BusinessError } from '@kit.BasicServicesKit';
import { TabHeader } from '../components/TabHeader';
import { SectionCard } from '../components/SectionCard';
import { ReadingCard } from '../components/ReadingCard';
import { HomeSnapshotService } from '../data/HomeSnapshotService';
import { HomeSnapshot } from '../model/HomeSnapshot';
import { BodyReading, formatHitRate } from '../model/HomeModel';
import { TabKey } from '../navigation/TabItems';
import { isDatabaseUnsupported } from '../app/AppHealth';
import {
  activeTab,
  subscribeTabRefresh,
  unsubscribeTabRefresh
} from '../app/TabRefreshBus';
import { ROUTES } from '../navigation/Routes';
import { previewStore } from '../preview/PreviewStore';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { PlanNode } from '../model/PlanNode';
import { PlanNodeStatus } from '../model/PlanStatus';

/** One module entry in the drawer grid. */
interface DrawerEntry {
  id: string;
  title: string;
  hint: string;
  route: string;
}

const NO_VALUE = '—';

/** Module entries; plan and relation live here now that they left the bottom bar. */
const DRAWER_ENTRIES: DrawerEntry[] = [
  { id: 'drawer_plan', title: '计划', hint: '周节点与清单', route: ROUTES.PLAN },
  { id: 'drawer_relation', title: '关系', hint: '披露层级与纠正', route: ROUTES.RELATION },
  { id: 'drawer_anchor', title: '价值锚点', hint: '只读对照', route: ROUTES.ANCHOR },
  { id: 'drawer_status', title: '状态', hint: '生理读数', route: ROUTES.STATUS },
  { id: 'drawer_review', title: '复盘', hint: '六区复盘', route: ROUTES.REVIEW },
  { id: 'drawer_review_history', title: '复盘历史', hint: '历次结果', route: ROUTES.REVIEW_HISTORY },
  { id: 'drawer_weekly', title: '周结算', hint: '本周与上周', route: ROUTES.REVIEW_WEEKLY },
  { id: 'drawer_settings', title: '设置', hint: '模型与密级', route: ROUTES.SETTINGS },
  { id: 'drawer_background', title: '页面背景', hint: '本机图片', route: ROUTES.BACKGROUND_APPLY }
];

/** Placeholder readings so the three body slots render even before the first read. */
function emptyReadings(): BodyReading[] {
  return [
    { label: '睡眠', value: '--', unit: ' 小时' },
    { label: '运动', value: '--', unit: ' 次' },
    { label: '速记', value: '--', unit: ' 条' }
  ];
}

/**
 * Drawer tab: the only entry point for every module that used to sit on the bottom bar, plus a
 * readings block. Missing values show a placeholder instead of an empty slot.
 */
@ComponentV2
export struct DrawerView {
  @Require @Param pathStack: NavPathStack;
  @Local readings: BodyReading[] = emptyReadings();
  @Local hitRateText: string = NO_VALUE;
  @Local pendingText: string = NO_VALUE;
  @Local replyText: string = NO_VALUE;
  @Local openNodeText: string = NO_VALUE;
  @Local loaded: boolean = false;
  @Local failed: boolean = false;
  private snapshotService: HomeSnapshotService | null = null;
  private tabListener: (() => void) | null = null;
  private lastPushAt: number = 0;
  private loadToken: number = 0;

  aboutToAppear(): void {
    if (this.tabListener === null) {
      this.tabListener = () => {
        if (activeTab() !== TabKey.DRAWER) {
          return;
        }
        this.load();
      };
      subscribeTabRefresh(TabKey.DRAWER, this.tabListener);
    }
    this.load();
  }

  aboutToDisappear(): void {
    if (this.tabListener !== null) {
      unsubscribeTabRefresh(TabKey.DRAWER, this.tabListener);
      this.tabListener = null;
    }
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.loadPreview();
      return;
    }
    const token = ++this.loadToken;
    try {
      if (this.snapshotService === null) {
        this.snapshotService = await HomeSnapshotService.open(context);
      }
      const snapshot: HomeSnapshot = await this.snapshotService.load();
      if (token !== this.loadToken) {
        return;
      }
      this.applySnapshot(snapshot);
      this.failed = snapshot.partial;
    } catch (error) {
      if (token !== this.loadToken) {
        return;
      }
      const failure = error as BusinessError;
      if (isDatabaseUnsupported(failure.code ?? 0)) {
        this.loadPreview();
        return;
      }
      // A real read failure keeps the placeholders and offers a retry instead of demo numbers.
      this.failed = true;
      this.loaded = true;
    }
  }

  private loadPreview(): void {
    this.readings = previewStore.previewReadings();
    const summary = previewStore.homeSummary();
    this.hitRateText = formatHitRate(summary.hitRate, summary.settledPredictions);
    this.pendingText = String(summary.pendingPredictions);
    this.replyText = '0';
    const primary = planPreviewStore.primary();
    const nodes: PlanNode[] = primary === null ? [] : planPreviewStore.nodes(primary.id);
    this.openNodeText = String(nodes.filter((node: PlanNode) => node.status === PlanNodeStatus.OPEN).length);
    this.failed = false;
    this.loaded = true;
  }

  private applySnapshot(snapshot: HomeSnapshot): void {
    this.readings = snapshot.readings.length > 0 ? snapshot.readings : emptyReadings();
    this.hitRateText = snapshot.summaryAvailable ?
      formatHitRate(snapshot.summary.hitRate, snapshot.summary.settledPredictions) : NO_VALUE;
    this.pendingText = snapshot.summaryAvailable ? String(snapshot.summary.pendingPredictions) : NO_VALUE;
    this.replyText = snapshot.agendaAvailable ? String(snapshot.agendaReply) : NO_VALUE;
    this.openNodeText = snapshot.agendaAvailable ? String(snapshot.planOpenCount) : NO_VALUE;
    this.loaded = true;
  }

  private push(route: string): void {
    const now = Date.now();
    if (now - this.lastPushAt < 600) {
      return;
    }
    this.lastPushAt = now;
    this.pathStack.pushPathByName(route, null, () => {
      this.load();
    });
  }

  @Builder
  countCell(cellId: string, value: string, label: string) {
    Column({ space: AppTheme.spacing.s2 }) {
      Text(value)
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.primary)
        .maxLines(1)
      Text(label)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textSecondary)
        .maxLines(1)
    }
    .id(cellId)
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .accessibilityText(`${label} ${value}`)
  }

  @Builder
  readingsBlock() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s10 }) {
        Row() {
          Text('读数')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
          Blank()
          if (this.failed) {
            Text('重试')
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.primary)
              .onClick(() => {
                this.load();
              })
          }
        }
        .width('100%')

        Row() {
          ForEach(this.readings, (reading: BodyReading) => {
            ReadingCard({ reading: reading })
          }, (reading: BodyReading) => `${reading.label}_${this.loaded ? 1 : 0}`)
        }
        .width('100%')

        Grid() {
          GridItem() {
            this.countCell('drawer_hit_rate', this.hitRateText, '预测命中率')
          }
          GridItem() {
            this.countCell('drawer_pending', this.pendingText, '待结算')
          }
          GridItem() {
            this.countCell('drawer_reply', this.replyText, '待回应')
          }
          GridItem() {
            this.countCell('drawer_open_nodes', this.openNodeText, '开放节点')
          }
        }
        .columnsTemplate('1fr 1fr')
        .rowsGap(AppTheme.spacing.s10)
        .columnsGap(AppTheme.spacing.s10)
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  moduleTile(entry: DrawerEntry) {
    Column({ space: AppTheme.spacing.s2 }) {
      Text(entry.title)
        .fontSize(AppTheme.font.bodyStrong)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(entry.hint)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .id(entry.id)
    .width('31%')
    .constraintSize({ minHeight: 64 })
    .padding(AppTheme.spacing.s10)
    .backgroundColor(AppTheme.color.surfaceAlt)
    .borderRadius(AppTheme.radius.md)
    .margin({ bottom: AppTheme.spacing.s8 })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityText(entry.title)
    .onClick(() => {
      this.push(entry.route);
    })
  }

  @Builder
  modulesBlock() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s8 }) {
        Text('全部模块')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(DRAWER_ENTRIES, (entry: DrawerEntry) => {
            this.moduleTile(entry)
          }, (entry: DrawerEntry) => entry.id)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column() {
      TabHeader({ title: '抽屉' })

      Scroll() {
        Column({ space: AppTheme.spacing.s12 }) {
          this.readingsBlock()
          this.modulesBlock()
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
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}