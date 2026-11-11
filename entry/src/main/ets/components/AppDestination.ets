import { AppTheme } from '../theme/AppTheme';
import { PageBackground } from './PageBackground';
import { backgroundKeyForRoute } from '../settings/PageBackgroundService';

/**
 * Shared destination shell. Every route builds its page through this component so the
 * opaque surface, the system title bar and the background layer exist once.
 */
@ComponentV2
export struct AppDestination {
  @Require @Param route: string;
  @Param title: string = '';
  @Param hideTitleBar: boolean = false;
  @BuilderParam content: () => void = this.emptyContent;
  @BuilderParam menus: () => void = this.emptyMenus;
  @Event onDestinationReady: (context: NavDestinationContext) => void = () => {
  };
  @Event onDestinationShown: () => void = () => {
  };
  @Event onDestinationBackPressed: () => boolean = () => false;

  private navStack: NavPathStack | null = null;

  @Builder
  emptyContent() {
  }

  @Builder
  emptyMenus() {
  }

  @Builder
  menusSlot() {
    this.menus()
  }

  build() {
    NavDestination() {
      Stack() {
        PageBackground({ route: backgroundKeyForRoute(this.route) })
        Column() {
          Column() {
            this.content()
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title(this.title)
    .menus(this.menusSlot)
    .hideTitleBar(this.hideTitleBar)
    .backgroundColor(AppTheme.color.page)
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      this.onDestinationReady(context);
    })
    .onShown(() => {
      this.onDestinationShown();
    })
    .onBackPressed(() => {
      return this.onDestinationBackPressed();
    })
  }
}
