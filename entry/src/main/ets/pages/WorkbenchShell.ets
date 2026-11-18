import { AppTheme } from '../theme/AppTheme';
import { PageBackground } from '../components/PageBackground';
import { TAB_ITEMS, TabKey, tabItemAt, tabIndex, tabKeyAt } from '../navigation/TabItems';
import { requestTabRefresh, setActiveTab } from '../app/TabRefreshBus';
import { WorkbenchView } from '../views/WorkbenchView';
import { MineView } from '../views/MineView';
import { LogsView } from '../views/LogsView';
import { DrawerView } from '../views/DrawerView';
import { PredictionTabView } from '../views/PredictionTabView';

/**
 * Shell of the five main tabs: the bottom bar stays visible, switching replaces the content
 * without any horizontal slide, and pushed pages cover the whole screen because Navigation lives
 * outside this component. The selected index is owned by the host so a page-level back press can
 * return to the workbench tab.
 */
@ComponentV2
export struct WorkbenchShell {
  @Require @Param pathStack: NavPathStack;
  /** Currently selected tab, mirrored from the host entry page. */
  @Param activeIndex: number = 0;
  @Event onActiveChange: (index: number) => void = () => {
  };
  @Local backgroundKey: string = tabItemAt(0).backgroundKey;
  /** Drives external switches, e.g. a page-level back press returning to the workbench. */
  private controller: TabsController = new TabsController();

  @Monitor('activeIndex')
  onActiveIndexChanged(): void {
    this.controller.changeIndex(this.activeIndex);
  }

  /** Resolves a tab to its verified system symbol; only symbols already used in the app appear. */
  private tabIcon(index: number): Resource {
    const key = tabKeyAt(index);
    if (key === TabKey.LOGS) {
      return $r('sys.symbol.calendar');
    }
    if (key === TabKey.PREDICTION) {
      return $r('sys.symbol.scope');
    }
    if (key === TabKey.DRAWER) {
      return $r('sys.symbol.diagnostic_analytics');
    }
    if (key === TabKey.MINE) {
      return $r('sys.symbol.person_2');
    }
    return $r('sys.symbol.house');
  }

  /** Reports a new selection to the host; the guard keeps repeated taps from re-reporting. */
  private selectIndex(index: number): void {
    if (index < 0 || index >= TAB_ITEMS.length) {
      return;
    }
    if (index !== this.activeIndex) {
      this.onActiveChange(index);
    }
  }

  /** Switches to another tab from inside a view, e.g. a module card on the workbench. */
  private switchTab(key: TabKey): void {
    const index = tabIndex(key);
    if (index === this.activeIndex) {
      return;
    }
    setActiveTab(key);
    this.onActiveChange(index);
  }

  private applyTab(index: number): void {
    const key = tabKeyAt(index);
    setActiveTab(key);
    this.backgroundKey = tabItemAt(index).backgroundKey;
    requestTabRefresh(key);
  }

  @Builder
  tabBarItem(index: number) {
    Column({ space: AppTheme.spacing.s2 }) {
      SymbolGlyph(this.tabIcon(index))
        .fontSize(22)
        .fontColor([index === this.activeIndex ? AppTheme.color.primary : AppTheme.color.textMuted])
      Text(tabItemAt(index).label)
        .fontSize(AppTheme.font.caption)
        .fontColor(index === this.activeIndex ? AppTheme.color.primary : AppTheme.color.textMuted)
        .maxLines(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityText(tabItemAt(index).label)
  }

  build() {
    Stack() {
      PageBackground({ route: this.backgroundKey })

      Tabs({ index: this.activeIndex, controller: this.controller }) {
        TabContent() {
          WorkbenchView({
            pathStack: this.pathStack,
            onSwitchTab: (key: TabKey) => {
              this.switchTab(key);
            }
          })
        }
        .tabBar(this.tabBarItem(0))

        TabContent() {
          LogsView({ pathStack: this.pathStack })
        }
        .tabBar(this.tabBarItem(1))

        TabContent() {
          PredictionTabView({ pathStack: this.pathStack })
        }
        .tabBar(this.tabBarItem(2))

        TabContent() {
          DrawerView({ pathStack: this.pathStack })
        }
        .tabBar(this.tabBarItem(3))

        TabContent() {
          MineView({ pathStack: this.pathStack })
        }
        .tabBar(this.tabBarItem(4))
      }
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .barHeight(56)
      .barBackgroundColor(AppTheme.color.surface)
      .animationMode(AnimationMode.NO_ANIMATION)
      .animationDuration(0)
      .scrollable(false)
      .onTabBarClick((index: number) => {
        // Highlight follows the tap at once; onChange only finalises the switch.
        setActiveTab(tabKeyAt(index));
        this.selectIndex(index);
      })
      .onChange((index: number) => {
        this.applyTab(index);
        this.selectIndex(index);
      })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.color.page)
  }
}