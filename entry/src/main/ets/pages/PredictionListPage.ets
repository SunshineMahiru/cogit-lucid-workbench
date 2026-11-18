import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { PredictionLogView } from '../views/PredictionLogView';
import { PredictionListParams } from '../navigation/RouteParams';
import { PredictionStatus } from '../model/PredictionStatus';
import { ROUTES } from '../navigation/Routes';

/**
 * Prediction log route: a thin wrapper around PredictionLogView. The title bar, the create entry
 * and the statistics entry stay here; statistics now scrolls to the dashboard inside the same list
 * instead of opening the standalone dashboard page.
 */
@ComponentV2
export struct PredictionListPage {
  @Local navStack: NavPathStack | null = null;
  @Local refreshToken: number = 0;
  @Local scrollToken: number = 0;
  @Local initialFilter: PredictionStatus | null = null;
  private hasShownOnce: boolean = false;

  private openCreate(): void {
    if (this.navStack === null) {
      return;
    }
    this.navStack.pushPathByName(ROUTES.PREDICTION_CREATE, { sourcePredictionId: null }, () => {
      this.refreshToken += 1;
    });
  }

  @Builder
  actionsMenu() {
    Row({ space: 2 }) {
      Text('统计')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8 })
        .accessibilityText('跳到页内数据看板')
        .onClick(() => {
          this.scrollToken += 1;
        })
      Text('＋')
        .fontSize(AppTheme.font.headline)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s4, right: AppTheme.spacing.s16 })
        .accessibilityText('新建预测')
        .onClick(() => {
          this.openCreate();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  listBody() {
    if (this.navStack !== null) {
      PredictionLogView({
        pathStack: this.navStack,
        refreshToken: this.refreshToken,
        scrollToStatsToken: this.scrollToken,
        initialFilter: this.initialFilter,
        collapsibleNotes: true,
        showDashboard: true
      })
    }
  }

  build() {
    AppDestination({
      route: 'prediction_list',
      title: '预测日志',
      content: () => {
        this.listBody();
      },
      menus: () => {
        this.actionsMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param !== undefined) {
          const params = context.pathInfo.param as PredictionListParams;
          this.initialFilter = params.status;
        }
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.refreshToken += 1;
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }
}