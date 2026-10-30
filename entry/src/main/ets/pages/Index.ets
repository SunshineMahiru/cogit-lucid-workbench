import { AppTheme, applyTheme } from '../theme/AppTheme';
import { resourceManager } from '@kit.LocalizationKit';
import { DashboardView } from '../views/DashboardView';
import { ROUTES } from '../navigation/Routes';
import { PlaceholderPage } from './PlaceholderPage';
import { NoteEditPage } from './NoteEditPage';
import { NoteListPage } from './NoteListPage';
import { NoteDetailPage } from './NoteDetailPage';
import { PredictionListPage } from './PredictionListPage';
import { PredictionDetailPage } from './PredictionDetailPage';
import { PredictionStatsPage } from './PredictionStatsPage';
import { PredictionCreatePage } from './PredictionCreatePage';
import { PredictionSettlePage } from './PredictionSettlePage';
import { ReviewPage } from './ReviewPage';
import { ReviewAgentPage } from './ReviewAgentPage';
import { WeeklySettlementPage } from './WeeklySettlementPage';
import { ReviewHistoryPage } from './ReviewHistoryPage';
import { ReviewDetailPage } from './ReviewDetailPage';
import { AnchorPage } from './AnchorPage';
import { RelationListPage } from './RelationListPage';
import { RelationDetailPage } from './RelationDetailPage';
import { RelationEditPage } from './RelationEditPage';
import { RelationGraphPage } from './RelationGraphPage';
import { StatusPage } from './StatusPage';
import { StatusHistoryPage } from './StatusHistoryPage';
import { StatusEditPage } from './StatusEditPage';
import { SettingsPage } from './SettingsPage';
import { BackgroundApplyPage } from './BackgroundApplyPage';
import { PageBackground } from '../components/PageBackground';
import { backgroundKeyForRoute, PageBackgroundService } from '../settings/PageBackgroundService';
import { setPageEmpty } from '../settings/PageBackgroundBus';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();
  @Local currentGroup: string = 'home';

  aboutToAppear(): void {
    this.trackCurrentPage();
    try {
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        const configuration = context.resourceManager.getConfigurationSync();
        applyTheme(configuration.colorMode === resourceManager.ColorMode.DARK);
        PageBackgroundService.recoverLegacyBackgrounds(context).catch(() => {
        });
      }
    } catch (error) {
    }
  }

  /** Keeps the shared background layer on the group of the page currently on top. */
  private trackCurrentPage(): void {
    this.pathStack.setInterception({
      didShow: (from: NavBar | NavDestinationContext, to: NavBar | NavDestinationContext,
        operation: NavigationOperation) => {
        const context = to as NavDestinationContext;
        if (context.pathInfo !== undefined) {
          this.currentGroup = backgroundKeyForRoute(context.pathInfo.name);
        } else {
          this.currentGroup = 'home';
        }
        setPageEmpty(false);
      }
    });
  }

  @Builder
  pageMap(name: string) {
    this.pageContent(name)
  }

  @Builder
  pageContent(name: string) {
    if (name === ROUTES.NOTE_EDIT) {
      NoteEditPage()
    } else if (name === ROUTES.NOTE_LIST) {
      NoteListPage()
    } else if (name === ROUTES.NOTE_DETAIL) {
      NoteDetailPage()
    } else if (name === ROUTES.PREDICTION_LIST) {
      PredictionListPage()
    } else if (name === ROUTES.PREDICTION_DETAIL) {
      PredictionDetailPage()
    } else if (name === ROUTES.PREDICTION_STATS) {
      PredictionStatsPage()
    } else if (name === ROUTES.PREDICTION_CREATE) {
      PredictionCreatePage()
    } else if (name === ROUTES.PREDICTION_SETTLE) {
      PredictionSettlePage()
    } else if (name === ROUTES.REVIEW) {
      ReviewPage()
    } else if (name === ROUTES.REVIEW_AGENT) {
      ReviewAgentPage()
    } else if (name === ROUTES.REVIEW_WEEKLY) {
      WeeklySettlementPage()
    } else if (name === ROUTES.REVIEW_HISTORY) {
      ReviewHistoryPage()
    } else if (name === ROUTES.REVIEW_DETAIL) {
      ReviewDetailPage()
    } else if (name === ROUTES.ANCHOR) {
      AnchorPage()
    } else if (name === ROUTES.RELATION) {
      RelationListPage()
    } else if (name === ROUTES.RELATION_DETAIL) {
      RelationDetailPage()
    } else if (name === ROUTES.RELATION_EDIT) {
      RelationEditPage()
    } else if (name === ROUTES.RELATION_GRAPH) {
      RelationGraphPage()
    } else if (name === ROUTES.STATUS) {
      StatusPage()
    } else if (name === ROUTES.STATUS_HISTORY) {
      StatusHistoryPage()
    } else if (name === ROUTES.STATUS_EDIT) {
      StatusEditPage()
    } else if (name === ROUTES.SETTINGS) {
      SettingsPage()
    } else if (name === ROUTES.BACKGROUND_APPLY) {
      BackgroundApplyPage()
    } else {
      PlaceholderPage({ title: '页面未实现', hint: name })
    }
  }

  build() {
    Stack() {
      PageBackground({ route: this.currentGroup })
      Navigation(this.pathStack) {
        DashboardView({ pathStack: this.pathStack })
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.pageMap)
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
    .backgroundColor(AppTheme.color.page)
  }
}
