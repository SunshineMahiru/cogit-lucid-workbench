import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { Plan } from '../model/Plan';
import { PlanNode } from '../model/PlanNode';
import { PlanProject } from '../model/PlanProject';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanNodeStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { buildPlanReviewFacts, writePlanReviewDraft } from '../plan/PlanReviewDraft';
import { planLinkModuleLabel } from '../plan/PlanLinkCatalog';
import { PlanLinkPickerParams, PlanNodeParams } from '../navigation/RouteParams';
import {
  NoteDetailParams,
  PlanReviewParams,
  PredictionDetailParams,
  RelationDetailParams,
  ReviewDetailParams,
  StatusEditParams
} from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** One seven-day node: checklist, carry-over marks and closing action. */
@ComponentV2
export struct PlanNodePage {
  @Local node: PlanNode | null = null;
  @Local plan: Plan | null = null;
  @Local items: PlanItem[] = [];
  @Local links: PlanLink[] = [];
  @Local projects: PlanProject[] = [];
  @Local selectedProjectId: string = '';
  @Local newText: string = '';
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local isPreview: boolean = false;
  private nodeId: string = '';
  private service: PlanService | null = null;
  private navStack: NavPathStack | null = null;

  private async load(nodeId: string): Promise<void> {
    this.nodeId = nodeId;
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      const service = await PlanService.open(hostContext);
      this.service = service;
      const node = await service.findNode(nodeId);
      if (node === null) {
        this.isLoading = false;
        return;
      }
      this.node = node;
      this.plan = await service.findPlan(node.planId);
      this.projects = await service.listProjects(node.planId);
      this.selectedProjectId = node.projectId ?? '';
      this.items = await service.listItems(nodeId);
      this.links = await service.listLinks(nodeId);
    } catch (error) {
      this.loadPreview();
    } finally {
      this.isLoading = false;
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.node = planPreviewStore.findNode(this.nodeId);
    if (this.node !== null) {
      this.plan = planPreviewStore.find(this.node.planId);
      this.projects = planPreviewStore.projects(this.node.planId);
      this.selectedProjectId = this.node.projectId ?? '';
      this.items = planPreviewStore.listItems(this.nodeId);
      this.links = planPreviewStore.links(this.nodeId);
    }
    this.isLoading = false;
  }

