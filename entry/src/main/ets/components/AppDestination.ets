import { AppTheme } from '../theme/AppTheme';
import { PageBackground } from './PageBackground';
import { backgroundKeyForRoute } from '../settings/PageBackgroundService';
import {
  PageTransitionHooks,
  registerPageTransition,
  unregisterPageTransition
} from '../navigation/PageTransitionHooks';

/**
 * Shared destination shell. Every route builds its page through this component so the
 * opaque surface, the custom title bar and the background layer exist once.
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

  @Local pageOpacity: number = 1;
  @Local bodyOpacity: number = 1;
  @Local bodyOffset: number = 0;
  private destinationId: string = '';
  private navStack: NavPathStack | null = null;

  aboutToAppear(): void {
    this.registerHooks(this.route);
  }

  @Builder
  emptyMenus() {
  }

  @Builder
  header() {
    Row({ space: 4 }) {
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
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row({ space: 8 }) {
        this.menus()
      }
      .width(56)
      .height(40)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
  }

  private goBack(): void {
    if (this.onDestinationBackPressed()) {
      return;
    }
    if (this.navStack !== null) {
      this.navStack.pop();
    }
  }

  private registerHooks(key: string): void {
    const hooks: PageTransitionHooks = {
      enterStart: () => {
        this.pageOpacity = 1;
        this.bodyOpacity = 0;
        this.bodyOffset = 12;
      },
      enterEnd: () => {
        this.bodyOpacity = 1;
        this.bodyOffset = 0;
      },
      exitStart: () => {
        this.pageOpacity = 1;
      },
      exitEnd: () => {
        this.pageOpacity = 0;
      }
    };
    registerPageTransition(key, hooks);
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
        .opacity(this.bodyOpacity)
        .translate({ y: this.bodyOffset })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .hideTitleBar(true)
    .backgroundColor(AppTheme.color.page)
    .opacity(this.pageOpacity)
    .onReady((context: NavDestinationContext) => {
      this.destinationId = context.navDestinationId ?? '';
      this.navStack = context.pathStack;
      this.registerHooks(this.destinationId);
      this.onDestinationReady(context);
    })
    .onShown(() => {
      this.onDestinationShown();
    })
    .onDisAppear(() => {
      unregisterPageTransition(this.destinationId);
      unregisterPageTransition(this.route);
    })
    .onBackPressed(() => {
      return this.onDestinationBackPressed();
    })
  }
}
