import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewForm } from '../components/ReviewForm';
import { AppTheme } from '../theme/AppTheme';
import { ROUTES } from '../navigation/Routes';

/** Review session shell: week and month tabs, each owning its own draft. */
@ComponentV2
export struct ReviewPage {
  @Local activeTab: number = 0;
  private navStack: NavPathStack | null = null;

  @Builder
  actionsMenu() {
    Row({ space: 2 }) {
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
  }

  build() {
    NavDestination() {
      Tabs({ barPosition: BarPosition.Start, index: this.activeTab }) {
        TabContent() {
          ReviewForm({ period: ReviewPeriod.WEEK })
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
      .backgroundColor(AppTheme.color.page)
    }
    .title('复盘')
    .menus(this.actionsMenu)
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
  }
}
