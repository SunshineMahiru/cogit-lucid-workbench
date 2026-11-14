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
import { DbHelper } from '../db/DbHelper';
import { DebugFaults } from '../app/DebugFaults';
import { previewStore } from '../preview/PreviewStore';
import { ROUTES } from '../navigation/Routes';
import { NoteEditParams, PredictionListParams } from '../navigation/RouteParams';

/** Launch page: identity band, four quick entries and the dashboard content. */
@ComponentV2
export struct HomePage {
  @Require @Param pathStack: NavPathStack;
  @Local summary: HomeSummary = {
    totalNotes: 0, todayNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0,
    hitRate: 0, unreviewedDecisions: 0, totalAnchors: 0, totalRelations: 0,
    duePredictions: 0, revisionPredictions: 0, closedNodeReviews: 0
  };
  @Local pulse: HomePulse = { streakDays: 0, lastReviewLabel: NO_RATE_TEXT };
  @Local loadFailed: boolean = false;
  @Local isPreview: boolean = false;
  @Local dataNotice: string = '';
  @Local encryptionNotice: string = '';
  @Local dbBlocked: boolean = false;
  @Local dbMessage: string = '';
  @Local moduleOffset: number = 0;
  private scroller: Scroller = new Scroller();
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
      this.encryptionNotice = (DbHelper.usesPlaintextFallback() || DebugFaults.encryptionFallback(context)) ?
        '数据库未能加密，记录以明文保存在本机；建议更新系统或重装应用' : '';
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

  private openRecordNow(): void {
    const params: NoteEditParams = { templateId: null };
    this.pathStack.pushPathByName(ROUTES.NOTE_EDIT, params, () => {
      this.load();
    });
  }

  private openTodo(): void {
    const params: PredictionListParams = { status: null };
    this.pathStack.pushPathByName(ROUTES.PREDICTION_LIST, params, () => {
      this.load();
    });
  }

  private openPlan(): void {
    this.pathStack.pushPathByName(ROUTES.PLAN, null, () => {
      this.load();
    });
  }

  /** Scrolls the dashboard scroll area down to the module grid. */
  private scrollToModules(): void {
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: this.moduleOffset,
      animation: { duration: 300, curve: Curve.EaseInOut }
    });
  }

  @Builder
  quickEntry(label: string, entryId: string, onTap: () => void) {
    Text(label)
      .id(entryId)
      .fontSize(AppTheme.font.body)
      .fontColor(AppTheme.color.primary)
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)
      .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
      .backgroundColor(AppTheme.color.surface)
      .borderRadius(AppTheme.radius.md)
      .onClick(() => {
        onTap();
      })
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
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.danger)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
          .onClick(() => {
            this.load();
          })
      } else if (this.isPreview) {
        Text('演示数据 · 数据库不可用')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s2 })
      } else if (this.encryptionNotice.length > 0) {
        Text(this.encryptionNotice)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.danger)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s2 })
      } else if (this.dataNotice.length > 0) {
        Text(this.dataNotice)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.warning)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s2 })
      }
      Row({ space: 8 }) {
        this.quickEntry('记录此刻', 'home_record_now', () => {
          this.openRecordNow();
        })
        this.quickEntry('待校正', 'home_todo', () => {
          this.openTodo();
        })
        this.quickEntry('当前计划', 'home_plan_entry_top', () => {
          this.openPlan();
        })
        this.quickEntry('全部模块', 'home_modules_all', () => {
          this.scrollToModules();
        })
      }
      .width('100%')
      .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s4 })

      Text(`待校正：到期预测 ${this.summary.duePredictions ?? 0} · 待修订模型 ${this.summary.revisionPredictions ?? 0} · 已结束周节点 ${this.summary.closedNodeReviews ?? 0}`)
        .id('home_todo_counts')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)

      Column() {
        DashboardView({
          pathStack: this.pathStack,
          showTitleBar: false,
          scroller: this.scroller,
          onModuleOffset: (offsetY: number) => {
            this.moduleOffset = offsetY;
          }
        })
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
        .fontSize(AppTheme.font.headline)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.color.text)
      Text('记录仍保存在本机。可以先重试；一直失败时请重启应用。备份与导出需要数据库打开后才能使用。')
        .fontSize(AppTheme.font.bodyStrong)
        .lineHeight(19)
        .fontColor(AppTheme.color.textSecondary)
        .textAlign(TextAlign.Center)
      if (this.dbMessage.length > 0) {
        Text(this.dbMessage)
          .fontSize(AppTheme.font.caption)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(AppTheme.color.textMuted)
          .textAlign(TextAlign.Center)
      }
      Text('重试')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(Color.White)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
        .backgroundColor(AppTheme.color.primary)
        .borderRadius(AppTheme.radius.md)
        .onClick(() => {
          this.retryDatabase();
        })
      Text('退出应用')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
        .padding({ top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
        .onClick(() => {
          this.exitApplication();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: AppTheme.spacing.s24, right: AppTheme.spacing.s24 })
    .backgroundColor(AppTheme.color.page)
  }
}
