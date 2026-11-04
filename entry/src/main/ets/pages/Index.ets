import { applyTheme } from '../theme/AppTheme';
import { resourceManager } from '@kit.LocalizationKit';
import { HomePage } from './HomePage';
import { ROUTES } from '../navigation/Routes';
import { PlaceholderPage } from './PlaceholderPage';
import { NoteEditPage } from './NoteEditPage';
import { NoteListPage } from './NoteListPage';
import { NoteDetailPage } from './NoteDetailPage';
import { PredictionListPage } from './PredictionListPage';
import { PredictionDetailPage } from './PredictionDetailPage';
import { PredictionStatsPage } from './PredictionStatsPage';
import { AnalyticsPage } from './AnalyticsPage';
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
import { IdentityEditPage } from './IdentityEditPage';
import { BackgroundApplyPage } from './BackgroundApplyPage';
import { PageBackgroundService } from '../settings/PageBackgroundService';
import { pageTransitionOf } from '../navigation/PageTransitionHooks';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.pathStack.pushPathByName(ROUTES.HOME, null, false);
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

  @Builder
  pageMap(name: string) {
    this.pageContent(name)
  }

  @Builder
  pageContent(name: string) {
    if (name === ROUTES.HOME) {
      HomePage({ pathStack: this.pathStack })
    } else if (name === ROUTES.NOTE_EDIT) {
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
    } else if (name === ROUTES.ANALYTICS) {
      AnalyticsPage()
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
        Stack() {
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.pageMap)
      .customNavContentTransition(
        (from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation):
          NavigationAnimatedTransition | undefined => {
          const touchesFirstLevel = from.index === 0 || to.index === 0 ||
            (from.index === 1 && to.index === 1);
          if (!touchesFirstLevel) {
            return undefined;
          }
          return {
            timeout: 600,
            transition: (proxy: NavigationTransitionProxy) => {
              const fromHooks = pageTransitionOf(from.navDestinationId) ?? pageTransitionOf(from.name);
              const toHooks = pageTransitionOf(to.navDestinationId) ?? pageTransitionOf(to.name);
              if (fromHooks === undefined || toHooks === undefined) {
                proxy.finishTransition();
                return;
              }
              fromHooks.exitStart();
              toHooks.enterStart();
              setTimeout(() => {
                if (operation === NavigationOperation.POP) {
                  this.getUIContext().animateTo({
                    duration: 110,
                    curve: Curve.EaseIn,
                    onFinish: () => {
                      this.getUIContext().animateTo({
                        duration: 110,
                        curve: Curve.EaseOut,
                        onFinish: () => {
                          proxy.finishTransition();
                        }
                      }, () => {
                        toHooks.enterEnd();
                      });
                    }
                  }, () => {
                    fromHooks.exitEnd();
                  });
                  return;
                }
                this.getUIContext().animateTo({
                  duration: 220,
                  curve: Curve.EaseOut,
                  onFinish: () => {
                    proxy.finishTransition();
                  }
                }, () => {
                  toHooks.enterEnd();
                });
              }, 32);
            }
          };
        })
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopStart)
    .backgroundColor(Color.Transparent)
  }
}
