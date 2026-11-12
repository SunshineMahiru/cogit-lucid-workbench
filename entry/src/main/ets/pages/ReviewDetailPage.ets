import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ReviewDetailView, ReviewService } from '../review';
import { Anchor } from '../model/Anchor';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewDetailParams, PlanNodeParams, PlanAttachParams } from '../navigation/RouteParams';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { ROUTES } from '../navigation/Routes';
import { previewStore } from '../preview/PreviewStore';

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
      this.loadPreview(reviewId);
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
      this.loadPreview(reviewId);
    } finally {
      this.isLoading = false;
    }
  }

  private loadPreview(reviewId: string): void {
    const detail = previewStore.findReview(reviewId);
    if (detail === null) {
      this.missing = true;
    } else {
      this.detail = detail;
    }
    this.isLoading = false;
  }

  @Builder
  stepSection(title: string, body: string) {
    SectionCard() {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        Text(body.length > 0 ? body : '（未填写）')
          .fontSize(AppTheme.font.bodyStrong)
          .lineHeight(21)
          .fontColor(AppTheme.color.text)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  private openAttach(): void {
    if (this.navStack === null || this.detail.id.length === 0) {
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.REVIEW,
      targetId: this.detail.id,
      label: `${this.detail.periodLabel} ${this.detail.rangeLabel}`
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  @Builder
  planMenu() {
    Text('计划')
      .fontSize(AppTheme.font.subtitle)
      .fontColor(AppTheme.color.primary)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s16 })
      .height(56)
      .onClick(() => {
        this.openAttach();
      })
  }

  build() {
    AppDestination({
      route: 'review_detail',
      title: '复盘详情',
      content: () => {
        this.reviewDetailBody();
      },
      menus: () => {
        this.planMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          this.missing = true;
          return;
        }
        const params = context.pathInfo.param as ReviewDetailParams;
        this.load(params.reviewId);
      }
    })
  }

  @Builder
  reviewDetailBody() {
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
        .backgroundColor(Color.Transparent)
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
        .backgroundColor(Color.Transparent)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            SectionCard() {
              Column({ space: 5 }) {
                Row({ space: 6 }) {
                  Text(this.detail.periodLabel)
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.primaryDeep)
                    .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                    .backgroundColor(AppTheme.color.tint)
                    .borderRadius(AppTheme.radius.sm)
                  Text(this.detail.rangeLabel)
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .layoutWeight(1)
                }
                .width('100%')
                Text(this.detail.createdAtLabel)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                Text('已完成记录不可修改')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.warning)
                  .width('100%')
                if (this.detail.planNodeId !== undefined) {
                  Text('返回计划节点 ›')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.primary)
                    .width('100%')
                    .onClick(() => {
                      if (this.navStack !== null && this.detail.planNodeId !== undefined) {
                        const params: PlanNodeParams = { nodeId: this.detail.planNodeId };
                        this.navStack.pushPathByName(ROUTES.PLAN_NODE, params);
                      }
                    })
                }
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
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Text(this.detail.action.length > 0 ? this.detail.action : '（未填写）')
                  .fontSize(AppTheme.font.bodyStrong)
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
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                if (this.detail.anchors.length === 0) {
                  Text('本次未选择锚点')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                } else {
                  ForEach(this.detail.anchors, (anchor: Anchor) => {
                    Column({ space: 2 }) {
                      Text(anchor.text)
                        .fontSize(AppTheme.font.bodyStrong)
                        .lineHeight(19)
                        .fontColor(AppTheme.color.text)
                        .width('100%')
                      Text(anchor.source)
                        .fontSize(AppTheme.font.caption)
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
        .backgroundColor(Color.Transparent)
      }
  }
}
