import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ReviewHistoryItem, ReviewService } from '../review';
import { ReviewDetailParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { previewStore } from '../preview/PreviewStore';

/** Saved review sessions, newest first; taps open the read-only detail. */
@ComponentV2
export struct ReviewHistoryPage {
  @Local items: ReviewHistoryItem[] = [];
  @Local isLoading: boolean = true;
  @Local range: string = 'all';
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.items = previewStore.reviewHistory();
      this.isLoading = false;
      return;
    }
    try {
      const service = await ReviewService.open(hostContext);
      this.items = await service.history();
      this.isLoading = false;
    } catch (error) {
      this.items = previewStore.reviewHistory();
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '复盘历史加载失败，已切换到演示数据' });
    }
  }

  /** Rows created inside the chosen range; all rows for 'all'. */
  private filtered(): ReviewHistoryItem[] {
    if (this.range === 'all') {
      return this.items;
    }
    const days = this.range === '7d' ? 7 : 30;
    const since = Date.now() - days * 24 * 60 * 60 * 1000;
    const rows: ReviewHistoryItem[] = [];
    for (const item of this.items) {
      if ((item.createdAt ?? 0) >= since) {
        rows.push(item);
      }
    }
    return rows;
  }

  private openDetail(reviewId: string): void {
    if (this.navStack === null) {
      return;
    }
    const params: ReviewDetailParams = { reviewId: reviewId };
    this.navStack.pushPathByName(ROUTES.REVIEW_DETAIL, params);
  }

  build() {
    AppDestination({
      route: 'review_history',
      title: '复盘历史',
      content: () => {
        this.reviewHistoryBody();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.load();
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }

  @Builder
  rangeChip(value: string, label: string, chipId: string) {
    Text(label)
      .id(chipId)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.range === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.range === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .onClick(() => {
        this.range = value;
      })
  }

  @Builder
  reviewHistoryBody() {
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
          Column() {
            Row({ space: 8 }) {
              this.rangeChip('all', '全部', 'history_range_all')
              this.rangeChip('7d', '近七天', 'history_range_7d')
              this.rangeChip('30d', '近三十天', 'history_range_30d')
            }
            .width('100%')
            .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: AppTheme.spacing.page })

            if (this.filtered().length === 0) {
              Column() {
                Text('这段时间没有复盘')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textMuted)
              }
              .width('100%')
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            } else {
              Scroll() {
                Column({ space: 8 }) {
                  ForEach(this.filtered(), (item: ReviewHistoryItem) => {
                    SectionCard({ contentPadding: 0 }) {
                      Column({ space: 5 }) {
                        Row({ space: 6 }) {
                          Text(item.periodLabel)
                            .fontSize(AppTheme.font.caption)
                            .fontColor(AppTheme.color.primaryDeep)
                            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                            .backgroundColor(AppTheme.color.tint)
                            .borderRadius(AppTheme.radius.sm)
                          Text(item.rangeLabel)
                            .fontSize(AppTheme.font.body)
                            .fontColor(AppTheme.color.textSecondary)
                            .layoutWeight(1)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          Text(item.createdAtLabel)
                            .fontSize(AppTheme.font.caption)
                            .fontColor(AppTheme.color.textMuted)
                        }
                        .width('100%')

                        Text(item.action.length > 0 ? item.action : '（未填写行动）')
                          .fontSize(AppTheme.font.bodyStrong)
                          .lineHeight(20)
                          .fontColor(AppTheme.color.text)
                          .width('100%')
                          .maxLines(2)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })

                        Text(item.anchorCount > 0 ? `对照 ${item.anchorCount} 条锚点` : '未选择锚点')
                          .fontSize(AppTheme.font.caption)
                          .fontColor(AppTheme.color.textMuted)
                          .width('100%')
                      }
                      .width('100%')
                      .padding(AppTheme.spacing.s16)
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
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }
}
