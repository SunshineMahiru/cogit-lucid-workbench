import { AppTheme } from '../theme/AppTheme';
import { PageBackground } from './PageBackground';
import { backgroundKeyForRoute } from '../settings/PageBackgroundService';

/**
 * Shared destination shell. Every route builds its page through this component so the
 * opaque surface and the background layer exist once and new pages inherit both.
 */
@ComponentV2
export struct AppDestination {
  @Require @Param route: string;
  @Param title: string = '';
  @Param hideTitleBar: boolean = false;
  @BuilderParam content: () => void;
  @BuilderParam menus: () => void = this.emptyMenus;
  @Event onDestinationReady: (context: NavDestinationContext) => void = () => {
  };
  @Event onDestinationShown: () => void = () => {
  };
  @Event onDestinationBackPressed: () => boolean = () => false;

  @Builder
  emptyMenus() {
  }

  build() {
    NavDestination() {
      Stack() {
        PageBackground({ route: backgroundKeyForRoute(this.route) })
        Column() {
          this.content()
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title(this.title)
    .hideTitleBar(this.hideTitleBar)
    .backgroundColor(Color.Transparent)
    .menus(this.menus)
    .onReady((context: NavDestinationContext) => {
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
