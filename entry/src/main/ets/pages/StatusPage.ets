import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { StatusDayRow } from '../components/StatusDayRow';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { StatusDayRow as StatusRow, StatusOverview, StatusService } from '../status';
import { ReadingFlag } from '../analysis/status/ReadingRules';
import { ROUTES } from '../navigation/Routes';
import { PREVIEW_STATUS_OVERVIEW } from '../preview/PreviewData';
import { PREVIEW_WRITE_BLOCKED } from '../preview/PreviewMode';

/** Physiological status panel: latest reading, seven-record summary and recent rows. */
@ComponentV2
export struct StatusPage {
  @Local service: StatusService | null = null;
  @Local overview: StatusOverview = {
    latest: null,
    summary: { days: 0, averageSleep: 0, totalExercise: 0, totalAlerts: 0, flaggedDays: 0 },
    recent: []
  };
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  @Local isPreview: boolean = false;
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await StatusService.open(hostContext);
      this.overview = await this.service.overview();
      this.isLoading = false;
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '状态数据加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.overview = PREVIEW_STATUS_OVERVIEW;
    this.isLoading = false;
  }

  private async refresh(): Promise<void> {
    if (this.isPreview) {
      this.overview = PREVIEW_STATUS_OVERVIEW;
      this.isLoading = false;
      return;
    }
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.overview = await this.service.overview();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '状态数据加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private async seed(): Promise<void> {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: PREVIEW_WRITE_BLOCKED });
      return;
    }
    if (this.service === null || this.isSeeding) {
      return;
    }
    this.isSeeding = true;
    try {
      const added = await this.service.seedDemoRecords();
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已载入 ${added} 天示例读数` : '已有读数，未重复载入'
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '载入失败，请重试' });
    } finally {
      this.isSeeding = false;
    }
  }

  private openHistory(): void {
    if (this.navStack === null) {
      return;
    }
    this.navStack.pushPathByName(ROUTES.STATUS_HISTORY, null);
  }

  @Builder
  statItem(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text(label)
        .fontSize(10)
        .fontColor(AppTheme.color.textSecondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(AppTheme.color.primary)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.overview.latest === null) {
          Column() {
            NoteEmptyState({
              title: '还没有状态读数',
              hint: '状态面板优先展示睡眠、运动与凌晨报警；示例数据仅用于演示',
              actionLabel: this.isSeeding ? '载入中…' : '载入示例读数',
              dashed: true,
              onAction: () => {
                this.seed();
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page })
        } else {
          Scroll() {
            Column({ space: 12 }) {
              SectionCard() {
                Column({ space: 10 }) {
                  Row() {
                    Text('最近一次读数')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text(this.overview.latest.date)
                      .fontSize(11)
                      .fontColor(AppTheme.color.textMuted)
                  }
                  .width('100%')

                  Row({ space: 6 }) {
                    Text(`${this.overview.latest.sleepHours}`)
                      .fontSize(32)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.overview.latest.flags.length > 0 ? AppTheme.color.danger : AppTheme.color.text)
                    Text('小时睡眠')
                      .fontSize(12)
                      .fontColor(AppTheme.color.textSecondary)
                      .margin({ top: 12 })
                    Blank()
                    Text(`运动 ${this.overview.latest.exerciseCount} 次 · 报警 ${this.overview.latest.alertCount} 次`)
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                  }
                  .width('100%')

                  Progress({ value: this.overview.latest.sleepHours, total: 10, type: ProgressType.Linear })
                    .height(8)
                    .color(this.overview.latest.flags.length > 0 ? AppTheme.color.danger : AppTheme.color.primary)
                    .backgroundColor('#EEF0F3')

                  if (this.overview.latest.flags.length > 0) {
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.overview.latest.flags, (flag: ReadingFlag) => {
                        Text(flag.message)
                          .fontSize(10)
                          .fontColor(AppTheme.color.danger)
                          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                          .backgroundColor(AppTheme.color.dangerSurface)
                          .borderRadius(6)
                          .margin({ right: 6, bottom: 4 })
                      }, (flag: ReadingFlag) => flag.code)
                    }
                    .width('100%')
                  }

                  if (this.overview.latest.note.length > 0) {
                    Text(this.overview.latest.note)
                      .fontSize(11)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 10 }) {
                  Row() {
                    this.statItem(`${this.overview.summary.averageSleep}`, '平均睡眠')
                    this.statItem(`${this.overview.summary.totalExercise}`, '运动合计')
                    this.statItem(`${this.overview.summary.totalAlerts}`, '凌晨报警')
                  }
                  .width('100%')
                  Text(`最近 ${this.overview.summary.days} 次记录 · 有提示 ${this.overview.summary.flaggedDays} 天`)
                    .fontSize(10)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
              }

              SectionCard() {
                Column({ space: 10 }) {
                  Row() {
                    Text('最近记录')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text('全部记录 ›')
                      .fontSize(11)
                      .fontColor(AppTheme.color.primary)
                      .onClick(() => {
                        this.openHistory();
                      })
                  }
                  .width('100%')

                  ForEach(this.overview.recent.slice(0, 3), (row: StatusRow) => {
                    StatusDayRow({ row: row, compact: true })
                  }, (row: StatusRow) => row.id)
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title('状态面板')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
    .onShown(() => {
      if (this.hasShownOnce) {
        this.refresh();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
