import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ReviewHistoryItem, ReviewService } from '../review';
import { ReviewDetailParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';

/** Saved review sessions, newest first; taps open the read-only detail. */
@ComponentV2
export struct ReviewHistoryPage {
  @Local items: ReviewHistoryItem[] = [];
  @Local isLoading: boolean = true;
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isLoading = false;
      return;
    }
    try {
      const service = await ReviewService.open(hostContext);
      this.items = await service.history();
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '复盘历史加载失败' });
    }
  }

  private openDetail(reviewId: string): void {
    if (this.navStack === null) {
      return;
    }
    const params: ReviewDetailParams = { reviewId: reviewId };
    this.navStack.pushPathByName(ROUTES.REVIEW_DETAIL, params);
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(AppTheme.color.primary)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.items.length === 0) {
          Column() {
            NoteEmptyState({
              title: '还没有复盘记录',
              hint: '完成一次周复盘或月复盘后，会在这里留下锚点对照',
              dashed: true
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.items, (item: ReviewHistoryItem) => {
                SectionCard({ contentPadding: 0 }) {
                  Column({ space: 5 }) {
                    Row({ space: 6 }) {
                      Text(item.periodLabel)
                        .fontSize(9)
                        .fontColor(AppTheme.color.primaryDeep)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor(AppTheme.color.tint)
                        .borderRadius(6)
                      Text(item.rangeLabel)
                        .fontSize(11)
                        .fontColor(AppTheme.color.textSecondary)
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(item.createdAtLabel)
                        .fontSize(9)
                        .fontColor(AppTheme.color.textMuted)
                    }
                    .width('100%')

                    Text(item.action.length > 0 ? item.action : '（未填写行动）')
                      .fontSize(13)
                      .lineHeight(20)
                      .fontColor(AppTheme.color.text)
                      .width('100%')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(item.anchorCount > 0 ? `对照 ${item.anchorCount} 条锚点` : '未选择锚点')
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                  .width('100%')
                  .padding(14)
                  .onClick(() => {
                    this.openDetail(item.id);
                  })
                }
              }, (item: ReviewHistoryItem) => item.id)
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title('复盘历史')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
    .onShown(() => {
      if (this.hasShownOnce) {
        this.load();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
