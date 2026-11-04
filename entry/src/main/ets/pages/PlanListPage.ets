import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { Plan } from '../model/Plan';
import { PlanStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { PlanDetailParams, PlanEditParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { notifyHomeRefresh, subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';

/** Lists the single primary goal and the other plans. */
@ComponentV2
export struct PlanListPage {
  @Local plans: Plan[] = [];
  @Local isLoading: boolean = true;
  @Local isPreview: boolean = false;
  @Local listVersion: number = 0;
  private service: PlanService | null = null;
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;
  private listener: (() => void) | null = null;

  aboutToAppear(): void {
    this.load();
    if (this.listener === null) {
      this.listener = () => {
        this.refresh();
      };
      subscribeHomeRefresh(this.listener);
    }
  }

  aboutToDisappear(): void {
    if (this.listener !== null) {
      unsubscribeHomeRefresh(this.listener);
      this.listener = null;
    }
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isPreview = true;
      this.plans = planPreviewStore.list();
      this.isLoading = false;
      return;
    }
    try {
      this.service = await PlanService.open(hostContext);
      this.plans = await this.service.listPlans();
      this.isPreview = false;
    } catch (error) {
      this.isPreview = true;
      this.plans = planPreviewStore.list();
      this.getUIContext().getPromptAction().showToast({ message: '计划数据加载失败，已切换到演示数据' });
    } finally {
      this.isLoading = false;
    }
  }

  async refresh(): Promise<void> {
    this.plans = [];
    if (this.isPreview || this.service === null) {
      this.plans = planPreviewStore.list();
      this.listVersion += 1;
      return;
    }
    this.plans = await this.service.listPlans();
    this.listVersion += 1;
  }

  private primaryPlan(): Plan | null {
    for (const plan of this.plans) {
      if (plan.isPrimary && plan.status === PlanStatus.ACTIVE) {
        return plan;
      }
    }
    return null;
  }

  private primaryPlans(): Plan[] {
    const plan = this.primaryPlan();
    return plan === null ? [] : [plan];
  }

  private otherPlans(): Plan[] {
    const rows: Plan[] = [];
    for (const plan of this.plans) {
      if (!plan.isPrimary && plan.status === PlanStatus.ACTIVE) {
        rows.push(plan);
      }
    }
    return rows;
  }

  private archivedPlans(): Plan[] {
    const rows: Plan[] = [];
    for (const plan of this.plans) {
      if (plan.status === PlanStatus.ARCHIVED) {
        rows.push(plan);
      }
    }
    return rows;
  }

  private async restore(planId: string): Promise<void> {
    if (this.isPreview) {
      planPreviewStore.restore(planId);
      await this.refresh();
      notifyHomeRefresh();
      return;
    }
    if (this.service === null) {
      return;
    }
    try {
      await this.service.restore(planId);
      await this.refresh();
      notifyHomeRefresh();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '恢复失败，请重试' });
    }
  }

  private openEditor(planId: string | null): void {
    if (this.navStack === null) {
      return;
    }
    const params: PlanEditParams = { planId: planId };
    this.navStack.pushPathByName(ROUTES.PLAN_EDIT, params, () => {
      this.refresh();
    });
  }

  private openDetail(planId: string): void {
    if (this.navStack === null) {
      return;
    }
    const params: PlanDetailParams = { planId: planId };
    this.navStack.pushPathByName(ROUTES.PLAN_DETAIL, params, () => {
      this.refresh();
    });
  }

  private async setPrimary(planId: string): Promise<void> {
    this.plans = [];
    if (this.isPreview) {
      planPreviewStore.setPrimary(planId);
      await this.refresh();
      notifyHomeRefresh();
      return;
    }
    if (this.service === null) {
      return;
    }
    try {
      await this.service.setPrimary(planId);
      await this.refresh();
      notifyHomeRefresh();
      this.getUIContext().getPromptAction().showToast({ message: '已切换主目标' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '切换失败，请重试' });
    }
  }

  @Builder
  addMenu() {
    Text('＋')
      .id('plan_create')
      .fontSize(22)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 12, right: 16 })
      .height(56)
      .onClick(() => {
        this.openEditor(null);
      })
  }

  @Builder
  primaryCard(plan: Plan) {
    SectionCard() {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text('主目标')
            .fontSize(10)
            .fontColor(AppTheme.color.primaryDeep)
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(6)
          Blank()
          Row({ space: 10 }) {
            Text('查看 ›')
              .fontSize(11)
              .fontColor(AppTheme.color.primary)
              .onClick(() => {
                this.openDetail(plan.id);
              })
            Text('编辑')
              .fontSize(11)
              .fontColor(AppTheme.color.textSecondary)
              .onClick(() => {
                this.openEditor(plan.id);
              })
          }
        }
        .width('100%')

        Text(plan.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.color.text)
          .width('100%')
          .maxLines(2)
        if (plan.goal.length > 0) {
          Text(plan.goal)
            .fontSize(12)
            .lineHeight(18)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
            .maxLines(3)
        }
        Text(`起始 ${plan.startDate} · 七日节点按周推进`)
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  planRow(plan: Plan) {
    SectionCard() {
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(plan.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.openDetail(plan.id);
            })
          Text('设为主目标')
            .fontSize(10)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.setPrimary(plan.id);
            })
        }
        .width('100%')

        Text(plan.goal.length > 0 ? plan.goal : '还没有目标说明')
          .fontSize(11)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  archivedRow(plan: Plan) {
    SectionCard() {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(plan.title)
            .fontSize(13)
            .fontColor(AppTheme.color.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(`归档 · 起始 ${plan.startDate}`)
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('恢复')
          .fontSize(11)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.restore(plan.id);
          })
      }
      .width('100%')
    }
  }

  @Builder
  listBody() {
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
    } else if (this.plans.length === 0) {
      Column() {
        NoteEmptyState({
          title: '还没有计划',
          hint: '先把一个长期目标写下来，再按七个一天推进',
          actionLabel: '新建目标',
          dashed: true,
          onAction: () => {
            this.openEditor(null);
          }
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 20 })
    } else {
      Scroll() {
        Column({ space: 12 }) {
          SectionCard() {
            Column({ space: 4 }) {
              Text('把长期目标切成七日节点')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.color.text)
                .width('100%')
              Text('首页只展示主目标；其他目标可以随时切换为主目标。进入目标即可管理周节点、清单与关联记录。')
                .fontSize(11)
                .lineHeight(17)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          if (this.primaryPlans().length > 0) {
            ForEach(this.primaryPlans(), (plan: Plan) => {
              this.primaryCard(plan)
            }, (plan: Plan) => `${plan.id}_${this.listVersion}`)
          }

          if (this.otherPlans().length > 0) {
            Text('其他目标')
              .fontSize(12)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            ForEach(this.otherPlans(), (plan: Plan) => {
              this.planRow(plan)
            }, (plan: Plan) => `${plan.id}_${this.listVersion}`)
          }

          if (this.archivedPlans().length > 0) {
            Text('已归档')
              .fontSize(12)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            ForEach(this.archivedPlans(), (plan: Plan) => {
              this.archivedRow(plan)
            }, (plan: Plan) => `${plan.id}_${this.listVersion}`)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
    }
  }

  build() {
    AppDestination({
      route: 'plan',
      title: '计划',
      content: () => {
        this.listBody()
      },
      menus: () => {
        this.addMenu()
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
}
