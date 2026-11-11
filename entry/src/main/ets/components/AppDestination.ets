import { AppTheme } from '../theme/AppTheme';
import { PageBackground } from './PageBackground';
import { backgroundKeyForRoute } from '../settings/PageBackgroundService';

/**
 * Shared destination shell. Every route builds its page through this component so the
 * opaque surface, the custom title bar and the background layer exist once.
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
  header() {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 72, right: 72 })
        .textAlign(TextAlign.Center)
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(AppTheme.color.text)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .accessibilityText('返回')
          .onClick(() => {
            this.goBack();
          })
        Blank()
        Row({ space: 4 }) {
          this.menus()
        }
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
  }

  private goBack(): void {
    if (this.onDestinationBackPressed()) {
      return;
    }
    if (this.navStack !== null) {
      this.navStack.pop();
    }
  }

  build() {
    NavDestination() {
      Stack() {
        PageBackground({ route: backgroundKeyForRoute(this.route) })
        Column() {
          if (!this.hideTitleBar) {
            this.header()
          }
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
    .hideTitleBar(true)
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
