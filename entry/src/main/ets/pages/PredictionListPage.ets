import { PredictionListItem, PredictionService, PredictionSummary } from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { formatHitRate, hitRateCaption } from '../model/HomeModel';
import { PredictionDetailParams, PredictionListParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { PredictionListCard } from '../components/PredictionListCard';
import { NoteEmptyState } from '../components/NoteEmptyState';

/** Prediction log: summary counts, status filters and the row list. */
@ComponentV2
export struct PredictionListPage {
  @Local service: PredictionService | null = null;
  @Local items: PredictionListItem[] = [];
  @Local summary: PredictionSummary = { total: 0, pending: 0, settled: 0, hits: 0, hitRate: 0 };
  @Local filter: PredictionStatus | null = null;
  @Local isLoading: boolean = true;
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.openService();
  }

  private async openService(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isLoading = false;
      return;
    }
    try {
      this.service = await PredictionService.open(hostContext);
      await this.refresh();
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，请重试' });
    }
  }

  async refresh(): Promise<void> {
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.items = await this.service.list(this.filter);
      this.summary = await this.service.summary();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private selectFilter(status: PredictionStatus | null): void {
    this.filter = status;
    this.refresh();
  }

  private openDetail(predictionId: string): void {
    if (this.navStack === null) {
      return;
    }
    const params: PredictionDetailParams = { predictionId: predictionId };
    this.navStack.pushPathByName(ROUTES.PREDICTION_DETAIL, params);
  }

  @Builder
  filterChip(label: string, status: PredictionStatus | null) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filter === status ? Color.White : '#444441')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === status ? '#4A6FA5' : '#F1EFE8')
      .borderRadius(14)
      .onClick(() => {
        this.selectFilter(status);
      })
  }

  @Builder
  summaryCard() {
    Row() {
      Column({ space: 4 }) {
        Text(formatHitRate(this.summary.hitRate, this.summary.settled))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4A6FA5')
        Text(hitRateCaption(this.summary.settled))
          .fontSize(11)
          .fontColor('#8A8F99')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text(String(this.summary.pending))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2329')
        Text('待结算')
          .fontSize(11)
          .fontColor('#8A8F99')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text(String(this.summary.settled))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2329')
        Text('已结算')
          .fontSize(11)
          .fontColor('#8A8F99')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(14)
  }

  build() {
    NavDestination() {
      Column({ space: 10 }) {
        this.summaryCard()

        Scroll() {
          Row({ space: 8 }) {
            this.filterChip('全部', null)
            this.filterChip('待结算', PredictionStatus.PENDING)
            this.filterChip('已结算', PredictionStatus.SETTLED)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color('#4A6FA5')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.items.length === 0) {
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
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.items, (item: PredictionListItem) => {
              ListItem() {
                PredictionListCard({
                  item: item,
                  onTap: () => {
                    this.openDetail(item.id);
                  }
                })
              }
            }, (item: PredictionListItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#F5F6F8')
    }
    .title('预测日志')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param !== undefined) {
        const params = context.pathInfo.param as PredictionListParams;
        this.filter = params.status;
        if (this.service !== null) {
          this.refresh();
        }
      }
    })
    .onShown(() => {
      if (this.hasShownOnce) {
        this.refresh();
      } else {
        this.hasShownOnce = true;
      }
    })
  }

  private emptyTitle(): string {
    if (this.filter === PredictionStatus.PENDING) {
      return '暂无待结算预测';
    }
    if (this.filter === PredictionStatus.SETTLED) {
      return '暂无已结算预测';
    }
    return '还没有预测记录';
  }

  private emptyHint(): string {
    if (this.filter === PredictionStatus.PENDING) {
      return '到期的判断会在这里等你结算';
    }
    if (this.filter === PredictionStatus.SETTLED) {
      return '结算后的判断会保留在这里';
    }
    return '预测创建入口稍后开放';
  }
}
