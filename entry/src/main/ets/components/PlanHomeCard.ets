import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';
import { Plan } from '../model/Plan';
import { PlanNode } from '../model/PlanNode';
import { PlanNodeStatus, PlanStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { PlanEditParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';

/** Home card for the primary plan; keeps the plan entry outside the six-module grid. */
@ComponentV2
export struct PlanHomeCard {
  @Require @Param pathStack: NavPathStack;
  @Local plan: Plan | null = null;
  @Local node: PlanNode | null = null;
  @Local doneCount: number = 0;
  @Local totalCount: number = 0;
  @Local isLoading: boolean = true;
  private listener: (() => void) | null = null;

  aboutToAppear(): void {
    this.load();
    if (this.listener === null) {
      this.listener = () => {
        this.load();
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
      this.plan = planPreviewStore.primary();
      this.isLoading = false;
      return;
    }
    try {
      const service = await PlanService.open(hostContext);
      this.plan = await service.primaryPlan();
      if (this.plan !== null) {
        const nodes = await service.listNodes(this.plan.id);
        let latest: PlanNode | null = null;
        for (const node of nodes) {
          if (node.status === PlanNodeStatus.OPEN) {
            latest = node;
          }
        }
        if (latest === null && nodes.length > 0) {
          latest = nodes[nodes.length - 1];
        }
        this.node = latest;
        if (latest !== null) {
          const items = await service.listItems(latest.id);
          this.totalCount = items.length;
          let done = 0;
          for (const item of items) {
            if (item.done) {
              done += 1;
            }
          }
          this.doneCount = done;
        }
      }
    } catch (error) {
      this.plan = null;
    } finally {
      this.isLoading = false;
    }
  }

  private openList(): void {
    this.pathStack.pushPathByName(ROUTES.PLAN, null, () => {
      this.load();
    });
  }

  private openPlan(): void {
    if (this.plan === null) {
      const params: PlanEditParams = { planId: null };
      this.pathStack.pushPathByName(ROUTES.PLAN_EDIT, params, () => {
        this.load();
      });
      return;
    }
    this.pathStack.pushPathByName(ROUTES.PLAN, null, () => {
      this.load();
    });
  }

  @Builder
  emptyCard() {
    SectionCard() {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('还没有进行中的计划')
            .fontSize(AppTheme.font.bodyStrong)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
            .width('100%')
          Text('用七日节点把长期目标推到下一周')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('全部目标 ›')
          .id('plan_home_all')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .padding({ left: 4, right: 8, top: 6, bottom: 6 })
          .onClick(() => {
            this.openList();
          })
        Text('新建')
          .id('plan_home_create')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primaryDeep)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.lg)
          .onClick(() => {
            this.openPlan();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  planCard(plan: Plan) {
    SectionCard() {
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text('当前计划')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.primaryDeep)
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(AppTheme.radius.sm)
          Blank()
          Text('查看 ›')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
        }
        .width('100%')

        Text(plan.title)
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 10 }) {
          Text(this.node !== null ? `第 ${this.node.weekIndex} 周` : '第 1 周')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
          Text(`清单 ${this.doneCount}/${this.totalCount}`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
          Text(this.node !== null ? `${this.node.startDate} 至 ${this.node.endDate}` : `起始 ${plan.startDate}`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
            .layoutWeight(1)
            .textAlign(TextAlign.End)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openPlan();
      })
    }
  }

  build() {
    if (this.isLoading) {
      Row({ space: 6 }) {
        LoadingProgress().width(14).height(14).color(AppTheme.color.primary)
        Text('读取计划…').fontSize(AppTheme.font.caption).fontColor(AppTheme.color.textMuted)
      }
      .width('100%')
      .padding({ top: 2, bottom: 2 })
    } else if (this.plan === null || this.plan.status !== PlanStatus.ACTIVE) {
      Column() {
        this.emptyCard()
      }
      .width('100%')
      .padding({ top: 2, bottom: 2 })
    } else {
      Column() {
        this.planCard(this.plan)
      }
      .width('100%')
      .padding({ top: 2, bottom: 2 })
    }
  }
}
