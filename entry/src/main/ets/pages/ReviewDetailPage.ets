import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ReviewDetailView, ReviewService } from '../review';
import { Anchor } from '../model/Anchor';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewDetailParams } from '../navigation/RouteParams';

/** Read-only four-step review with the anchors it actually referenced. */
@ComponentV2
export struct ReviewDetailPage {
  @Local detail: ReviewDetailView = {
    id: '',
    period: ReviewPeriod.WEEK,
    periodLabel: '',
    rangeLabel: '',
    action: '',
    createdAtLabel: '',
    anchorCount: 0,
    facts: '',
    interpretation: '',
    contradiction: '',
    anchors: []
  };
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  private navStack: NavPathStack | null = null;

  private async load(reviewId: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isLoading = false;
      this.missing = true;
      return;
    }
    try {
      const service = await ReviewService.open(hostContext);
      const detail = await service.find(reviewId);
      if (detail === null) {
        this.missing = true;
      } else {
        this.detail = detail;
      }
    } catch (error) {
      this.missing = true;
    } finally {
      this.isLoading = false;
    }
  }

  @Builder
  stepSection(title: string, body: string) {
    SectionCard() {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        Text(body.length > 0 ? body : '（未填写）')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(AppTheme.color.text)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
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
      } else if (this.missing) {
        Column() {
          NoteEmptyState({
            title: '复盘记录不存在',
            hint: '可能已经被删除',
            actionLabel: '返回',
            onAction: () => {
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.color.page)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            SectionCard() {
              Column({ space: 5 }) {
                Row({ space: 6 }) {
                  Text(this.detail.periodLabel)
                    .fontSize(10)
                    .fontColor(AppTheme.color.primaryDeep)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor(AppTheme.color.tint)
                    .borderRadius(6)
                  Text(this.detail.rangeLabel)
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .layoutWeight(1)
                }
                .width('100%')
                Text(this.detail.createdAtLabel)
                  .fontSize(10)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            this.stepSection('1. 事实', this.detail.facts)
            this.stepSection('2. 解释', this.detail.interpretation)
            this.stepSection('3. 矛盾', this.detail.contradiction)

            SectionCard() {
              Column({ space: 6 }) {
                Text('4. 行动')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Text(this.detail.action.length > 0 ? this.detail.action : '（未填写）')
                  .fontSize(13)
                  .lineHeight(21)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text(`锚点对照 · ${this.detail.anchors.length} 条`)
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                if (this.detail.anchors.length === 0) {
                  Text('本次未选择锚点')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                } else {
                  ForEach(this.detail.anchors, (anchor: Anchor) => {
                    Column({ space: 2 }) {
                      Text(anchor.text)
                        .fontSize(12)
                        .lineHeight(19)
                        .fontColor(AppTheme.color.text)
                        .width('100%')
                      Text(anchor.source)
                        .fontSize(9)
                        .fontColor(AppTheme.color.textMuted)
                        .width('100%')
                    }
                    .width('100%')
                  }, (anchor: Anchor) => anchor.id)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.page)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(AppTheme.color.page)
      }
    }
    .title('复盘详情')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param === undefined) {
        this.isLoading = false;
        this.missing = true;
        return;
      }
      const params = context.pathInfo.param as ReviewDetailParams;
      this.load(params.reviewId);
    })
  }
}
