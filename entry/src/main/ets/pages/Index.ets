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
import { PageBackground } from '../components/PageBackground';
import { backgroundKeyForRoute } from '../settings/PageBackgroundService';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    try {
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        const configuration = context.resourceManager.getConfigurationSync();
        applyTheme(configuration.colorMode === resourceManager.ColorMode.DARK);
      }
    } catch (error) {
    }
  }

  @Builder
  pageMap(name: string) {
    Stack() {
      this.pageContent(name)
      PageBackground({ route: backgroundKeyForRoute(name) })
    }
    .width('100%')
    .height('100%')
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
    } else {
      PlaceholderPage({ title: '页面未实现', hint: name })
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack() {
        DashboardView({ pathStack: this.pathStack })
        PageBackground({ route: 'home' })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
    .backgroundColor(AppTheme.color.page)
  }
}
