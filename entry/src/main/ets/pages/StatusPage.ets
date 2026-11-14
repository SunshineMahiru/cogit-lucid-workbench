import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { StatusDayRow } from '../components/StatusDayRow';
import { StatusTrendCard } from '../components/StatusTrendCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { StatusDayRow as StatusRow, StatusOverview, StatusService, defaultRule } from '../status';
import { ReadingFlag } from '../analysis/status/ReadingRules';
import { ObservationRule, OBSERVATION_RULE_NOTE, sanitizeObservationRule } from '../analysis/status/ObservationRule';
import { capacityText } from '../model/CapacityJudgment';
import { ROUTES } from '../navigation/Routes';
import { StatusEditParams } from '../navigation/RouteParams';
import { PREVIEW_STATUS_OVERVIEW } from '../preview/PreviewData';
import { PREVIEW_WRITE_BLOCKED } from '../preview/PreviewMode';

/** Physiological status panel: latest reading, seven-record summary and recent rows. */
@ComponentV2
export struct StatusPage {
  @Local service: StatusService | null = null;
  @Local overview: StatusOverview = {
    latest: null,
    summary: { days: 0, averageSleep: 0, sleepDays: 0, totalExercise: 0, totalAlerts: 0, unknownDays: 0, flaggedDays: 0 },
    recent: []
  };
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  @Local isPreview: boolean = false;
  @Local listVersion: number = 0;
  @Local rule: ObservationRule = defaultRule();
  @Local ruleVisible: boolean = false;
  @Local ruleSleep: string = '';
  @Local ruleAlert: string = '';
  @Local ruleHints: boolean = true;
  @Local ruleError: string = '';
  @Local isSavingRule: boolean = false;
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
      this.rule = this.service.observationRule();
      this.overview = await this.service.overview();
      this.listVersion += 1;
      this.isLoading = false;
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '状态数据加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.overview = PREVIEW_STATUS_OVERVIEW;
    this.listVersion += 1;
    this.isLoading = false;
  }

  private async refresh(): Promise<void> {
    if (this.isPreview) {
      this.overview = PREVIEW_STATUS_OVERVIEW;
      this.listVersion += 1;
      this.isLoading = false;
      return;
    }
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.overview = await this.service.overview();
      this.listVersion += 1;
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

  private openEditor(): void {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '演示模式下不能录入读数' });
      return;
    }
    if (this.navStack === null) {
      return;
    }
    const params: StatusEditParams = { date: null };
    this.navStack.pushPathByName(ROUTES.STATUS_EDIT, params, () => {
      this.refresh();
    });
  }

  private openRule(): void {
    this.ruleSleep = String(this.rule.sleepMinHours);
    this.ruleAlert = String(this.rule.alertWarnCount);
    this.ruleHints = this.rule.hintsEnabled;
    this.ruleError = '';
    this.ruleVisible = true;
  }

  private async saveRule(): Promise<void> {
    if (this.isSavingRule || this.isPreview) {
      return;
    }
    const sleep = Number(this.ruleSleep);
    const alerts = Number(this.ruleAlert);
    if (!Number.isFinite(sleep) || sleep < 3 || sleep > 10) {
      this.ruleError = '睡眠下限需在 3–10 小时之间';
      return;
    }
    if (!Number.isInteger(alerts) || alerts < 1 || alerts > 10) {
      this.ruleError = '报警次数需为 1–10 的整数';
      return;
    }
    if (this.service === null) {
      return;
    }
    this.isSavingRule = true;
    this.ruleError = '';
    try {
      await this.service.saveObservationRule(sanitizeObservationRule({
        sleepMinHours: sleep,
        alertWarnCount: alerts,
        hintsEnabled: this.ruleHints
      }));
      this.rule = this.service.observationRule();
      this.ruleVisible = false;
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({ message: '观察规则已保存' });
    } catch (error) {
      this.ruleError = '保存失败，请重试';
    } finally {
      this.isSavingRule = false;
    }
  }

  private async restoreRule(): Promise<void> {
    if (this.service === null || this.isPreview) {
      return;
    }
    try {
      this.rule = await this.service.resetObservationRule();
      this.ruleSleep = String(this.rule.sleepMinHours);
      this.ruleAlert = String(this.rule.alertWarnCount);
      this.ruleHints = this.rule.hintsEnabled;
      this.ruleError = '';
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({ message: '已恢复默认观察规则' });
    } catch (error) {
      this.ruleError = '恢复失败，请重试';
    }
  }

  @Builder
  ruleSheet() {
    Column({ space: AppTheme.spacing.s8 }) {
      Text('观察规则')
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text(OBSERVATION_RULE_NOTE)
        .fontSize(AppTheme.font.caption)
        .lineHeight(15)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
      Row({ space: AppTheme.spacing.s8 }) {
        Text('睡眠下限（小时）')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .layoutWeight(1)
        TextInput({ text: this.ruleSleep, placeholder: '6.5' })
          .id('status_rule_sleep')
          .type(InputType.NUMBER_DECIMAL)
          .width(96)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .onChange((value: string) => {
            this.ruleSleep = value;
            this.ruleError = '';
          })
      }
      .width('100%')
      Row({ space: AppTheme.spacing.s8 }) {
        Text('报警次数起算')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .layoutWeight(1)
        TextInput({ text: this.ruleAlert, placeholder: '1' })
          .id('status_rule_alert')
          .type(InputType.Number)
          .width(96)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .onChange((value: string) => {
            this.ruleAlert = value;
            this.ruleError = '';
          })
      }
      .width('100%')
      Text(this.ruleHints ? '观察提示 · 已开启' : '观察提示 · 已关闭')
        .id('status_rule_hints')
        .fontSize(AppTheme.font.body)
        .fontColor(this.ruleHints ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
        .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
        .backgroundColor(this.ruleHints ? AppTheme.color.tint : AppTheme.color.chip)
        .borderRadius(AppTheme.radius.md)
        .onClick(() => {
          this.ruleHints = !this.ruleHints;
        })
      if (this.ruleError.length > 0) {
        Text(this.ruleError)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.danger)
          .width('100%')
      }
      Row({ space: AppTheme.spacing.s8 }) {
        Text('恢复默认')
          .id('status_rule_reset')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.restoreRule();
          })
        Text(this.isSavingRule ? '保存中…' : '保存规则')
          .id('status_rule_save')
          .fontSize(AppTheme.font.body)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(this.isSavingRule ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.saveRule();
          })
      }
      .width('100%')
    }
    .id('status_rule_panel')
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  addMenu() {
    Row() {
      Text('＋')
        .fontSize(AppTheme.font.headline)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s16 })
        .onClick(() => {
          this.openEditor();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  statItem(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text(label)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textSecondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    AppDestination({
      route: 'status',
      title: '状态面板',
      content: () => {
        this.statusBody();
      },
      menus: () => {
        this.addMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.refresh();
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }

  @Builder
  statusBody() {
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
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text(this.overview.latest.date)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textMuted)
                  }
                  .width('100%')

                  Row({ space: 6 }) {
                    if (this.overview.latest.unknownReadings.indexOf('sleep') >= 0) {
                      Text('睡眠未记录')
                        .fontSize(AppTheme.font.title)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.color.textMuted)
                    } else {
                      Text(`${this.overview.latest.sleepHours}`)
                        .fontSize(AppTheme.font.display)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.overview.latest.flags.length > 0 ? AppTheme.color.danger : AppTheme.color.text)
                      Text('小时睡眠')
                        .fontSize(AppTheme.font.bodyStrong)
                        .fontColor(AppTheme.color.textSecondary)
                        .margin({ top: AppTheme.spacing.s12 })
                    }
                    Blank()
                    Text(`运动 ${this.overview.latest.unknownReadings.indexOf('exercise') >= 0 ? '未记录' : `${this.overview.latest.exerciseCount} 次`} · 报警 ${this.overview.latest.unknownReadings.indexOf('alert') >= 0 ? '未记录' : `${this.overview.latest.alertCount} 次`}`)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                  }
                  .width('100%')

                  if (this.overview.latest.unknownReadings.indexOf('sleep') < 0) {
                    Progress({ value: this.overview.latest.sleepHours, total: 10, type: ProgressType.Linear })
                      .height(8)
                      .color(this.overview.latest.flags.length > 0 ? AppTheme.color.danger : AppTheme.color.primary)
                      .backgroundColor(AppTheme.color.track)
                  }

                  if (this.overview.latest.flags.length > 0) {
                    Text('观察提示（只描述数据条件）')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.overview.latest.flags, (flag: ReadingFlag) => {
                        Text(flag.message)
                          .fontSize(AppTheme.font.caption)
                          .fontColor(AppTheme.color.danger)
                          .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                          .backgroundColor(AppTheme.color.dangerSurface)
                          .borderRadius(AppTheme.radius.sm)
                          .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
                      }, (flag: ReadingFlag) => flag.code)
                    }
                    .width('100%')
                  }

                  if (this.overview.latest.capacity.length > 0) {
                    Text(`我的判断：${capacityText(this.overview.latest.capacity)}`)
                      .fontSize(AppTheme.font.bodyStrong)
                      .fontColor(AppTheme.color.primaryDeep)
                      .width('100%')
                  }

                  if (this.overview.latest.bodySignals.length > 0) {
                    Text(`身体信号：${this.overview.latest.bodySignals}`)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                  }

                  if (this.overview.latest.functionState.length > 0) {
                    Text(`当下功能：${this.overview.latest.functionState}`)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                  }

                  if (this.overview.latest.functionGain.length > 0 || this.overview.latest.costPaid.length > 0) {
                    Text(`功能：${this.overview.latest.functionGain.length > 0 ? this.overview.latest.functionGain : '未填写'}`)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                    Text(`成本：${this.overview.latest.costPaid.length > 0 ? this.overview.latest.costPaid : '未填写'}`)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                  }

                  if (this.overview.latest.note.length > 0) {
                    Text(this.overview.latest.note)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Row() {
                    Text('观察规则')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text('设置 ›')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.primary)
                      .id('status_rule_entry')
                      .onClick(() => {
                        this.openRule();
                      })
                  }
                  .width('100%')
                  Text(`睡眠低于 ${this.rule.sleepMinHours} 小时、报警达到 ${this.rule.alertWarnCount} 次时给提示；${this.rule.hintsEnabled ? '提示已开启' : '提示已关闭'}`)
                    .fontSize(AppTheme.font.caption)
                    .lineHeight(15)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                  Text(OBSERVATION_RULE_NOTE)
                    .fontSize(AppTheme.font.caption)
                    .lineHeight(15)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
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
                  Text(`最近 ${this.overview.summary.days} 天 · 睡眠有读数 ${this.overview.summary.sleepDays} 天 · 有未记录项 ${this.overview.summary.unknownDays} 天 · 观察提示 ${this.overview.summary.flaggedDays} 天`)
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
              }

              StatusTrendCard({ rows: this.overview.recent })

              SectionCard() {
                Column({ space: 10 }) {
                  Row() {
                    Text('最近记录')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text('全部记录 ›')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.primary)
                      .onClick(() => {
                        this.openHistory();
                      })
                  }
                  .width('100%')

                  ForEach(this.overview.recent.slice(0, 3), (row: StatusRow) => {
                    StatusDayRow({ row: row, compact: true })
                  }, (row: StatusRow) => `${row.id}_${this.listVersion}`)
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
          .bindSheet($$this.ruleVisible, this.ruleSheet(), {
            height: 420,
            dragBar: false,
            backgroundColor: AppTheme.color.surface
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }
}
