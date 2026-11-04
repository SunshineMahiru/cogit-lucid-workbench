import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { Plan } from '../model/Plan';
import { PlanNode } from '../model/PlanNode';
import { PlanNodeStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { PlanDetailParams, PlanEditParams, PlanNodeParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';

interface PlanNodeView {
  node: PlanNode;
  done: number;
  total: number;
}

/** Goal detail: current week plus the timeline of seven-day nodes. */
@ComponentV2
export struct PlanDetailPage {
  @Local plan: Plan | null = null;
  @Local nodes: PlanNodeView[] = [];
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local isPreview: boolean = false;
  private planId: string = '';
  private service: PlanService | null = null;
  private navStack: NavPathStack | null = null;
  private listener: (() => void) | null = null;

  aboutToAppear(): void {
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

  private async load(planId: string): Promise<void> {
    this.planId = planId;
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      const service = await PlanService.open(hostContext);
      this.service = service;
      this.plan = await service.findPlan(planId);
      if (this.plan === null) {
        this.missing = true;
        return;
      }
      const nodes = await service.listNodes(planId);
      if (nodes.length === 0) {
        await service.ensureFirstNode(planId);
      }
      const refreshed = await service.listNodes(planId);
      await this.applyNodes(service, refreshed);
    } catch (error) {
      this.loadPreview();
    } finally {
      this.isLoading = false;
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.plan = planPreviewStore.find(this.planId);
    if (this.plan === null) {
      this.missing = true;
      this.isLoading = false;
      return;
    }
    planPreviewStore.ensureFirstNode(this.planId);
    const nodes = planPreviewStore.nodes(this.planId);
    const views: PlanNodeView[] = [];
    for (const node of nodes) {
      const items = planPreviewStore.listItems(node.id);
      let done = 0;
      for (const item of items) {
        if (item.done) {
          done += 1;
        }
      }
      views.push({ node: node, done: done, total: items.length });
    }
    this.nodes = views;
    this.isLoading = false;
  }

  private async applyNodes(service: PlanService, nodes: PlanNode[]): Promise<void> {
    const views: PlanNodeView[] = [];
    for (const node of nodes) {
      const items = await service.listItems(node.id);
      let done = 0;
      for (const item of items) {
        if (item.done) {
          done += 1;
        }
      }
      views.push({ node: node, done: done, total: items.length });
    }
    this.nodes = views;
  }

  async refresh(): Promise<void> {
    if (this.planId.length === 0) {
      return;
    }
    if (this.isPreview || this.service === null) {
      this.loadPreview();
      return;
    }
    this.plan = await this.service.findPlan(this.planId);
    const nodes = await this.service.listNodes(this.planId);
    await this.applyNodes(this.service, nodes);
  }

  private currentNode(): PlanNodeView | null {
    let latest: PlanNodeView | null = null;
    for (const view of this.nodes) {
      if (view.node.status === PlanNodeStatus.OPEN) {
        latest = view;
      }
    }
    if (latest === null && this.nodes.length > 0) {
      latest = this.nodes[this.nodes.length - 1];
    }
    return latest;
  }

  private openNode(nodeId: string): void {
    if (this.navStack === null) {
      return;
    }
    const params: PlanNodeParams = { nodeId: nodeId };
    this.navStack.pushPathByName(ROUTES.PLAN_NODE, params, () => {
      this.refresh();
    });
  }

  private openEditor(): void {
    if (this.navStack === null || this.plan === null) {
      return;
    }
    const params: PlanEditParams = { planId: this.plan.id };
    this.navStack.pushPathByName(ROUTES.PLAN_EDIT, params, () => {
      this.refresh();
    });
  }

  @Builder
  editMenu() {
    Text('编辑')
      .fontSize(14)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 12, right: 16 })
      .height(56)
      .onClick(() => {
        this.openEditor();
      })
  }

  @Builder
  nodeCard(view: PlanNodeView) {
    SectionCard() {
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(`第 ${view.node.weekIndex} 周`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text(view.node.status === PlanNodeStatus.OPEN ? '进行中' : '已结束')
            .fontSize(10)
            .fontColor(view.node.status === PlanNodeStatus.OPEN ? AppTheme.color.success : AppTheme.color.textMuted)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(view.node.status === PlanNodeStatus.OPEN ? AppTheme.color.successSurface : AppTheme.color.chip)
            .borderRadius(6)
          Blank()
          Text(`${view.done}/${view.total}`)
            .fontSize(11)
            .fontColor(AppTheme.color.textSecondary)
        }
        .width('100%')

        Text(`${view.node.startDate} 至 ${view.node.endDate}`)
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openNode(view.node.id);
      })
    }
  }

  @Builder
  detailBody() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(32).height(32).color(AppTheme.color.primary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.missing || this.plan === null) {
      Column() {
        NoteEmptyState({
          title: '计划不存在',
          hint: '可能已经被归档或删除',
          actionLabel: '返回',
          onAction: () => {
            if (this.navStack !== null) {
              this.navStack.pop();
            }
          }
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column({ space: 12 }) {
          SectionCard() {
            Column({ space: 5 }) {
              Row() {
                Text(this.plan.title)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.color.text)
                  .layoutWeight(1)
                Text(this.plan.isPrimary ? '主目标' : '目标')
                  .fontSize(10)
                  .fontColor(AppTheme.color.primaryDeep)
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor(AppTheme.color.tint)
                  .borderRadius(6)
              }
              .width('100%')

              if (this.plan.goal.length > 0) {
                Text(this.plan.goal)
                  .fontSize(12)
                  .lineHeight(18)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
              }
              Text(`起始 ${this.plan.startDate} · 周一至周日`)
                .fontSize(10)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          if (this.currentNode() !== null) {
            SectionCard() {
              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(this.currentNode()!.node.status === PlanNodeStatus.OPEN ? '本周节点' : '最近节点')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                  Text(`第 ${this.currentNode()!.node.weekIndex} 周 · ${this.currentNode()!.done}/${this.currentNode()!.total}`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                  Text(`${this.currentNode()!.node.startDate} 至 ${this.currentNode()!.node.endDate}`)
                    .fontSize(10)
                    .fontColor(AppTheme.color.textMuted)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text(this.currentNode()!.node.status === PlanNodeStatus.OPEN ? '进入本周 ›' : '查看 ›')
                  .fontSize(11)
                  .fontColor(AppTheme.color.primary)
              }
              .width('100%')
              .onClick(() => {
                this.openNode(this.currentNode()!.node.id);
              })
            }
          }

          if (this.nodes.length > 1) {
            Text('周节点')
              .fontSize(12)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            ForEach(this.nodes, (view: PlanNodeView) => {
              this.nodeCard(view)
            }, (view: PlanNodeView) => view.node.id)
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
      route: 'plan_detail',
      title: '目标详情',
      content: () => {
        this.detailBody()
      },
      menus: () => {
        this.editMenu()
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        const params = context.pathInfo.param as PlanDetailParams;
        this.load(params.planId);
      },
      onDestinationShown: () => {
        if (this.planId.length > 0 && !this.isLoading) {
          this.refresh();
        }
      }
    })
  }
}
