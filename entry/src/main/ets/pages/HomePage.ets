import { AppTheme, LINE_HEIGHT } from '../theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppDestination } from '../components/AppDestination';
import { DashboardView } from '../views/DashboardView';
import { ProfileHeader } from '../components/ProfileHeader';
import { HomeDataService } from '../data/HomeDataService';
import { HomeSummary } from '../model/HomeModel';
import { ROUTES } from '../navigation/Routes';
import { PredictionListParams } from '../navigation/RouteParams';
import { subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';
import { appHealth, isDatabaseUnsupported } from '../app/AppHealth';
import { consumeJsonIssues } from '../db/SafeJson';
import { DbHelper } from '../db/DbHelper';
import { DebugFaults } from '../app/DebugFaults';
import { previewStore } from '../preview/PreviewStore';

/** Launch page: a compact identity band above the writing surface and the trace stream. */
@ComponentV2
export struct HomePage {
  @Require @Param pathStack: NavPathStack;
  @Local summary: HomeSummary = {
    totalNotes: 0, todayNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0,
    hitRate: 0, unreviewedDecisions: 0, totalAnchors: 0, totalRelations: 0,
    duePredictions: 0, revisionPredictions: 0, closedNodeReviews: 0, pendingDecisions: 0
  };
  @Local loadFailed: boolean = false;
  @Local isPreview: boolean = false;
  @Local dataNotice: string = '';
  @Local encryptionNotice: string = '';
  @Local dbBlocked: boolean = false;
  @Local dbMessage: string = '';
  private scroller: Scroller = new Scroller();
  private service: HomeDataService | null = null;
  private loadToken: number = 0;
  private listener: (() => void) | null = null;
  private lastNavAt: number = 0;

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
      this.summary = summary;
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

  private navTo(name: string, param: Object | null): void {
    const now = Date.now();
    if (now - this.lastNavAt < 600) {
      return;
    }
    this.lastNavAt = now;
    this.pathStack.pushPathByName(name, param);
  }

  private openPredictionList(): void {
    const params: PredictionListParams = { status: null };
    this.navTo(ROUTES.PREDICTION_LIST, params);
  }

  @Builder
  navItem(label: string, icon: Resource, selected: boolean, onTap: () => void) {
    Column({ space: AppTheme.spacing.s2 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([selected ? AppTheme.color.primary : AppTheme.color.textMuted])
      Text(label)
        .fontSize(AppTheme.font.caption)
        .fontColor(selected ? AppTheme.color.primary : AppTheme.color.textMuted)
    }
    .layoutWeight(1)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .accessibilityText(label)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  bottomNav() {
    Row() {
      this.navItem('工作台', $r('sys.symbol.house'), true, () => {
        this.scroller.scrollEdge(Edge.Top);
      })
      this.navItem('计划', $r('sys.symbol.calendar'), false, () => {
        this.navTo(ROUTES.PLAN, null);
      })
      this.navItem('预测', $r('sys.symbol.scope'), false, () => {
        this.openPredictionList();
      })
      this.navItem('关系', $r('sys.symbol.person_2'), false, () => {
        this.navTo(ROUTES.RELATION, null);
      })
      this.navItem('看板', $r('sys.symbol.diagnostic_analytics'), false, () => {
        this.navTo(ROUTES.ANALYTICS, null);
      })
    }
    .width('100%')
    .height(60)
    .backgroundColor(AppTheme.color.surface)
    .border({ width: { top: 0.5 }, color: AppTheme.color.border })
    .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8 })
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
        Column() {
          DashboardView({
            pathStack: this.pathStack,
            scroller: this.scroller
          })
        }
        .width('100%')
        .layoutWeight(1)

        this.bottomNav()
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  blockedBody() {
    Column({ space: AppTheme.spacing.s12 }) {
      Text('数据库打不开')
        .fontSize(AppTheme.font.headline)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.color.text)
      Text('记录仍保存在本机。可以先重试；一直失败时请重启应用。备份与导出需要数据库打开后才能使用。')
        .fontSize(AppTheme.font.bodyStrong)
        .lineHeight(LINE_HEIGHT.bodyStrong)
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
        .borderRadius(AppTheme.radius.lg)
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