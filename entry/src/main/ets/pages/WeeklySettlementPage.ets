import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { ReviewPeriod, ReviewService, ReviewStats, emptyReviewStats } from '../review';
import { formatHitRate } from '../model/HomeModel';
import { ROUTES } from '../navigation/Routes';

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/** Weekly settlement summary; this week and last week share the same projection. */
@ComponentV2
export struct WeeklySettlementPage {
  @Local stats: ReviewStats = emptyReviewStats();
  @Local weekOffset: number = 0;
  @Local isLoading: boolean = true;
  private service: ReviewService | null = null;
  private navStack: NavPathStack | null = null;

  async aboutToAppear(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isLoading = false;
      return;
    }
    try {
      this.service = await ReviewService.open(hostContext);
      await this.load();
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '周结算加载失败' });
    }
  }

  private async load(): Promise<void> {
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.stats = await this.service.loadStatsFor(ReviewPeriod.WEEK, Date.now() + this.weekOffset * WEEK_MS);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '周结算加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private selectOffset(offset: number): void {
    if (this.weekOffset === offset) {
      return;
    }
    this.weekOffset = offset;
    this.load();
  }

  private openReview(): void {
    if (this.navStack !== null) {
      this.navStack.pushPathByName(ROUTES.REVIEW, null);
    }
  }

  @Builder
  offsetChip(label: string, value: number) {
    Text(label)
      .fontSize(12)
      .fontColor(this.weekOffset === value ? Color.White : AppTheme.color.text)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.weekOffset === value ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(14)
      .onClick(() => {
        this.selectOffset(value);
      })
  }

  @Builder
  metric(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text(label)
        .fontSize(10)
        .fontColor(AppTheme.color.textSecondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    NavDestination() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppTheme.color.primary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.color.page)
      } else {
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                this.offsetChip('本周', 0)
                this.offsetChip('上周', -1)
                Blank()
                Text(this.stats.rangeLabel)
                  .fontSize(10)
                  .fontColor(AppTheme.color.textMuted)
              }
              .width('100%')

              SectionCard() {
                Column({ space: 12 }) {
                  Row() {
                    this.metric(`${this.stats.noteCount}`, '速记')
                    this.metric(`${this.stats.decisionCount}`, '决策')
                  }
                  .width('100%')
                  Row() {
                    this.metric(`${this.stats.settledPredictions}`, '已结算预测')
                    this.metric(formatHitRate(this.stats.hitRate, this.stats.settledPredictions), '命中率')
                  }
                  .width('100%')
                }
                .width('100%')
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Row() {
                    Text('待结算预测')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text(`${this.stats.pendingPredictions} 条`)
                      .fontSize(12)
                      .fontColor(AppTheme.color.text)
                  }
                  .width('100%')
                  Row() {
                    Text('价值锚点')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text(`${this.stats.anchorCount} 条`)
                      .fontSize(12)
                      .fontColor(AppTheme.color.text)
                  }
                  .width('100%')
                  Text('周结算只汇总本机记录，不写入新的结算表；复盘结果仍由四步表单保存。')
                    .fontSize(10)
                    .lineHeight(16)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Column() {
            Text('开始周复盘')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 })
              .backgroundColor(AppTheme.color.primary)
              .borderRadius(12)
              .onClick(() => {
                this.openReview();
              })
          }
          .width('100%')
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: 8, bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(AppTheme.color.page)
      }
    }
    .title('周结算')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
  }
}
