import { AppTheme } from '../theme/AppTheme';
import { TabHeader } from '../components/TabHeader';
import { QuickCaptureBar } from '../components/QuickCaptureBar';
import { NoteListView } from './NoteListView';
import { ROUTES } from '../navigation/Routes';
import { TabKey } from '../navigation/TabItems';
import {
  activeTab,
  requestTabRefresh,
  subscribeTabRefresh,
  unsubscribeTabRefresh
} from '../app/TabRefreshBus';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/**
 * Logs tab: one-line capture on top, the shared note list below. Saving a note refreshes the list
 * and tells the workbench and prediction tabs that their counts are stale.
 */
@ComponentV2
export struct LogsView {
  @Require @Param pathStack: NavPathStack;
  @Local refreshToken: number = 0;
  private tabListener: (() => void) | null = null;
  private lastPushAt: number = 0;

  aboutToAppear(): void {
    if (this.tabListener === null) {
      this.tabListener = () => {
        if (activeTab() !== TabKey.LOGS) {
          return;
        }
        this.refreshToken += 1;
      };
      subscribeTabRefresh(TabKey.LOGS, this.tabListener);
    }
  }

  aboutToDisappear(): void {
    if (this.tabListener !== null) {
      unsubscribeTabRefresh(TabKey.LOGS, this.tabListener);
      this.tabListener = null;
    }
  }

  private openEditor(): void {
    const now = Date.now();
    if (now - this.lastPushAt < 600) {
      return;
    }
    this.lastPushAt = now;
    this.pathStack.pushPathByName(ROUTES.NOTE_EDIT, { templateId: null }, () => {
      this.refreshToken += 1;
    });
  }

  private afterCapture(): void {
    this.refreshToken += 1;
    notifyHomeRefresh();
    requestTabRefresh(TabKey.WORKBENCH);
    requestTabRefresh(TabKey.PREDICTION);
  }

  @Builder
  createAction() {
    Text('＋')
      .id('logs_create')
      .fontSize(AppTheme.font.headline)
      .fontColor(AppTheme.color.primary)
      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8 })
      .accessibilityText('新建速记')
      .onClick(() => {
        this.openEditor();
      })
  }

  build() {
    Column() {
      TabHeader({
        title: '日志',
        actions: () => {
          this.createAction();
        }
      })

      Column() {
        QuickCaptureBar({
          placeholder: '此刻发生了什么',
          hint: '一句现场、一种感受、一个身体信号都可以。不必解释。',
          onSaved: () => {
            this.afterCapture();
          }
        })
      }
      .width('100%')
      .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, bottom: AppTheme.spacing.s4 })

      NoteListView({
        pathStack: this.pathStack,
        refreshToken: this.refreshToken,
        initialFilter: '',
        showFab: false
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}