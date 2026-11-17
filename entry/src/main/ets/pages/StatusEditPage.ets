import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { StatusService, StatusDraft, emptyStatusDraft } from '../status';
import { StatusRecord } from '../model/StatusRecord';
import { CapacityJudgment, CAPACITY_OPTIONS, capacityText } from '../model/CapacityJudgment';
import { isReadingUnknown, setReadingUnknown, ReadingField } from '../analysis/status/ReadingPresence';
import { OBSERVATION_RULE_NOTE } from '../analysis/status/ObservationRule';
import { StatusEditParams, PlanAttachParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { Plan } from '../model/Plan';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Creates or edits one day's readings, body evidence and capacity judgment. */
@ComponentV2
export struct StatusEditPage {
  @Local date: string = todayString();
  @Local sleepHours: string = '';
  @Local exerciseCount: string = '';
  @Local alertCount: string = '';
  @Local note: string = '';
  @Local bodySignals: string = '';
  @Local functionState: string = '';
  @Local emotion: string = '';
  @Local environment: string = '';
  @Local capacity: CapacityJudgment = '';
  @Local functionGain: string = '';
  @Local costPaid: string = '';
  @Local statusMoreOpen: boolean = false;
  @Local unknownReadings: string = '';
  @Local hasExisting: boolean = false;
  @Local correctedAt: number = 0;
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local isDirty: boolean = false;
  @Local isPreview: boolean = false;
  @Local errorText: string = '';
  @Local pauseVisible: boolean = false;
  @Local pauseReason: string = '';
  @Local pauseError: string = '';
  @Local isPausing: boolean = false;
  @Local pausePlans: Plan[] = [];
  @Local pausePlanId: string = '';
  private service: StatusService | null = null;
  private planService: PlanService | null = null;
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
      const record = await service.findRecord(this.date);
      if (record !== null) {
        this.applyRecord(record);
      }
    } catch (error) {
      this.errorText = '读数加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private applyRecord(record: StatusRecord): void {
    this.hasExisting = true;
    this.correctedAt = record.correctedAt ?? 0;
    this.unknownReadings = record.unknownReadings ?? '';
    this.sleepHours = isReadingUnknown(this.unknownReadings, 'sleep') ? '' : String(record.sleepHours);
    this.exerciseCount = isReadingUnknown(this.unknownReadings, 'exercise') ? '' : String(record.exerciseCount);
    this.alertCount = isReadingUnknown(this.unknownReadings, 'alert') ? '' : String(record.alertCount);
    this.note = record.note;
    this.bodySignals = record.bodySignals ?? '';
    this.functionState = record.functionState ?? '';
    this.emotion = record.emotion ?? '';
    this.environment = record.environment ?? '';
    this.capacity = record.capacity ?? '';
    this.functionGain = record.functionGain ?? '';
    this.costPaid = record.costPaid ?? '';
    this.statusMoreOpen = this.bodySignals.length > 0 || this.functionState.length > 0
      || this.emotion.length > 0 || this.environment.length > 0
      || this.functionGain.length > 0 || this.costPaid.length > 0 || this.note.length > 0;
  }

  private buildDraft(): StatusDraft {
    const draft = emptyStatusDraft(this.date);
    draft.unknownReadings = this.unknownReadings;
    draft.sleepHours = isReadingUnknown(this.unknownReadings, 'sleep') ? 0 : Number(this.sleepHours);
    draft.exerciseCount = isReadingUnknown(this.unknownReadings, 'exercise') ? 0 : Number(this.exerciseCount);
    draft.alertCount = isReadingUnknown(this.unknownReadings, 'alert') ? 0 : Number(this.alertCount);
    draft.note = this.note;
    draft.bodySignals = this.bodySignals;
    draft.functionState = this.functionState;
    draft.emotion = this.emotion;
    draft.environment = this.environment;
    draft.capacity = this.capacity;
    draft.functionGain = this.functionGain;
    draft.costPaid = this.costPaid;
    return draft;
  }

  private validate(): string {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(this.date)) {
      return '日期格式应为 YYYY-MM-DD';
    }
    if (!isReadingUnknown(this.unknownReadings, 'sleep')) {
      if (this.sleepHours.trim().length === 0) {
        return '请填写睡眠小时，或标为不清楚';
      }
      const sleep = Number(this.sleepHours);
      if (!Number.isFinite(sleep) || sleep < 0 || sleep > 24) {
        return '睡眠需在 0–24 小时之间';
      }
    }
    if (!isReadingUnknown(this.unknownReadings, 'exercise')) {
      if (this.exerciseCount.trim().length === 0) {
        return '请填写运动次数，或标为不清楚';
      }
      const exercise = Number(this.exerciseCount);
      if (!Number.isInteger(exercise) || exercise < 0 || exercise > 20) {
        return '运动次数需为 0–20 的整数';
      }
    }
    if (!isReadingUnknown(this.unknownReadings, 'alert')) {
      if (this.alertCount.trim().length === 0) {
        return '请填写报警次数，或标为不清楚';
      }
      const alerts = Number(this.alertCount);
      if (!Number.isInteger(alerts) || alerts < 0 || alerts > 20) {
        return '报警次数需为 0–20 的整数';
      }
    }
    return '';
  }

  private async save(pauseAfter: boolean): Promise<void> {
    if (this.isSaving || this.isPreview) {
      return;
    }
    const problem = this.validate();
    if (problem.length > 0) {
      this.errorText = problem;
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
      this.service = service;
      await service.save(this.buildDraft());
      notifyHomeRefresh();
      this.isDirty = false;
      if (pauseAfter) {
        await this.openPause();
        return;
      }
      this.getUIContext().getPromptAction().showToast({ message: '已保存，不处理其他事情' });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.errorText = '保存失败，请重试';
    } finally {
      this.isSaving = false;
    }
  }

  private async openPause(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return;
    }
    try {
      const planService = await PlanService.open(hostContext);
      this.planService = planService;
      const all = await planService.listPlans();
      this.pausePlans = all.filter((plan: Plan) => plan.status === PlanStatus.ACTIVE);
      if (this.pausePlans.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '没有进行中的目标，已保存这一天的记录' });
        if (this.navStack !== null) {
          this.navStack.pop(true);
        }
        return;
      }
      this.pausePlanId = this.pausePlans[0].id;
      this.pauseReason = '身体状态需要暂停';
      this.pauseError = '';
      this.pauseVisible = true;
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '目标列表加载失败，已保存这一天的记录' });
    }
  }

  private async confirmPause(): Promise<void> {
    if (this.isPausing || this.planService === null) {
      return;
    }
    const reason = this.pauseReason.trim();
    if (reason.length === 0) {
      this.pauseError = '写一句暂停原因';
      return;
    }
    if (this.pausePlanId.length === 0) {
      this.pauseError = '选择一个要暂停的目标';
      return;
    }
    this.isPausing = true;
    this.pauseError = '';
    try {
      await this.planService.pausePlan(this.pausePlanId, reason);
      notifyHomeRefresh();
      this.pauseVisible = false;
      this.getUIContext().getPromptAction().showToast({ message: '目标已暂停' });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.pauseError = '暂停失败，请重试';
    } finally {
      this.isPausing = false;
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
          this.save(false);
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  numberField(label: string, placeholder: string, value: string, field: ReadingField,
    decimal: boolean, onChange: (value: string) => void) {
    Column({ space: 5 }) {
      Row() {
        Text(label)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        Text(isReadingUnknown(this.unknownReadings, field) ? '不清楚 · 已选' : '不清楚')
          .fontSize(AppTheme.font.caption)
          .fontColor(isReadingUnknown(this.unknownReadings, field) ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(isReadingUnknown(this.unknownReadings, field) ? AppTheme.color.tint : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id(`status_unknown_${field}`)
          .onClick(() => {
            const next = !isReadingUnknown(this.unknownReadings, field);
            this.unknownReadings = setReadingUnknown(this.unknownReadings, field, next);
            onChange('');
            this.isDirty = true;
            this.errorText = '';
          })
      }
      .width('100%')
      TextInput({ text: value, placeholder: isReadingUnknown(this.unknownReadings, field) ? '已标为不清楚' : placeholder })
        .type(decimal ? InputType.NUMBER_DECIMAL : InputType.Number)
        .enabled(!isReadingUnknown(this.unknownReadings, field))
        .backgroundColor(AppTheme.color.surfaceAlt)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  textField(label: string, hint: string, value: string, lines: number, onChange: (value: string) => void) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
      if (hint.length > 0) {
        Text(hint)
          .fontSize(AppTheme.font.caption)
          .lineHeight(15)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      TextArea({ text: value, placeholder: hint.length > 0 ? hint : '可留空' })
        .height(lines * 22)
        .maxLength(200)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  capacityChip(value: CapacityJudgment) {
    Text(capacityText(value))
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.capacity === value ? Color.White : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.capacity === value ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .id(`status_capacity_${value}`)
      .onClick(() => {
        this.capacity = value;
        this.isDirty = true;
      })
  }

  @Builder
  pauseSheet() {
    Column({ space: AppTheme.spacing.s8 }) {
      Text('暂停哪个目标')
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text('暂停只改变计划状态，体检与医学判断不在本应用的适用范围。')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
      if (this.pausePlans.length > 1) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.pausePlans, (plan: Plan) => {
            Text(plan.title)
              .fontSize(AppTheme.font.body)
              .fontColor(this.pausePlanId === plan.id ? Color.White : AppTheme.color.text)
              .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
              .backgroundColor(this.pausePlanId === plan.id ? AppTheme.color.primary : AppTheme.color.chip)
              .borderRadius(AppTheme.radius.md)
              .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
              .onClick(() => {
                this.pausePlanId = plan.id;
              })
          }, (plan: Plan) => plan.id)
        }
        .width('100%')
      } else if (this.pausePlans.length === 1) {
        Text(`目标：${this.pausePlans[0].title}`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
      }
      TextInput({ text: this.pauseReason, placeholder: '暂停原因（必填）' })
        .id('status_pause_reason')
        .backgroundColor(AppTheme.color.surfaceAlt)
        .onChange((value: string) => {
          this.pauseReason = value;
          this.pauseError = '';
        })
      if (this.pauseError.length > 0) {
        Text(this.pauseError)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.danger)
          .width('100%')
      }
      Row({ space: AppTheme.spacing.s8 }) {
        Text('只保存')
          .id('status_pause_cancel')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.pauseVisible = false;
            if (this.navStack !== null) {
              this.navStack.pop(true);
            }
          })
        Text(this.isPausing ? '暂停中…' : '确认暂停')
          .id('status_pause_confirm')
          .fontSize(AppTheme.font.body)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(this.isPausing ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.confirmPause();
          })
      }
      .width('100%')
    }
    .id('status_pause_panel')
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    AppDestination({
      route: 'status_edit',
      title: '记录状态',
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
          title: '放弃这一天的记录？',
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
            Text(this.hasExisting ?
              '这一天已有记录。再次保存会记为更正，原读数保留在历史里。' :
              '先记下能确认的事实；不确定的读数可以标为不清楚，身体与感受可以只写一句。')
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
                Text('事实读数')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
                this.numberField('睡眠小时', '例如 7.5', this.sleepHours, 'sleep', true, (value: string) => {
                  this.sleepHours = value;
                  this.isDirty = true;
                })
                this.numberField('运动次数', '例如 1', this.exerciseCount, 'exercise', false, (value: string) => {
                  this.exerciseCount = value;
                  this.isDirty = true;
                })
                this.numberField('凌晨报警次数', '例如 0', this.alertCount, 'alert', false, (value: string) => {
                  this.alertCount = value;
                  this.isDirty = true;
                })
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
              Column({ space: 8 }) {
                Text('你怎么判断今天的承受能力')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
                Text('系统不根据数值替你选，只保存你的判断。')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(CAPACITY_OPTIONS, (option: CapacityJudgment) => {
                    this.capacityChip(option)
                  }, (option: CapacityJudgment) => option)
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            Row() {
              Text(this.statusMoreOpen ? '收起' : '更多（可选）')
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.primary)
                .layoutWeight(1)
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontSize(14)
                .fontColor([AppTheme.color.primary])
                .rotate({ angle: this.statusMoreOpen ? 180 : 0 })
            }
            .id('status_more_toggle')
            .width('100%')
            .height(40)
            .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12 })
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.md)
            .onClick(() => {
              this.statusMoreOpen = !this.statusMoreOpen;
            })

            if (this.statusMoreOpen) {
              SectionCard() {
                Column({ space: 10 }) {
                  Text('身体与当下')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  this.textField('身体信号', '例如 头痛、胃部不适、眼睛发干', this.bodySignals, 2, (value: string) => {
                    this.bodySignals = value;
                    this.isDirty = true;
                  })
                  this.textField('当下功能', '例如 能读十分钟，无法连续工作', this.functionState, 2, (value: string) => {
                    this.functionState = value;
                    this.isDirty = true;
                  })
                  this.textField('情绪感受', '例如 烦躁、心里发紧', this.emotion, 2, (value: string) => {
                    this.emotion = value;
                    this.isDirty = true;
                  })
                  this.textField('环境因素', '例如 房间闷热、连续开会', this.environment, 2, (value: string) => {
                    this.environment = value;
                    this.isDirty = true;
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('这次高负荷的成对记录')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('同一件事带来的功能和付出的代价分开写，避免只记住其中一面。')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                  this.textField('带来了什么功能', '例如 赶完了报告、维持了课程进度', this.functionGain, 2, (value: string) => {
                    this.functionGain = value;
                    this.isDirty = true;
                  })
                  this.textField('付出了什么成本', '例如 两天注意力涣散、错过锻炼', this.costPaid, 2, (value: string) => {
                    this.costPaid = value;
                    this.isDirty = true;
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('自由备注')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  TextArea({ text: this.note, placeholder: '可写一句当天状态' })
                    .height(80)
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
            }

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.danger)
                .width('100%')
            }

            Text(this.isSaving ? '保存中…' : '只保存，不处理')
              .id('status_edit_save')
              .fontSize(AppTheme.font.subtitle)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(this.isPreview ? AppTheme.color.textMuted : AppTheme.color.primary)
              .borderRadius(AppTheme.radius.md)
              .onClick(() => {
                this.save(false);
              })

            Text('保存并暂停计划')
              .id('status_edit_save_pause')
              .fontSize(AppTheme.font.subtitle)
              .fontColor(this.isPreview ? AppTheme.color.textMuted : AppTheme.color.primary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(AppTheme.color.tint)
              .borderRadius(AppTheme.radius.md)
              .onClick(() => {
                this.save(true);
              })
          }
          .width('100%')
          .padding(AppTheme.spacing.page)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(Color.Transparent)
        .bindSheet($$this.pauseVisible, this.pauseSheet(), {
          height: 420,
          dragBar: false,
          backgroundColor: AppTheme.color.surface
        })
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