  private async addItem(): Promise<void> {
    if (this.newText.trim().length === 0 || this.isSaving) {
      return;
    }
    this.isSaving = true;
    try {
      if (this.isPreview) {
        planPreviewStore.addItem(this.nodeId, this.newText);
        this.items = planPreviewStore.listItems(this.nodeId);
      } else if (this.service !== null) {
        await this.service.addItem(this.nodeId, this.newText);
        this.items = await this.service.listItems(this.nodeId);
      }
      this.newText = '';
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '添加失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private async toggle(item: PlanItem): Promise<void> {
    const next = !item.done;
    if (this.isPreview) {
      planPreviewStore.setItemDone(item.id, next);
      this.items = planPreviewStore.listItems(this.nodeId);
      return;
    }
    if (this.service === null) {
      return;
    }
    try {
      await this.service.setItemDone(item.id, next);
      this.items = await this.service.listItems(this.nodeId);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '更新失败，请重试' });
    }
  }

  private async remove(item: PlanItem): Promise<void> {
    if (this.isPreview) {
      planPreviewStore.removeItem(item.id);
      this.items = planPreviewStore.listItems(this.nodeId);
      return;
    }
    if (this.service === null) {
      return;
    }
    try {
      await this.service.removeItem(item.id);
      this.items = await this.service.listItems(this.nodeId);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '删除失败，请重试' });
    }
  }

  private async assignProject(projectId: string): Promise<void> {
    if (this.node === null) {
      return;
    }
    try {
      if (this.isPreview) {
        planPreviewStore.setNodeProject(this.node.id, projectId);
      } else if (this.service !== null) {
        await this.service.setNodeProject(this.node.id, projectId);
      }
      this.selectedProjectId = projectId;
      if (this.node !== null) {
        this.node.projectId = projectId.length > 0 ? projectId : undefined;
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '项目归属保存失败' });
    }
  }

  private openLinkedRecord(link: PlanLink): void {
    if (this.navStack === null) {
      return;
    }
    if (link.module === PlanLinkModule.NOTE) {
      const params: NoteDetailParams = { noteId: link.targetId };
      this.navStack.pushPathByName(ROUTES.NOTE_DETAIL, params);
    } else if (link.module === PlanLinkModule.PREDICTION) {
      const params: PredictionDetailParams = { predictionId: link.targetId };
      this.navStack.pushPathByName(ROUTES.PREDICTION_DETAIL, params);
    } else if (link.module === PlanLinkModule.REVIEW) {
      const params: ReviewDetailParams = { reviewId: link.targetId };
      this.navStack.pushPathByName(ROUTES.REVIEW_DETAIL, params);
    } else if (link.module === PlanLinkModule.ANCHOR) {
      this.navStack.pushPathByName(ROUTES.ANCHOR, null);
    } else if (link.module === PlanLinkModule.RELATION) {
      const params: RelationDetailParams = { relationId: link.targetId };
      this.navStack.pushPathByName(ROUTES.RELATION_DETAIL, params);
    } else if (link.module === PlanLinkModule.STATUS) {
      const params: StatusEditParams = { date: link.label };
      this.navStack.pushPathByName(ROUTES.STATUS_EDIT, params);
    }
  }

  private openLinkPicker(): void {
    if (this.navStack === null || this.node === null) {
      return;
    }
    const params: PlanLinkPickerParams = {
      planId: this.node.planId,
      nodeId: this.node.id,
      weekStart: this.node.startDate,
      weekEnd: this.node.endDate
    };
    this.navStack.pushPathByName(ROUTES.PLAN_LINK_PICKER, params, () => {
      this.reloadLinks();
    });
  }

  private async reloadLinks(): Promise<void> {
    if (this.isPreview) {
      this.links = planPreviewStore.links(this.nodeId);
      return;
    }
    if (this.service === null) {
      return;
    }
    this.links = await this.service.listLinks(this.nodeId);
  }

  private async refreshNode(): Promise<void> {
    if (this.nodeId.length === 0) {
      return;
    }
    if (this.isPreview) {
      this.loadPreview();
      return;
    }
    if (this.service === null) {
      return;
    }
    const node = await this.service.findNode(this.nodeId);
    if (node === null) {
      return;
    }
    this.node = node;
    this.projects = await this.service.listProjects(node.planId);
    this.selectedProjectId = node.projectId ?? '';
    this.items = await this.service.listItems(this.nodeId);
    this.links = await this.service.listLinks(this.nodeId);
  }

  private async closeWeek(): Promise<void> {
    if (this.node === null || this.node.status === PlanNodeStatus.CLOSED || this.isSaving) {
      return;
    }
    this.isSaving = true;
    const closedNode = this.node;
    const closedItems = this.items;
    let draftFailed = false;
    try {
      let next: PlanNode | null = null;
      if (this.isPreview) {
        next = planPreviewStore.closeAndCarry(closedNode.id);
      } else if (this.service !== null) {
        next = await this.service.closeNodeAndCarry(closedNode.id);
      }
      const facts = buildPlanReviewFacts(this.plan !== null ? this.plan.title : '', closedNode, closedItems, next);
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext !== undefined && !this.isPreview) {
        try {
          await writePlanReviewDraft(hostContext, facts, closedNode.planId, closedNode.id);
        } catch (draftError) {
          draftFailed = true;
        }
      }
      this.getUIContext().getPromptAction().showToast({
        message: this.closeMessage(next, draftFailed)
      });
      notifyHomeRefresh();
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '结束本周失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private closeMessage(next: PlanNode | null, draftFailed: boolean): string {
    if (draftFailed) {
      return '本周已结束，草稿写入失败，可稍后重试';
    }
    return next === null ? '本周已结束' : '本周已结束，清单已写入周复盘草稿';
  }

  @Builder
  itemRow(item: PlanItem) {
    Row({ space: 8 }) {
      Text(item.done ? '✓' : '○')
        .fontSize(16)
        .fontColor(item.done ? AppTheme.color.success : AppTheme.color.textMuted)
        .width(26)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.toggle(item);
        })
      Column({ space: 2 }) {
        Text(item.text)
          .fontSize(13)
          .fontColor(item.done ? AppTheme.color.textMuted : AppTheme.color.text)
          .decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          .width('100%')
        if (item.carriedFrom !== undefined) {
          Text('上周延续')
            .fontSize(9)
            .fontColor(AppTheme.color.warning)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('删除')
        .fontSize(10)
        .fontColor(AppTheme.color.textMuted)
        .onClick(() => {
          this.remove(item);
        })
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  @Builder
  nodeBody() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(32).height(32).color(AppTheme.color.primary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.node === null) {
      Column() {
        NoteEmptyState({
          title: '节点不存在',
          hint: '可能已经被移除',
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
                Text(`第 ${this.node.weekIndex} 周`)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.color.text)
                  .layoutWeight(1)
                Text(this.node.status === PlanNodeStatus.OPEN ? '进行中' : '已结束')
                  .fontSize(10)
                  .fontColor(this.node.status === PlanNodeStatus.OPEN ? AppTheme.color.success : AppTheme.color.textMuted)
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor(this.node.status === PlanNodeStatus.OPEN ? AppTheme.color.successSurface : AppTheme.color.chip)
                  .borderRadius(6)
              }
              .width('100%')
              Text(`${this.node.startDate} 至 ${this.node.endDate}`)
                .fontSize(10)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
              if (this.plan !== null) {
                Text(this.plan.title)
                  .fontSize(12)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
              }
              if (this.node.status === PlanNodeStatus.OPEN && this.projects.length > 0) {
                Text('所属项目')
                  .fontSize(10)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                  .padding({ top: 2 })
                Scroll() {
                  Row({ space: 6 }) {
                    Text('不分组')
                      .fontSize(10)
                      .fontColor(this.selectedProjectId.length === 0 ? Color.White : AppTheme.color.textSecondary)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(this.selectedProjectId.length === 0 ? AppTheme.color.primary : AppTheme.color.chip)
                      .borderRadius(10)
                      .onClick(() => {
                        this.assignProject('');
                      })
                    ForEach(this.projects, (project: PlanProject) => {
                      Text(project.name)
                        .fontSize(10)
                        .fontColor(this.selectedProjectId === project.id ? Color.White : AppTheme.color.textSecondary)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor(this.selectedProjectId === project.id ? AppTheme.color.primary : AppTheme.color.chip)
                        .borderRadius(10)
                        .onClick(() => {
                          this.assignProject(project.id);
                        })
                    }, (project: PlanProject) =>
                      `${project.id}_${project.name}_${this.selectedProjectId === project.id ? 1 : 0}`)
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 4 }) {
              Text('本周清单')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.color.text)
                .width('100%')
              if (this.items.length === 0) {
                Text('还没有清单项，先加一条')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
              } else {
                ForEach(this.items, (item: PlanItem) => {
                  this.itemRow(item)
                }, (item: PlanItem) => `${item.id}_${item.done ? 1 : 0}`)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 5 }) {
              Row({ space: 8 }) {
                Text('关联记录')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.color.text)
                  .layoutWeight(1)
                Text('选择记录')
                  .id('plan_link_open')
                  .fontSize(11)
                  .fontColor(AppTheme.color.primary)
                  .onClick(() => {
                    this.openLinkPicker();
                  })
              }
              .width('100%')
              if (this.links.length === 0) {
                Text('还没有关联速记、预测、复盘、锚点、关系或状态')
                  .fontSize(10)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              } else {
                ForEach(this.links, (link: PlanLink) => {
                  Text(`${planLinkModuleLabel(link.module)} · ${link.label}`)
                    .fontSize(11)
                    .fontColor(AppTheme.color.primary)
                    .width('100%')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .onClick(() => {
                      this.openLinkedRecord(link);
                    })
                }, (link: PlanLink) => `${link.id}_${link.label}`)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          if (this.node.status === PlanNodeStatus.OPEN) {
            SectionCard() {
              Row({ space: 8 }) {
                TextInput({ text: this.newText, placeholder: '加一条本周要做的事' })
                  .id('plan_item_input')
                  .maxLength(120)
                  .layoutWeight(1)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.newText = value;
                  })
                Text('添加')
                  .id('plan_item_add')
                  .fontSize(12)
                  .fontColor(AppTheme.color.primary)
                  .onClick(() => {
                    this.addItem();
                  })
              }
              .width('100%')
            }
          }

          if (this.node.status === PlanNodeStatus.OPEN) {
            Text(this.isSaving ? '处理中…' : '结束本周，未完成带入下周')
              .id('plan_node_close')
              .fontSize(14)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 })
              .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
              .borderRadius(12)
              .onClick(() => {
                this.closeWeek();
              })
          } else {
            Text(this.isPreview ? '本周已结束' : '本周已结束，清单已写入周复盘草稿')
              .fontSize(12)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 6 })
            Text('去复盘')
              .id('plan_node_review')
              .fontSize(13)
              .fontColor(AppTheme.color.primary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 6, bottom: 10 })
              .onClick(() => {
                if (this.navStack !== null && this.node !== null) {
                  const params: PlanReviewParams = { planId: this.node.planId, nodeId: this.node.id };
                  this.navStack.pushPathByName(ROUTES.REVIEW, params);
                }
              })
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
      route: 'plan_node',
      title: '七日节点',
      content: () => {
        this.nodeBody()
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          return;
        }
        const params = context.pathInfo.param as PlanNodeParams;
        this.load(params.nodeId);
      },
      onDestinationShown: () => {
        if (this.nodeId.length > 0 && !this.isLoading) {
          this.refreshNode();
        }
      }
    })
  }
}
