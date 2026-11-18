import { AppTheme } from '../theme/AppTheme';
import {
  PredictionListItem,
  PredictionQuickFilter,
  PredictionService,
  PredictionSummary,
  filterPredictionItems,
  todayDateString
} from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { formatHitRate, hitRateCaption } from '../model/HomeModel';
import { PredictionDetailParams, PredictionCreateParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { PredictionListCard } from '../components/PredictionListCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { TagChip } from '../components/TagChip';
import { AnalyticsView } from './AnalyticsView';
import { previewStore } from '../preview/PreviewStore';

const PAGE_SIZE = 20;
const QUICK_PAGE_SIZE = 1000;

/**
 * Prediction log body shared by the prediction tab and the prediction list route. One List is the
 * only scroll container: summary, filters, rows, load-more, the dashboard heading and the dashboard
 * itself are all items in the same stream.
 */
@ComponentV2
export struct PredictionLogView {
  @Require @Param pathStack: NavPathStack;
  /** Host-owned counter; every change reloads the first page and the summary. */
  @Param refreshToken: number = 0;
  /** Host-owned counter; every change scrolls to the embedded dashboard. */
  @Param scrollToStatsToken: number = 0;
  /** Hides each dashboard card's explanation behind its notes toggle. */
  @Param collapsibleNotes: boolean = true;
  /** Status selected when the page opens; null shows every prediction. */
  @Param initialFilter: PredictionStatus | null = null;
  /** The route host may hide the dashboard; the tab always shows it. */
  @Param showDashboard: boolean = true;
  @Local service: PredictionService | null = null;
  @Local items: PredictionListItem[] = [];
  @Local summary: PredictionSummary = { total: 0, pending: 0, settled: 0, hits: 0, hitRate: 0 };
  @Local filter: PredictionStatus | null = null;
  @Local quick: PredictionQuickFilter = 'all';
  @Local isLoading: boolean = true;
  @Local isLoadingMore: boolean = false;
  @Local hasMore: boolean = false;
  @Local isPreview: boolean = false;
  @Local listVersion: number = 0;
  /** Bumped on every list reload so the embedded dashboard refreshes with the rows. */
  @Local analyticsToken: number = 0;
  private scroller: Scroller = new Scroller();
  private loadToken: number = 0;

  aboutToAppear(): void {
    this.filter = this.initialFilter;
    this.openService();
  }

  @Monitor('refreshToken')
  onRefreshToken(): void {
    this.refresh();
  }

  @Monitor('initialFilter')
  onInitialFilterChanged(): void {
    this.filter = this.initialFilter;
    this.quick = 'all';
    this.refresh();
  }

  @Monitor('scrollToStatsToken')
  onScrollToStats(): void {
    this.scroller.scrollEdge(Edge.Bottom);
  }

  private async openService(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await PredictionService.open(hostContext);
      await this.refresh();
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.items = this.applyQuick(previewStore.listPredictions(this.filter));
    this.listVersion += 1;
    this.summary = previewStore.predictionSummary();
    this.isLoading = false;
    this.analyticsToken += 1;
  }

  async refresh(): Promise<void> {
    if (this.isPreview) {
      this.items = this.applyQuick(previewStore.listPredictions(this.filter));
      this.listVersion += 1;
      this.summary = previewStore.predictionSummary();
      this.isLoading = false;
      return;
    }
    if (this.service === null) {
      return;
    }
    const token = ++this.loadToken;
    this.isLoading = true;
    try {
      const limit = this.quick === 'all' ? PAGE_SIZE : QUICK_PAGE_SIZE;
      const rows = await this.service.listPage(this.filter, limit, 0);
      if (token !== this.loadToken) {
        return;
      }
      this.items = this.applyQuick(rows);
      this.listVersion += 1;
      this.hasMore = this.quick === 'all' && rows.length >= PAGE_SIZE;
      this.summary = await this.service.summary();
      this.analyticsToken += 1;
    } catch (error) {
      if (token !== this.loadToken) {
        return;
      }
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，请重试' });
    } finally {
      if (token === this.loadToken) {
        this.isLoading = false;
      }
    }
  }

  private async loadMore(): Promise<void> {
    if (this.service === null || this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    try {
      const next = await this.service.listPage(this.filter, PAGE_SIZE, this.items.length);
      this.items = this.items.concat(next);
      this.listVersion += 1;
      this.hasMore = next.length >= PAGE_SIZE;
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '加载更多失败，请重试' });
    } finally {
      this.isLoadingMore = false;
    }
  }

  private selectFilter(status: PredictionStatus | null): void {
    this.filter = status;
    this.quick = 'all';
    this.refresh();
  }

  private selectQuick(quick: PredictionQuickFilter): void {
    this.quick = this.quick === quick ? 'all' : quick;
    if (this.quick !== 'all') {
      this.filter = PredictionStatus.PENDING;
    }
    this.refresh();
  }

  private applyQuick(items: PredictionListItem[]): PredictionListItem[] {
    return filterPredictionItems(items, this.quick, todayDateString(Date.now()));
  }

  private openDetail(predictionId: string): void {
    const params: PredictionDetailParams = { predictionId: predictionId };
    this.pathStack.pushPathByName(ROUTES.PREDICTION_DETAIL, params, () => {
      this.refresh();
    });
  }

  private openCreate(): void {
    const params: PredictionCreateParams = { sourcePredictionId: null };
    this.pathStack.pushPathByName(ROUTES.PREDICTION_CREATE, params, () => {
      this.refresh();
    });
  }

  private emptyTitle(): string {
    if (this.quick === 'due') {
      return '没有到期待结算的预测';
    }
    if (this.quick === 'revised') {
      return '没有待修订的预测';
    }
    if (this.filter === PredictionStatus.PENDING) {
      return '暂无待结算预测';
    }
    if (this.filter === PredictionStatus.SETTLED) {
      return '暂无已结算预测';
    }
    return '还没有预测记录';
  }

  private emptyHint(): string {
    if (this.quick === 'due') {
      return '到达结算日的判断会在这里等你';
    }
    if (this.quick === 'revised') {
      return '修订过的判断会在这里列出';
    }
    if (this.filter === PredictionStatus.PENDING) {
      return '到期的判断会在这里等你结算';
    }
    if (this.filter === PredictionStatus.SETTLED) {
      return '结算后的判断会保留在这里';
    }
    return '点右上角「＋」创建一条';
  }

  @Builder
  statusChip(label: string, status: PredictionStatus | null) {
    TagChip({
      label: label,
      tone: AppTheme.color.primary,
      surface: AppTheme.color.evPracticeSurface,
      selected: this.filter === status && this.quick === 'all',
      onTap: () => {
        this.selectFilter(status);
      }
    })
  }

  @Builder
  quickChip(label: string, quick: PredictionQuickFilter, tone: ResourceColor, surface: ResourceColor) {
    TagChip({
      label: label,
      tone: tone,
      surface: surface,
      selected: this.quick === quick,
      onTap: () => {
        this.selectQuick(quick);
      }
    })
  }

  @Builder
  summaryCard() {
    Row() {
      Column({ space: 4 }) {
        Text(formatHitRate(this.summary.hitRate, this.summary.settled))
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.primary)
        Text(hitRateCaption(this.summary.settled))
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text(String(this.summary.pending))
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Text('待结算')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text(String(this.summary.settled))
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Text('已结算')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  filterRow() {
    Scroll() {
      Row({ space: AppTheme.spacing.s8 }) {
        this.statusChip('全部', null)
        this.statusChip('待结算', PredictionStatus.PENDING)
        this.statusChip('已结算', PredictionStatus.SETTLED)
        this.quickChip('到期待结算', 'due', AppTheme.color.warning, AppTheme.color.warningSurface)
        this.quickChip('待修订', 'revised', AppTheme.color.accentPurple, AppTheme.color.evOtherSurface)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  dashboardHeading() {
    Column({ space: AppTheme.spacing.s2 }) {
      Text('数据看板')
        .fontSize(AppTheme.font.subtitle)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .width('100%')
      Text('看板说明默认收起，点卡片里的「说明」展开')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
    }
    .width('100%')
    .padding({ top: AppTheme.spacing.s8 })
  }

  build() {
    List({ space: 8, scroller: this.scroller }) {
      ListItem() {
        this.summaryCard()
      }

      ListItem() {
        this.filterRow()
      }

      if (this.isLoading) {
        ListItem() {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(AppTheme.color.primary)
          }
          .width('100%')
          .constraintSize({ minHeight: 200 })
          .justifyContent(FlexAlign.Center)
        }
      } else if (this.items.length === 0) {
        ListItem() {
          Column() {
            NoteEmptyState({
              title: this.emptyTitle(),
              hint: this.emptyHint(),
              actionLabel: '',
              onAction: () => {
              }
            })
          }
          .width('100%')
          .constraintSize({ minHeight: 200 })
          .justifyContent(FlexAlign.Center)
        }
      } else {
        ForEach(this.items, (item: PredictionListItem) => {
          ListItem() {
            PredictionListCard({
              item: item,
              onTap: () => {
                this.openDetail(item.id);
              }
            })
          }
        }, (item: PredictionListItem) => `${item.id}_${this.listVersion}`)
      }

      if (this.hasMore) {
        ListItem() {
          Text(this.isLoadingMore ? '加载中…' : '加载更多')
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.primary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
            .onClick(() => {
              this.loadMore();
            })
            .accessibilityText(this.isLoadingMore ? '正在加载更多预测' : '加载更多预测')
        }
      }

      if (this.showDashboard) {
        ListItem() {
          this.dashboardHeading()
        }
        ListItem() {
          AnalyticsView({
            refreshToken: this.refreshToken + this.analyticsToken,
            collapsibleNotes: this.collapsibleNotes
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .padding({
      left: AppTheme.spacing.s16,
      right: AppTheme.spacing.s16,
      top: AppTheme.spacing.s12,
      bottom: AppTheme.spacing.s24
    })
  }
}