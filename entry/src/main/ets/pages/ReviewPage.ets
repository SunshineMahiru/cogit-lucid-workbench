import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewForm } from '../components/ReviewForm';
import { ROUTES } from '../navigation/Routes';

/** Review session shell: week and month tabs, each owning its own draft. */
@ComponentV2
export struct ReviewPage {
  @Local activeTab: number = 0;
  private navStack: NavPathStack | null = null;

  @Builder
  agentMenu() {
    Text('Agent')
      .fontSize(14)
      .fontColor('#4A6FA5')
      .padding({ left: 12, right: 16 })
      .onClick(() => {
        if (this.navStack !== null) {
          this.navStack.pushPathByName(ROUTES.REVIEW_AGENT, null);
        }
      })
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
      .backgroundColor('#F5F6F8')
    }
    .title('复盘')
    .menus(this.agentMenu)
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
  }
}
