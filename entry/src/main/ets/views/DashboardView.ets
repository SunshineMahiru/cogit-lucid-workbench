import {
  BodyReading,
  HomeModule,
  HomeSummary,
  PredictionItem,
  formatHitRate,
  formatNoteCount,
  hitRateCaption,
  todayLabel
} from '../model/HomeModel';
import { HomeDataService } from '../data/HomeDataService';
import { PredictionCard } from '../components/PredictionCard';
import { ReadingCard } from '../components/ReadingCard';
import { NoteListItem } from '../note/NoteListItem';
import { NoteEditParams, NoteListParams, PredictionDetailParams, PredictionListParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { APP_DISPLAY_NAME } from '../theme/AppIdentity';
import { AppTheme } from '../theme/AppTheme';
import { ReviewPeriod, ReviewService, ReviewStats, emptyReviewStats } from '../review';
import { ReviewPromptPanel } from '../components/ReviewPromptPanel';
import { WelcomeCard } from '../components/WelcomeCard';
import { PlanHomeCard } from '../components/PlanHomeCard';
import { OnboardingStore } from '../settings/OnboardingStore';
import { PREVIEW_BANNER } from '../preview/PreviewMode';
import { previewStore } from '../preview/PreviewStore';
import { subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';
import { ModuleGridCard } from './dashboard/ModuleGridCard';
import { RecentNotesCard } from './dashboard/RecentNotesCard';

/** Dashboard content: readings first, then module tiles and the two recent lists. */
@ComponentV2
export struct DashboardView {
  @Require @Param pathStack: NavPathStack;
  /** Set to false when the host page renders its own header above this content. */
  @Param showTitleBar: boolean = true;
  @Local today: string = todayLabel();
  @Local readings: BodyReading[] = [];
  @Local predictions: PredictionItem[] = [];
  @Local recentNotes: NoteListItem[] = [];
  @Local summary: HomeSummary = {
    totalNotes: 0, todayNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0, hitRate: 0,
    unreviewedDecisions: 0, totalAnchors: 0, totalRelations: 0
  };
  @Local moduleItems: HomeModule[] = [];
  @Local dataService: HomeDataService | null = null;
  @Local weekStats: ReviewStats = emptyReviewStats();
  private lastPushAt: number = 0;
  @Local weekReviewed: boolean = false;
  @Local dataVersion: number = 0;
  @Local isLoading: boolean = true;
  @Local loadFailed: boolean = false;
  @Local isPreview: boolean = false;
  @Local showWelcome: boolean = false;
  private reviewService: ReviewService | null = null;
  private refreshListener: (() => void) | null = null;

  async aboutToAppear(): Promise<void> {
    if (this.refreshListener === null) {
      this.refreshListener = () => {
        this.refresh();
      };
      subscribeHomeRefresh(this.refreshListener);
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showWelcome = true;
      this.loadPreview();
      return;
    }
    try {
      const onboarding = await OnboardingStore.open(context);
      this.showWelcome = !(await onboarding.isSeen());
    } catch (error) {
      this.showWelcome = true;
    }
    try {
      this.dataService = await HomeDataService.open(context);
      this.reviewService = await ReviewService.open(context);
      await this.refresh();
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '数据加载失败，已切换到演示数据' });
    }
  }

  aboutToDisappear(): void {
    if (this.refreshListener !== null) {
      unsubscribeHomeRefresh(this.refreshListener);
      this.refreshListener = null;
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.readings = previewStore.previewReadings();
    this.predictions = previewStore.pendingPredictions();
    this.recentNotes = previewStore.recentNotes();
    this.summary = previewStore.homeSummary();
    this.weekStats = previewStore.weekStats();
    this.weekReviewed = previewStore.weekReviewed();
    this.moduleItems = this.buildModules();
    this.dataVersion += 1;
    this.isLoading = false;
    this.loadFailed = false;
  }

  async refresh(): Promise<void> {
    if (this.isPreview) {
      this.loadPreview();
      return;
    }
    if (this.dataService === null) {
      this.isLoading = false;
      return;
    }
    this.isLoading = true;
    try {
      this.readings = await this.dataService.loadReadings();
      this.predictions = await this.dataService.loadPendingPredictions();
      this.recentNotes = await this.dataService.loadRecentNotes();
      this.summary = await this.dataService.loadSummary();
      this.moduleItems = this.buildModules();
      if (this.reviewService !== null) {
        this.weekStats = await this.reviewService.loadStats(ReviewPeriod.WEEK);
        const history = await this.reviewService.history(10);
        this.weekReviewed = history.some((item) =>
          item.period === ReviewPeriod.WEEK && item.rangeLabel === this.weekStats.rangeLabel);
      }
      this.dataVersion += 1;
      this.loadFailed = false;
    } catch (error) {
      this.loadFailed = true;
      this.getUIContext().getPromptAction().showToast({ message: '数据加载失败，请稍后重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private buildModules(): HomeModule[] {
    const sleep = this.readings.length > 0 ? this.readings[0].value : '--';
    return [
      {
        route: ROUTES.NOTE_EDIT,
        icon: '记',
        title: '速记',
        summary: formatNoteCount(this.summary.todayNotes, this.summary.totalNotes)
      },
      {
        route: ROUTES.PREDICTION_LIST,
        icon: '测',
        title: '预测',
        summary: `待结算 ${this.summary.pendingPredictions} · 命中 ` +
          `${formatHitRate(this.summary.hitRate, this.summary.settledPredictions)}`
      },
      {
        route: ROUTES.REVIEW,
        icon: '复',
        title: '复盘',
        summary: `待复盘 ${this.summary.unreviewedDecisions} 条`
      },
      {
        route: ROUTES.ANCHOR,
        icon: '锚',
        title: '锚点',
        summary: `共 ${this.summary.totalAnchors} 条`
      },
      {
        route: ROUTES.STATUS,
        icon: '状',
        title: '状态',
        summary: sleep === '--' ? '暂无读数' : `睡眠 ${sleep} 小时`
      },
      {
        route: ROUTES.RELATION,
        icon: '联',
        title: '关系',
        summary: `共 ${this.summary.totalRelations} 人`
      }
    ];
  }

  private openSettings(): void {
    this.guardedPush(ROUTES.SETTINGS, null, () => {
    });
  }

  private dismissWelcome(): void {
    this.showWelcome = false;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    OnboardingStore.open(context).then((store: OnboardingStore) => {
      store.markSeen().catch(() => {
      });
    }).catch(() => {
    });
  }

  private startFromWelcome(): void {
    this.dismissWelcome();
    this.openNoteEditor();
  }

  private guardedPush(name: string, param: Object | null, onPop: () => void): void {
    const now = Date.now();
    if (now - this.lastPushAt < 600) {
      return;
    }
    this.lastPushAt = now;
    this.pathStack.pushPathByName(name, param, onPop);
  }

  private openWeeklySettlement(): void {
    this.guardedPush(ROUTES.REVIEW_WEEKLY, null, () => {
      this.refresh();
    });
  }

  private openNoteEditor(): void {
    const params: NoteEditParams = { templateId: null };
    this.guardedPush(ROUTES.NOTE_EDIT, params, () => {
      this.refresh();
    });
  }

  private openNoteList(): void {
    const params: NoteListParams = { filterType: '' };
    this.guardedPush(ROUTES.NOTE_LIST, params, () => {
      this.refresh();
    });
  }

  private openPredictionList(): void {
    const params: PredictionListParams = { status: null };
    this.guardedPush(ROUTES.PREDICTION_LIST, params, () => {
      this.refresh();
    });
  }

  private openPredictionDetail(predictionId: string): void {
    const params: PredictionDetailParams = { predictionId: predictionId };
    this.guardedPush(ROUTES.PREDICTION_DETAIL, params, () => {
      this.refresh();
    });
  }

  private openModule(route: string): void {
    if (route === ROUTES.NOTE_EDIT) {
      this.openNoteEditor();
      return;
    }
    if (route === ROUTES.PREDICTION_LIST) {
      this.openPredictionList();
      return;
    }
    this.guardedPush(route, null, () => {
      this.refresh();
    });
  }

  @Builder
  loadingView() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(AppTheme.color.primary)
      Text('加载中...')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.textSecondary)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  emptyPredictionsView() {
    Column({ space: 8 }) {
      Text('暂无待结算预测')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.textSecondary)
      Text('点击「预测」模块创建一条')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textMuted)
    }
    .width('100%')
    .padding(AppTheme.spacing.s24)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.showTitleBar) {
        // Title bar
        Row() {
          Column({ space: 4 }) {
            Text(APP_DISPLAY_NAME)
              .fontSize(AppTheme.font.headline)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.color.text)
            Text(this.today)
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.textSecondary)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row({ space: 12 }) {
            Text(`${this.predictions.length} 条待结算`)
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.primary)
            Text('设置')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.primary)
              .accessibilityText('打开设置')
              .onClick(() => {
                this.openSettings();
              })
            Text('↻ 刷新')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.primary)
              .accessibilityText('刷新首页数据')
              .onClick(() => {
                this.refresh();
              })
          }
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s16, bottom: AppTheme.spacing.s12 })
        .border({ width: { bottom: 0.5 }, color: AppTheme.color.border })
      }

      if (this.loadFailed) {
        Row({ space: 8 }) {
          Text('本地数据暂不可用，当前仅展示界面')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.warning)
            .layoutWeight(1)
          Text('重试')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.refresh();
            })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
        .backgroundColor(AppTheme.color.warningSurface)
      }

      if (this.isPreview) {
        Text(PREVIEW_BANNER)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primaryDeep)
          .width('100%')
          .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
          .backgroundColor(AppTheme.color.tint)
      }

      if (this.isLoading) {
        this.loadingView()
      } else {
        Column() {
          Scroll() {
            Column({ space: 16 }) {
              if (this.showWelcome) {
                WelcomeCard({
                  onStart: () => {
                    this.startFromWelcome();
                  },
                  onDismiss: () => {
                    this.dismissWelcome();
                  }
                })
              }

              // Body readings
              Grid() {
                ForEach(this.readings, (reading: BodyReading) => {
                  GridItem() {
                    ReadingCard({ reading: reading })
                  }
                }, (reading: BodyReading) => `${reading.label}_${this.dataVersion}`)
              }
              .columnsTemplate('1fr 1fr 1fr')
              .rowsGap(0)
              .columnsGap(0)
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.lg)

              // Summary
              Row() {
                Column({ space: 4 }) {
                  Text(String(this.summary.totalNotes))
                    .fontSize(AppTheme.font.title)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                  Text('总速记')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)

                Column({ space: 4 }) {
                  Text(String(this.summary.pendingPredictions))
                    .fontSize(AppTheme.font.title)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                  Text('待结算')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)

                Column({ space: 4 }) {
                  Text(formatHitRate(this.summary.hitRate, this.summary.settledPredictions))
                    .fontSize(AppTheme.font.title)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.primary)
                  Text(hitRateCaption(this.summary.settledPredictions))
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.lg)

              // Weekly settlement
              Column({ space: 6 }) {
                Row() {
                  Text('本周结算')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.primaryDeep)
                  Blank()
                  Text('查看 ›')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.primary)
                }
                .width('100%')

                Text(this.weekStats.rangeLabel)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')

                Row({ space: 12 }) {
                  Text(`速记 ${this.weekStats.noteCount}`)
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                  Text(`决策 ${this.weekStats.decisionCount}`)
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                  Text(`命中率 ${formatHitRate(this.weekStats.hitRate, this.weekStats.settledPredictions)}`)
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.primary)
                  Blank()
                  Text(this.weekReviewed ? '已复盘' : '未复盘')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(this.weekReviewed ? AppTheme.color.success : AppTheme.color.warning)
                }
                .width('100%')
              }
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.selectedSurface)
              .borderRadius(AppTheme.radius.lg)
              .border({ width: 1, color: AppTheme.color.borderSelected })
              .onClick(() => {
                this.openWeeklySettlement();
              })

              PlanHomeCard({ pathStack: this.pathStack })

              ReviewPromptPanel({ period: ReviewPeriod.WEEK })

              ModuleGridCard({
                moduleItems: this.moduleItems,
                dataVersion: this.dataVersion,
                onOpen: (route: string) => {
                  this.openModule(route);
                }
              })

              RecentNotesCard({
                notes: this.recentNotes,
                dataVersion: this.dataVersion,
                onOpenAll: () => {
                  this.openNoteList();
                },
                onNoteTap: () => {
                  this.openNoteList();
                }
              })

              // Pending predictions
              Column({ space: 10 }) {
                Row() {
                  Text('今日待结算')
                    .fontSize(AppTheme.font.subtitle)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                  Blank()
                  Text('全部')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.textSecondary)
                    .onClick(() => {
                      this.openPredictionList();
                    })
                }
                .width('100%')

                if (this.predictions.length === 0) {
                  this.emptyPredictionsView()
                } else {
                  List({ space: 10 }) {
                    ForEach(this.predictions, (item: PredictionItem) => {
                      ListItem() {
                        PredictionCard({
                          item: item,
                          onTap: () => {
                            this.openPredictionDetail(item.id);
                          }
                        })
                      }
                    }, (item: PredictionItem) => `${item.id}_${this.dataVersion}`)
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.lg)
            }
            .width('100%')
            .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, bottom: AppTheme.spacing.s24 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)

          Row() {
            Text('＋ 速记')
              .fontSize(AppTheme.font.bodyStrong)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
              .backgroundColor(AppTheme.color.primary)
              .borderRadius(AppTheme.radius.xl)
              .onClick(() => {
                this.openNoteEditor();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s20 })
          .backgroundColor(AppTheme.color.page)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
