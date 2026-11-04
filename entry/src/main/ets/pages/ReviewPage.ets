import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewForm } from '../components/ReviewForm';
import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { ROUTES } from '../navigation/Routes';
import { PlanNodeParams, PlanReviewParams } from '../navigation/RouteParams';

/** Review session shell: week and month tabs, each owning its own draft. */
@ComponentV2
export struct ReviewPage {
  @Local activeTab: number = 0;
  @Local planId: string = '';
  @Local planNodeId: string = '';
  private navStack: NavPathStack | null = null;

  @Builder
  actionsMenu() {
    Row({ space: 2 }) {
      if (this.planNodeId.length > 0) {
        Text('返回节点')
          .fontSize(14)
          .fontColor(AppTheme.color.primary)
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            this.openPlanNode();
          })
      }
      Text('历史')
        .fontSize(14)
        .fontColor(AppTheme.color.primary)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          if (this.navStack !== null) {
            this.navStack.pushPathByName(ROUTES.REVIEW_HISTORY, null);
          }
        })
      Text('Agent')
        .fontSize(14)
        .fontColor(AppTheme.color.primary)
        .padding({ left: 4, right: 14 })
        .onClick(() => {
          if (this.navStack !== null) {
            this.navStack.pushPathByName(ROUTES.REVIEW_AGENT, null);
          }
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  private openPlanNode(): void {
    if (this.navStack === null || this.planNodeId.length === 0) {
      return;
    }
    const names = this.navStack.getAllPathName();
    if (names.length > 1 && names[names.length - 2] === ROUTES.PLAN_NODE) {
      this.navStack.pop();
      return;
    }
    const params: PlanNodeParams = { nodeId: this.planNodeId };
    this.navStack.pushPathByName(ROUTES.PLAN_NODE, params);
  }

  build() {
    AppDestination({
      route: 'review',
      title: '复盘',
      content: () => {
        this.reviewBody();
      },
      menus: () => {
        this.actionsMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param !== undefined) {
          const params = context.pathInfo.param as PlanReviewParams;
          this.planId = params.planId;
          this.planNodeId = params.nodeId;
        }
      }
    })
  }

  @Builder
  reviewBody() {
      Tabs({ barPosition: BarPosition.Start, index: this.activeTab }) {
        TabContent() {
          ReviewForm({
            period: ReviewPeriod.WEEK,
            planId: this.planId,
            planNodeId: this.planNodeId,
            onBackToPlan: () => {
              this.openPlanNode();
            }
          })
        }
        .tabBar('周复盘')

        TabContent() {
          ReviewForm({ period: ReviewPeriod.MONTH })
        }
        .tabBar('月复盘')
      }
      .barMode(BarMode.Fixed)
      .barHeight(44)
      .onChange((index: number) => {
        this.activeTab = index;
      })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }
}
