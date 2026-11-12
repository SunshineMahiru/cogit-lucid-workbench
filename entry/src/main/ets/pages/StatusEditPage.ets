import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { StatusDayRow, StatusService } from '../status';
import { StatusEditParams, PlanAttachParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Creates or edits one day's physiological reading. */
@ComponentV2
export struct StatusEditPage {
  @Local date: string = todayString();
  @Local sleepHours: string = '';
  @Local exerciseCount: string = '';
  @Local alertCount: string = '';
  @Local note: string = '';
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local isDirty: boolean = false;
  @Local isPreview: boolean = false;
  @Local errorText: string = '';
  private service: StatusService | null = null;
  private navStack: NavPathStack | null = null;

  private async load(date: string | null): Promise<void> {
    if (date !== null) {
      this.date = date;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isPreview = true;
      this.isLoading = false;
      return;
    }
    try {
      const service = await StatusService.open(hostContext);
      this.service = service;
      const row = await service.find(this.date);
      if (row !== null) {
        this.sleepHours = String(row.sleepHours);
        this.exerciseCount = String(row.exerciseCount);
        this.alertCount = String(row.alertCount);
        this.note = row.note;
      }
    } catch (error) {
      this.errorText = '读数加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private async save(): Promise<void> {
    if (this.isSaving || this.isPreview) {
      return;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(this.date)) {
      this.errorText = '日期格式应为 YYYY-MM-DD';
      return;
    }
    if (this.sleepHours.trim().length === 0) {
      this.errorText = '请填写睡眠时长';
      return;
    }
    if (this.exerciseCount.trim().length === 0) {
      this.errorText = '请填写运动次数';
      return;
    }
    if (this.alertCount.trim().length === 0) {
      this.errorText = '请填写报警次数';
      return;
    }
    const sleep = Number(this.sleepHours);
    const exercise = Number(this.exerciseCount);
    const alerts = Number(this.alertCount);
    if (!Number.isFinite(sleep) || sleep < 0 || sleep > 24) {
      this.errorText = '睡眠需在 0–24 小时之间';
      return;
    }
    if (!Number.isInteger(exercise) || exercise < 0 || exercise > 20) {
      this.errorText = '运动次数需为 0–20 的整数';
      return;
    }
    if (!Number.isInteger(alerts) || alerts < 0 || alerts > 20) {
      this.errorText = '报警次数需为 0–20 的整数';
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.errorText = '运行环境未就绪';
      return;
    }
    this.isSaving = true;
    this.errorText = '';
    try {
      const service = await StatusService.open(hostContext);
      await service.save(this.date, sleep, exercise, alerts, this.note);
      notifyHomeRefresh();
      this.getUIContext().getPromptAction().showToast({ message: '读数已保存' });
      this.isDirty = false;
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.errorText = '保存失败，请重试';
    } finally {
      this.isSaving = false;
    }
  }

  private async openAttach(): Promise<void> {
    if (this.navStack === null) {
      return;
    }
    const day = this.date.trim();
    if (this.service === null) {
      this.getUIContext().getPromptAction().showToast({ message: '先保存读数再关联计划' });
      return;
    }
    const row = await this.service.find(day);
    if (row === null) {
      this.getUIContext().getPromptAction().showToast({ message: '先保存当前日期的读数再关联计划' });
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.STATUS,
      targetId: row.id,
      label: day
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  @Builder
  saveMenu() {
    Row() {
      Text('计划')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s6 })
        .onClick(() => {
          this.openAttach();
        })
      Text(this.isSaving ? '保存中' : '保存')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(this.isPreview ? AppTheme.color.textMuted : AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s16 })
        .onClick(() => {
          this.save();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  numberField(label: string, placeholder: string, value: string, decimal: boolean, onChange: (value: string) => void) {
    Column({ space: 5 }) {
      Text(label)
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .type(decimal ? InputType.NUMBER_DECIMAL : InputType.Number)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    AppDestination({
      route: 'status_edit',
      title: '记录读数',
      content: () => {
        this.statusEditBody();
      },
      menus: () => {
        this.saveMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        const params = context.pathInfo.param as StatusEditParams;
        this.load(params.date);
      },
      onDestinationBackPressed: () => {
        if (!this.isDirty) {
          return false;
        }
        this.getUIContext().showAlertDialog({
          title: '放弃这条读数？',
          message: '已填写的内容不会保存。',
          primaryButton: {
            value: '继续编辑',
            action: () => {
            }
          },
          secondaryButton: {
            value: '放弃',
            action: () => {
              this.isDirty = false;
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          }
        });
        return true;
      }
    })
  }

  @Builder
  statusEditBody() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppTheme.color.primary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Text('记录睡眠、运动与凌晨报警；同一天再次保存会覆盖原读数。')
              .fontSize(AppTheme.font.body)
              .lineHeight(18)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')

            SectionCard() {
              Column({ space: 6 }) {
                Text('日期')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextInput({ text: this.date, placeholder: 'YYYY-MM-DD' })
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.date = value;
                    this.isDirty = true;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 10 }) {
                this.numberField('睡眠小时', '例如 7.5', this.sleepHours, true, (value: string) => {
                  this.sleepHours = value;
                  this.isDirty = true;
                })
                this.numberField('运动次数', '例如 1', this.exerciseCount, false, (value: string) => {
                  this.exerciseCount = value;
                  this.isDirty = true;
                })
                this.numberField('凌晨报警次数', '例如 0', this.alertCount, false, (value: string) => {
                  this.alertCount = value;
                  this.isDirty = true;
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text('备注')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextArea({ text: this.note, placeholder: '可写一句当天状态' })
                  .height(90)
                  .maxLength(200)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.note = value;
                    this.isDirty = true;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.danger)
                .width('100%')
            }

            Text(this.isSaving ? '保存中…' : '保存读数')
              .fontSize(AppTheme.font.subtitle)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(this.isPreview ? AppTheme.color.textMuted : AppTheme.color.primary)
              .borderRadius(AppTheme.radius.md)
              .onClick(() => {
                this.save();
              })
          }
          .width('100%')
          .padding(AppTheme.spacing.page)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(Color.Transparent)
      }
  }
}

function todayString(): string {
  const date = new Date();
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
