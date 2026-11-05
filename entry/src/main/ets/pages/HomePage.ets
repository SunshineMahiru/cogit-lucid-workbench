import { AppTheme } from '../theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppDestination } from '../components/AppDestination';
import { DashboardView } from '../views/DashboardView';
import { ProfileHeader } from '../components/ProfileHeader';
import { HomeDataService } from '../data/HomeDataService';
import { HomePulse, HomeSummary, NO_RATE_TEXT } from '../model/HomeModel';
import { subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';
import { appHealth, isDatabaseUnsupported } from '../app/AppHealth';
import { consumeJsonIssues } from '../db/SafeJson';
import { previewStore } from '../preview/PreviewStore';
import { ROUTES } from '../navigation/Routes';

/** Launch page: identity band and four live counters above the existing dashboard content. */
@ComponentV2
export struct HomePage {
  @Require @Param pathStack: NavPathStack;
  @Local summary: HomeSummary = {
    totalNotes: 0, todayNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0,
    hitRate: 0, unreviewedDecisions: 0, totalAnchors: 0, totalRelations: 0
  };
  @Local pulse: HomePulse = { streakDays: 0, lastReviewLabel: NO_RATE_TEXT };
  @Local loadFailed: boolean = false;
  @Local isPreview: boolean = false;
  @Local dataNotice: string = '';
  @Local dbBlocked: boolean = false;
  @Local dbMessage: string = '';
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
      this.loadPreview();
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
      this.dataNotice = consumeJsonIssues() > 0 ? '部分记录格式异常，已跳过' : '';
      this.loadFailed = false;
      this.isPreview = false;
      this.dbBlocked = false;
      appHealth.markReady();
    } catch (error) {
      if (token !== this.loadToken) {
        return;
      }
      const failure = error as BusinessError;
      const code: number = failure.code ?? 0;
      const message: string = failure.message ?? '';
      if (isDatabaseUnsupported(code)) {
        this.loadPreview();
        return;
      }
      appHealth.markFailed(message);
      this.dbMessage = message;
      this.dbBlocked = true;
      this.loadFailed = false;
      this.isPreview = false;
      this.service = null;
    }
  }

  private loadPreview(): void {
    this.summary = previewStore.homeSummary();
    this.pulse = previewStore.homePulse();
    this.isPreview = true;
    this.dbBlocked = false;
    this.loadFailed = false;
  }

  private retryDatabase(): void {
    appHealth.reset();
    this.service = null;
    this.dbBlocked = false;
    this.dbMessage = '';
    this.load();
  }

  private exitApplication(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      (context as common.UIAbilityContext).terminateSelf();
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
    if (this.dbBlocked) {
      this.blockedBody()
    } else {
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
      } else if (this.isPreview) {
        Text('演示数据 · 数据库不可用')
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 6, bottom: 2 })
      } else if (this.dataNotice.length > 0) {
        Text(this.dataNotice)
          .fontSize(10)
          .fontColor(AppTheme.color.warning)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 6, bottom: 2 })
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
      .padding({ left: 20, right: 20, top: 8, bottom: 4 })

      Row() {
        Text('数据看板 ›')
          .id('home_dashboard_entry')
          .fontSize(11)
          .fontColor(AppTheme.color.primary)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(18)
          .onClick(() => {
            this.pathStack.pushPathByName(ROUTES.ANALYTICS, null);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ left: 20, right: 20, top: 2, bottom: 6 })

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

  @Builder
  blockedBody() {
    Column({ space: 14 }) {
      Text('数据库打不开')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.color.text)
      Text('记录仍保存在本机。可以先重试；一直失败时请重启应用。备份与导出需要数据库打开后才能使用。')
        .fontSize(12)
        .lineHeight(19)
        .fontColor(AppTheme.color.textSecondary)
        .textAlign(TextAlign.Center)
      if (this.dbMessage.length > 0) {
        Text(this.dbMessage)
          .fontSize(10)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(AppTheme.color.textMuted)
          .textAlign(TextAlign.Center)
      }
      Text('重试')
        .fontSize(14)
        .fontColor(Color.White)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 })
        .backgroundColor(AppTheme.color.primary)
        .borderRadius(12)
        .onClick(() => {
          this.retryDatabase();
        })
      Text('退出应用')
        .fontSize(12)
        .fontColor(AppTheme.color.textSecondary)
        .padding({ top: 4, bottom: 4 })
        .onClick(() => {
          this.exitApplication();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 28, right: 28 })
    .backgroundColor(AppTheme.color.page)
  }
}
