import { common } from '@kit.AbilityKit';
import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { Plan } from '../model/Plan';
import { PlanService } from '../plan';
import { formatPlanDate, mondayOf, parsePlanDate } from '../plan/PlanFactory';
import { PlanEditParams } from '../navigation/RouteParams';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Creates or edits one plan goal; the first week is created together with a new goal. */
@ComponentV2
export struct PlanEditPage {
  @Local title: string = '';
  @Local goal: string = '';
  @Local startDate: string = '';
  @Local errorText: string = '';
  @Local isSaving: boolean = false;
  @Local isPreview: boolean = false;
  private planId: string | null = null;
  private navStack: NavPathStack | null = null;

  aboutToAppear(): void {
    this.startDate = formatPlanDate(new Date());
  }

  private async load(planId: string | null): Promise<void> {
    this.planId = planId;
    if (planId === null) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      const preview = planPreviewStore.find(planId);
      if (preview !== null) {
        this.apply(preview);
      }
      this.isPreview = true;
      return;
    }
    try {
      const service = await PlanService.open(hostContext);
      const plan = await service.findPlan(planId);
      if (plan !== null) {
        this.apply(plan);
      } else {
        this.errorText = '计划不存在';
      }
    } catch (error) {
      this.errorText = '计划读取失败';
    }
  }

  private apply(plan: Plan): void {
    this.title = plan.title;
    this.goal = plan.goal;
    this.startDate = plan.startDate;
  }

  private validDate(value: string): boolean {
    if (value.length !== 10) {
      return false;
    }
    return !Number.isNaN(parsePlanDate(value).getTime());
  }

  private async save(): Promise<void> {
    if (this.title.trim().length === 0) {
      this.errorText = '请填写目标名称';
      return;
    }
    if (!this.validDate(this.startDate)) {
      this.errorText = '起始日期格式应为 YYYY-MM-DD';
      return;
    }
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    this.errorText = '';
    const monday = mondayOf(this.startDate);
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined || this.isPreview) {
      if (this.planId === null) {
        planPreviewStore.create(this.title, monday);
      } else {
        const plan = planPreviewStore.find(this.planId);
        if (plan !== null) {
          plan.title = this.title.trim();
          plan.goal = this.goal.trim();
          plan.startDate = monday;
          planPreviewStore.update(plan);
        }
      }
      this.getUIContext().getPromptAction().showToast({ message: '演示模式：计划已保存' });
      notifyHomeRefresh();
      this.pop();
      this.isSaving = false;
      return;
    }
    try {
      if (this.planId === null) {
        await this.createInStore(hostContext);
      } else {
        await this.updateInStore(hostContext);
      }
      this.getUIContext().getPromptAction().showToast({ message: '计划已保存' });
      notifyHomeRefresh();
      this.pop();
    } catch (error) {
      this.errorText = '保存失败，请重试';
    } finally {
      this.isSaving = false;
    }
  }

  private async createInStore(context: common.Context): Promise<void> {
    const service = await PlanService.open(context);
    await service.createPlan(this.title, mondayOf(this.startDate));
  }

  private async updateInStore(context: common.Context): Promise<void> {
    const service = await PlanService.open(context);
    const plan = await service.findPlan(this.planId as string);
    if (plan === null) {
      throw new Error('plan missing');
    }
    plan.title = this.title.trim();
    plan.goal = this.goal.trim();
    plan.startDate = mondayOf(this.startDate);
    await service.updatePlan(plan);
  }

  private pop(): void {
    if (this.navStack !== null) {
      this.navStack.pop(true);
    }
  }

  @Builder
  saveMenu() {
    Text(this.isSaving ? '保存中' : '保存')
      .id('plan_save')
      .fontSize(14)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 12, right: 16 })
      .height(56)
      .onClick(() => {
        this.save();
      })
  }

  @Builder
  editBody() {
    Scroll() {
      Column({ space: 12 }) {
        SectionCard() {
          Column({ space: 4 }) {
            Text('先写目标，再排周期')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.color.text)
              .width('100%')
            Text('目标名称要能一眼看出这段时期要推进什么；起始日期会自动归到所在周的周一。')
              .fontSize(11)
              .lineHeight(17)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        SectionCard() {
          Column({ space: 6 }) {
            Text('目标名称')
              .fontSize(11)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            TextInput({ text: this.title, placeholder: '例如：把计划模块接入首页' })
              .id('plan_title')
              .maxLength(40)
              .backgroundColor(AppTheme.color.surfaceAlt)
              .onChange((value: string) => {
                this.title = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        SectionCard() {
          Column({ space: 6 }) {
            Text('目标说明')
              .fontSize(11)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            TextArea({ text: this.goal, placeholder: '写清完成标准，不写口号' })
              .id('plan_goal')
              .height(100)
              .maxLength(300)
              .backgroundColor(AppTheme.color.surfaceAlt)
              .onChange((value: string) => {
                this.goal = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        SectionCard() {
          Column({ space: 6 }) {
            Text('起始日期')
              .fontSize(11)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            TextInput({ text: this.startDate, placeholder: 'YYYY-MM-DD' })
              .id('plan_start')
              .maxLength(10)
              .backgroundColor(AppTheme.color.surfaceAlt)
              .onChange((value: string) => {
                this.startDate = value;
              })
            Text('保存后按周一至周日生成第一个七日节点。')
              .fontSize(10)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(11)
            .fontColor(AppTheme.color.danger)
            .width('100%')
        }

        Text(this.isSaving ? '保存中…' : '保存计划')
          .fontSize(14)
          .fontColor(Color.White)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
          .borderRadius(12)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  build() {
    AppDestination({
      route: 'plan_edit',
      title: this.planId === null ? '新建目标' : '编辑目标',
      content: () => {
        this.editBody()
      },
      menus: () => {
        this.saveMenu()
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        const params = context.pathInfo.param === undefined ? null : context.pathInfo.param as PlanEditParams;
        this.load(params === null ? null : params.planId);
      }
    })
  }
}
