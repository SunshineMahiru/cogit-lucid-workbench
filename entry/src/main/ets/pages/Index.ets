import { applyTheme } from '../theme/AppTheme';
import { resourceManager } from '@kit.LocalizationKit';
import { WorkbenchShell } from './WorkbenchShell';
import { ROUTES } from '../navigation/Routes';
import { TabKey, tabIndex } from '../navigation/TabItems';
import { activeTab, requestActiveTabRefresh, setActiveTab } from '../app/TabRefreshBus';
import { runBackHandler } from '../app/BackGuard';
import { PlaceholderPage } from './PlaceholderPage';
import { NoteEditPage } from './NoteEditPage';
import { NoteListPage } from './NoteListPage';
import { NoteDetailPage } from './NoteDetailPage';
import { PredictionListPage } from './PredictionListPage';
import { PredictionDetailPage } from './PredictionDetailPage';
import { AnalyticsPage } from './AnalyticsPage';
import { PlanListPage } from './PlanListPage';
import { PlanEditPage } from './PlanEditPage';
import { PlanDetailPage } from './PlanDetailPage';
import { PlanNodePage } from './PlanNodePage';
import { PlanLinkPickerPage } from './PlanLinkPickerPage';
import { PlanAttachPage } from './PlanAttachPage';
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
import { StatusPage } from './StatusPage';
import { StatusHistoryPage } from './StatusHistoryPage';
import { StatusEditPage } from './StatusEditPage';
import { SettingsPage } from './SettingsPage';
import { IdentityEditPage } from './IdentityEditPage';
import { BackgroundApplyPage } from './BackgroundApplyPage';
import { PageBackgroundService } from '../settings/PageBackgroundService';

/** Entry page: Navigation owns the stack, the tab shell is its root content. */
@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();
  /** Selected main tab; owned here so the back press can return to the workbench. */
  @Local activeIndex: number = 0;

  aboutToAppear(): void {
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
    setActiveTab(TabKey.WORKBENCH);
  }

  /** Returning to the foreground refreshes the tab that is on screen. */
  onPageShow(): void {
    requestActiveTabRefresh();
  }

  /**
   * Back inside a pushed page is left to the system. With an empty stack, a tab other than the
   * workbench is consumed here and returns there; on the workbench the system exits as before.
   */
  onBackPress(): boolean {
    if (this.pathStack.size() > 0) {
      return false;
    }
    if (runBackHandler()) {
      return true;
    }
    if (activeTab() !== TabKey.WORKBENCH) {
      setActiveTab(TabKey.WORKBENCH);
      this.activeIndex = tabIndex(TabKey.WORKBENCH);
      return true;
    }
    return false;
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
    } else if (name === ROUTES.ANALYTICS) {
      AnalyticsPage()
    } else if (name === ROUTES.PLAN) {
      PlanListPage()
    } else if (name === ROUTES.PLAN_EDIT) {
      PlanEditPage()
    } else if (name === ROUTES.PLAN_DETAIL) {
      PlanDetailPage()
    } else if (name === ROUTES.PLAN_NODE) {
      PlanNodePage()
    } else if (name === ROUTES.PLAN_LINK_PICKER) {
      PlanLinkPickerPage()
    } else if (name === ROUTES.PLAN_ATTACH) {
      PlanAttachPage()
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
    } else if (name === ROUTES.STATUS) {
      StatusPage()
    } else if (name === ROUTES.STATUS_HISTORY) {
      StatusHistoryPage()
    } else if (name === ROUTES.STATUS_EDIT) {
      StatusEditPage()
    } else if (name === ROUTES.SETTINGS) {
      SettingsPage()
    } else if (name === ROUTES.IDENTITY_EDIT) {
      IdentityEditPage()
    } else if (name === ROUTES.BACKGROUND_APPLY) {
      BackgroundApplyPage()
    } else {
      PlaceholderPage({ title: '页面未实现', hint: name })
    }
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        WorkbenchShell({
          pathStack: this.pathStack,
          activeIndex: this.activeIndex,
          onActiveChange: (index: number) => {
            this.activeIndex = index;
          }
        })
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.pageMap)
      .onNavBarStateChange((isVisible: boolean) => {
        // Returning from a pushed page re-shows the tab shell; the active tab reloads its data.
        if (isVisible) {
          requestActiveTabRefresh();
        }
      })
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
    .backgroundColor(Color.Transparent)
  }
}