import { AppTheme } from '../theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { AppDestination } from '../components/AppDestination';
import { DashboardView } from '../views/DashboardView';
import { ProfileHeader } from '../components/ProfileHeader';
import { HomeDataService } from '../data/HomeDataService';
import { HomePulse, HomeSummary, NO_RATE_TEXT } from '../model/HomeModel';
import { subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';

const EMPTY_SUMMARY: HomeSummary = {
  totalNotes: 0, todayNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0,
  hitRate: 0, unreviewedDecisions: 0, totalAnchors: 0, totalRelations: 0
};

/** Launch page: identity band and four live counters above the existing dashboard content. */
@ComponentV2
export struct HomePage {
  @Require @Param pathStack: NavPathStack;
  @Local summary: HomeSummary = EMPTY_SUMMARY;
  @Local pulse: HomePulse = { streakDays: 0, lastReviewLabel: NO_RATE_TEXT };
  @Local loadFailed: boolean = false;
  private service: HomeDataService | null = null;
  private loadToken: number = 0;
  private listener: (() => void) | null = null;

  aboutToAppear(): void {
    if (this.listener === null) {
      this.listener = () => {
        this.load();
      };
      subscribeHomeRefresh(this.listener);
    }
    this.load();
  }

  aboutToDisappear(): void {
    if (this.listener !== null) {
      unsubscribeHomeRefresh(this.listener);
      this.listener = null;
    }
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const token = ++this.loadToken;
    try {
      if (this.service === null) {
        this.service = await HomeDataService.open(context);
      }
      const summary = await this.service.loadSummary();
      if (token !== this.loadToken) {
        return;
      }
      const pulse = await this.service.loadPulse();
      if (token !== this.loadToken) {
        return;
      }
      this.summary = summary;
      this.pulse = pulse;
      this.loadFailed = false;
    } catch (error) {
      if (token === this.loadToken) {
        this.loadFailed = true;
      }
    }
  }

  build() {
    AppDestination({
      route: 'home',
      hideTitleBar: true,
      content: () => {
        this.homeBody();
      },
      onDestinationBackPressed: () => {
        const context = this.getUIContext().getHostContext();
        if (context !== undefined) {
          (context as common.UIAbilityContext).terminateSelf();
        }
        return true;
      }
    })
  }

  @Builder
  homeBody() {
      Column() {
      ProfileHeader({
        pathStack: this.pathStack
      })
      if (this.loadFailed) {
        Text('首页数据读取失败，点此重试')
          .fontSize(11)
          .fontColor(AppTheme.color.danger)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            this.load();
          })
      }
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(`${this.summary.todayNotes} 条`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text('今日速记')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
        .layoutWeight(1)
        .padding({ top: 6, bottom: 6 })
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(8)

        Column({ space: 2 }) {
          Text(`${this.summary.pendingPredictions} 条`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text('待结算')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
        .layoutWeight(1)
        .padding({ top: 6, bottom: 6 })
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(8)

        Column({ space: 2 }) {
          Text(`${this.pulse.streakDays} 天`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text('连续记录')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
        .layoutWeight(1)
        .padding({ top: 6, bottom: 6 })
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(8)

        Column({ space: 2 }) {
          Text(this.pulse.lastReviewLabel)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text('最近复盘')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
        .layoutWeight(1)
        .padding({ top: 6, bottom: 6 })
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(8)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })

      Column() {
        DashboardView({ pathStack: this.pathStack, showTitleBar: false })
      }
      .width('100%')
      .layoutWeight(1)
    }
      .width('100%')
      .height('100%')
  }
}
