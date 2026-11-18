import { AppTheme } from '../theme/AppTheme';
import { TabHeader } from '../components/TabHeader';
import { PredictionLogView } from './PredictionLogView';
import { ROUTES } from '../navigation/Routes';
import { TabKey } from '../navigation/TabItems';
import {
  activeTab,
  subscribeTabRefresh,
  unsubscribeTabRefresh
} from '../app/TabRefreshBus';

/**
 * Prediction tab: one header with the create entry, then the prediction log whose single list also
 * carries the dashboard. Switching to this tab reloads both the rows and the statistics.
 */
@ComponentV2
export struct PredictionTabView {
  @Require @Param pathStack: NavPathStack;
  @Local refreshToken: number = 0;
  private tabListener: (() => void) | null = null;
  private lastPushAt: number = 0;

  aboutToAppear(): void {
    if (this.tabListener === null) {
      this.tabListener = () => {
        if (activeTab() !== TabKey.PREDICTION) {
          return;
        }
        this.refreshToken += 1;
      };
      subscribeTabRefresh(TabKey.PREDICTION, this.tabListener);
    }
  }

  aboutToDisappear(): void {
    if (this.tabListener !== null) {
      unsubscribeTabRefresh(TabKey.PREDICTION, this.tabListener);
      this.tabListener = null;
    }
  }

  private openCreate(): void {
    const now = Date.now();
    if (now - this.lastPushAt < 600) {
      return;
    }
    this.lastPushAt = now;
    this.pathStack.pushPathByName(ROUTES.PREDICTION_CREATE, { sourcePredictionId: null }, () => {
      this.refreshToken += 1;
    });
  }

  @Builder
  createAction() {
    Text('＋')
      .id('prediction_tab_create')
      .fontSize(AppTheme.font.headline)
      .fontColor(AppTheme.color.primary)
      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8 })
      .accessibilityText('新建预测')
      .onClick(() => {
        this.openCreate();
      })
  }

  build() {
    Column() {
      TabHeader({
        title: '预测',
        actions: () => {
          this.createAction();
        }
      })

      PredictionLogView({
        pathStack: this.pathStack,
        refreshToken: this.refreshToken,
        collapsibleNotes: true,
        showDashboard: true
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}