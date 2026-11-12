import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { PlanRhythmStrip } from '../components/PlanRhythmStrip';
import { PlanWeekView } from '../components/PlanWeekView';
import { PlanMonthView } from '../components/PlanMonthView';
import { PlanDeadlineCard } from '../components/PlanDeadlineCard';
import { SimpleLineChart } from '../components/charts/SimpleLineChart';
import { ChartPoint, ChartSeries } from '../components/charts/ChartModels';
import { Plan } from '../model/Plan';
import { PlanNode } from '../model/PlanNode';
import { PlanLink } from '../model/PlanLink';
import { PlanItem } from '../model/PlanItem';
import { PlanProject } from '../model/PlanProject';
import { PlanNodeStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { planLinkModuleLabel } from '../plan/PlanLinkCatalog';
import {
  CarryPoint,
  DayActivity,
  DayReading,
  DeadlineProgress,
  LinkCount,
  NodeProgress,
  buildDayActivity,
  buildNodeProgress,
  carrySeries,
  deadlineProgress,
  linkCounts,
  weekDates
} from '../plan/PlanInsights';
import { addPlanDays, parsePlanDate } from '../plan/PlanFactory';
import { QuickNoteService } from '../note';
import { StatusService } from '../status';
import { PlanDetailParams, PlanEditParams, PlanNodeParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { notifyHomeRefresh, subscribeHomeRefresh, unsubscribeHomeRefresh } from '../app/HomeRefreshBus';
import { LinkCompositionCard } from '../views/plan/LinkCompositionCard';

/** Goal detail: deadline, rhythm, week/month views and the node timeline. */
@ComponentV2
export struct PlanDetailPage {
  @Local plan: Plan | null = null;
  @Local nodes: NodeProgress[] = [];
  @Local projects: PlanProject[] = [];
  @Local newProjectName: string = '';
  @Local editingProjectId: string = '';
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local isPreview: boolean = false;
  @Local carryPoints: CarryPoint[] = [];
  @Local linkRows: LinkCount[] = [];
  @Local links: PlanLink[] = [];
  @Local deadline: DeadlineProgress = {
    hasTarget: false, percent: 0, remainingDays: 0, totalDays: 0, overdue: false
  };
  @Local viewMode: number = 0;
  @Local weekDays: DayActivity[] = [];
  @Local monthOffset: number = 0;
  private planId: string = '';
  private service: PlanService | null = null;
  private noteService: QuickNoteService | null = null;
  private statusService: StatusService | null = null;
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
      this.noteService = await QuickNoteService.open(hostContext);
      this.statusService = await StatusService.open(hostContext);
      this.plan = await service.findPlan(planId);
      if (this.plan === null) {
        this.missing = true;
        return;
      }
      this.projects = await service.listProjects(planId);
      const nodes = await service.listNodes(planId);
      if (nodes.length === 0) {
        await service.ensureFirstNode(planId);
      }
      const refreshed = await service.listNodes(planId);
      await this.applyNodes(service, refreshed);
      await this.applyLinks();
      await this.loadWeekView();
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
    this.projects = planPreviewStore.projects(this.planId);
    const nodes = planPreviewStore.nodes(this.planId);
    const items: PlanItem[] = [];
    for (const node of nodes) {
      for (const item of planPreviewStore.listItems(node.id)) {
        items.push(item);
      }
    }
    this.nodes = buildNodeProgress(nodes, items);
    this.carryPoints = carrySeries(this.nodes);
    this.links = planPreviewStore.linksByPlan(this.planId);
    this.linkRows = linkCounts(this.links);
    this.updateDeadline();
    this.loadWeekView();
    this.isLoading = false;
  }

  private async applyNodes(service: PlanService, nodes: PlanNode[]): Promise<void> {
    const items: PlanItem[] = [];
    for (const node of nodes) {
      for (const item of await service.listItems(node.id)) {
        items.push(item);
      }
    }
    this.nodes = buildNodeProgress(nodes, items);
    this.carryPoints = carrySeries(this.nodes);
    this.updateDeadline();
  }

  private async applyLinks(): Promise<void> {
    if (this.service === null) {
      this.links = planPreviewStore.linksByPlan(this.planId);
    } else {
      this.links = await this.service.listLinksByPlan(this.planId);
    }
    this.linkRows = linkCounts(this.links);
  }

  private updateDeadline(): void {
    if (this.plan === null) {
      return;
    }
    this.deadline = deadlineProgress(this.plan.startDate, this.plan.targetDate ?? '', todayString());
  }

  private async loadWeekView(): Promise<void> {
    const current = this.currentNode();
    if (current === null) {
      this.weekDays = [];
      return;
    }
    const dates = weekDates(current.startDate);
    let stamps: number[] = [];
    let readings: DayReading[] = [];
    if (this.noteService !== null) {
      const startMs = parsePlanDate(current.startDate).getTime();
      const endMs = parsePlanDate(addPlanDays(current.endDate, 1)).getTime() - 1;
      stamps = await this.noteService.timestampsBetween(startMs, endMs);
    }
    if (this.statusService !== null) {
      const rows = await this.statusService.history(30);
      for (const row of rows) {
        if (row.date >= current.startDate && row.date <= current.endDate) {
          readings.push({
            date: row.date,
            sleepHours: row.sleepHours,
            exerciseCount: row.exerciseCount
          });
        }
      }
    }
    this.weekDays = buildDayActivity(dates, stamps, readings);
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
    this.projects = await this.service.listProjects(this.planId);
    const nodes = await this.service.listNodes(this.planId);
    await this.applyNodes(this.service, nodes);
    await this.applyLinks();
    await this.loadWeekView();
  }

  private currentNode(): NodeProgress | null {
    let latest: NodeProgress | null = null;
    for (const view of this.nodes) {
      if (view.status === PlanNodeStatus.OPEN) {
        latest = view;
      }
    }
    if (latest === null && this.nodes.length > 0) {
      latest = this.nodes[this.nodes.length - 1];
    }
    return latest;
  }

  private monthRows(): NodeProgress[] {
    const base = new Date();
    base.setDate(1);
    base.setMonth(base.getMonth() + this.monthOffset);
    const prefix = `${base.getFullYear()}-${monthPad(base.getMonth() + 1)}`;
    const rows: NodeProgress[] = [];
    for (const row of this.nodes) {
      if (row.startDate.startsWith(prefix)) {
        rows.push(row);
      }
    }
    return rows;
  }

  private monthLabel(): string {
    const base = new Date();
    base.setDate(1);
    base.setMonth(base.getMonth() + this.monthOffset);
    return `${base.getFullYear()} 年 ${base.getMonth() + 1} 月`;
  }

  private carryChartSeries(): ChartSeries[] {
    const points: ChartPoint[] = [];
    for (const point of this.carryPoints) {
      points.push({
        label: point.label,
        value: point.percent,
        note: `${point.carried}/${point.total} 项延续`
      });
    }
    return [{ name: '延续率', color: 0xFF185FA5, points: points }];
  }

  private linkChartPoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    for (const row of this.linkRows) {
      points.push({
        label: planLinkModuleLabel(row.module),
        value: row.count,
        note: `${row.count} 条`
      });
    }
    return points;
  }

  private totalLinkCount(): number {
    let total = 0;
    for (const row of this.linkRows) {
      total += row.count;
    }
    return total;
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

  private async submitProject(): Promise<void> {
    if (this.plan === null || this.newProjectName.trim().length === 0) {
      return;
    }
    try {
      if (this.isPreview) {
        if (this.editingProjectId.length > 0) {
          planPreviewStore.renameProject(this.editingProjectId, this.newProjectName);
        } else {
          planPreviewStore.createProject(this.plan.id, this.newProjectName);
        }
        this.projects = planPreviewStore.projects(this.plan.id);
      } else if (this.service !== null) {
        if (this.editingProjectId.length > 0) {
          await this.service.renameProject(this.editingProjectId, this.newProjectName);
        } else {
          await this.service.createProject(this.plan.id, this.newProjectName);
        }
        this.projects = await this.service.listProjects(this.plan.id);
      }
      this.newProjectName = '';
      this.editingProjectId = '';
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({
        message: this.editingProjectId.length > 0 ? '项目改名失败，请重试' : '项目创建失败，请重试'
      });
    }
  }

  private beginRenameProject(project: PlanProject): void {
    this.editingProjectId = project.id;
    this.newProjectName = project.name;
  }

  private cancelRenameProject(): void {
    this.editingProjectId = '';
    this.newProjectName = '';
  }

  private confirmDeleteProject(project: PlanProject): void {
    this.getUIContext().showAlertDialog({
      title: `删除项目「${project.name}」？`,
      message: '项目下的周节点会回到未分组，节点与清单内容都保留。',
      primaryButton: {
        value: '保留',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.deleteProject(project);
        }
      }
    });
  }

  private async deleteProject(project: PlanProject): Promise<void> {
    if (this.plan === null) {
      return;
    }
    try {
      if (this.isPreview) {
        planPreviewStore.deleteProject(this.plan.id, project.id);
        this.projects = planPreviewStore.projects(this.plan.id);
        this.loadPreview();
      } else if (this.service !== null) {
        await this.service.deleteProject(this.plan.id, project.id);
        await this.refresh();
      }
      if (this.editingProjectId === project.id) {
        this.cancelRenameProject();
      }
      this.getUIContext().getPromptAction().showToast({ message: '项目已删除' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '项目删除失败，请重试' });
    }
  }

  private confirmArchive(): void {
    if (this.plan === null) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: `归档「${this.plan.title}」？`,
      message: '归档后目标从首页列表移出，可在计划列表的已归档区恢复。',
      primaryButton: {
        value: '继续推进',
        action: () => {
        }
      },
      secondaryButton: {
        value: '归档',
        action: () => {
          this.archivePlan();
        }
      }
    });
  }

  private async archivePlan(): Promise<void> {
    if (this.plan === null) {
      return;
    }
    try {
      if (this.isPreview) {
        planPreviewStore.archive(this.plan.id);
      } else if (this.service !== null) {
        await this.service.archive(this.plan.id);
      }
      this.getUIContext().getPromptAction().showToast({ message: '目标已归档' });
      notifyHomeRefresh();
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '归档失败，请重试' });
    }
  }

  @Builder
  editMenu() {
    Row({ space: 4 }) {
      Text('编辑')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s8 })
        .height(56)
        .onClick(() => {
          this.openEditor();
        })
      Text('归档')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.textSecondary)
        .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s16 })
        .height(56)
        .onClick(() => {
          this.confirmArchive();
        })
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  nodeCard(view: NodeProgress) {
    SectionCard() {
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(`第 ${view.weekIndex} 周`)
            .fontSize(AppTheme.font.subtitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text(view.status === PlanNodeStatus.OPEN ? '进行中' : '已结束')
            .fontSize(AppTheme.font.caption)
            .fontColor(view.status === PlanNodeStatus.OPEN ? AppTheme.color.success : AppTheme.color.textMuted)
            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
            .backgroundColor(view.status === PlanNodeStatus.OPEN ? AppTheme.color.successSurface : AppTheme.color.chip)
            .borderRadius(AppTheme.radius.sm)
          Blank()
          Text(`${view.done}/${view.total}`)
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
        }
        .width('100%')

        Text(`${view.startDate} 至 ${view.endDate}`)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openNode(view.nodeId);
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
                  .fontSize(AppTheme.font.headline)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.color.text)
                  .layoutWeight(1)
                Text(this.plan.isPrimary ? '主目标' : '目标')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.primaryDeep)
                  .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                  .backgroundColor(AppTheme.color.tint)
                  .borderRadius(AppTheme.radius.sm)
              }
              .width('100%')

              if (this.plan.goal.length > 0) {
                Text(this.plan.goal)
                  .fontSize(AppTheme.font.bodyStrong)
                  .lineHeight(18)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
              }
              Text(`起始 ${this.plan.startDate} · 周一至周日`)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 8 }) {
              Text('时间')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              PlanDeadlineCard({
                progress: this.deadline,
                weeksElapsed: this.nodes.length
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 8 }) {
              Text('周节奏')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              PlanRhythmStrip({
                rows: this.nodes,
                currentId: this.currentNode() !== null ? this.currentNode()!.nodeId : '',
                onOpen: (nodeId: string) => {
                  this.openNode(nodeId);
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 10 }) {
              Row({ space: 6 }) {
                Text('周视图')
                  .fontSize(AppTheme.font.body)
                  .fontColor(this.viewMode === 0 ? Color.White : AppTheme.color.textSecondary)
                  .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                  .backgroundColor(this.viewMode === 0 ? AppTheme.color.primary : AppTheme.color.surfaceAlt)
                  .borderRadius(AppTheme.radius.lg)
                  .onClick(() => {
                    this.viewMode = 0;
                  })
                Text('月视图')
                  .fontSize(AppTheme.font.body)
                  .fontColor(this.viewMode === 1 ? Color.White : AppTheme.color.textSecondary)
                  .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                  .backgroundColor(this.viewMode === 1 ? AppTheme.color.primary : AppTheme.color.surfaceAlt)
                  .borderRadius(AppTheme.radius.lg)
                  .onClick(() => {
                    this.viewMode = 1;
                  })
                Blank()
              }
              .width('100%')

              if (this.viewMode === 0) {
                PlanWeekView({ days: this.weekDays, previewMode: this.isPreview })
              } else {
                PlanMonthView({
                  rows: this.monthRows(),
                  label: this.monthLabel(),
                  onPrev: () => {
                    this.monthOffset -= 1;
                  },
                  onNext: () => {
                    this.monthOffset += 1;
                  },
                  onOpen: (nodeId: string) => {
                    this.openNode(nodeId);
                  }
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 8 }) {
              Row() {
                Text('延续率')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                Blank()
                Text('延续项 ÷ 当周清单')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
              }
              .width('100%')

              if (this.carryPoints.length >= 3) {
                SimpleLineChart({ series: this.carryChartSeries(), minValue: 0, maxValue: 100, chartHeight: 150 })
              } else {
                Text('至少三周有清单后，才画出延续率走势。')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          LinkCompositionCard({
            points: this.linkChartPoints(),
            total: this.totalLinkCount()
          })

          SectionCard() {
            Column({ space: 6 }) {
              Text('项目')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              if (this.projects.length === 0) {
                Text('还没有项目分组；项目是可选的，不影响周节点。')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              } else {
                ForEach(this.projects, (project: PlanProject) => {
                  Row({ space: 6 }) {
                    Text(project.name)
                      .fontSize(AppTheme.font.bodyStrong)
                      .fontColor(AppTheme.color.text)
                      .layoutWeight(1)
                    Text('改名')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.primary)
                      .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                      .onClick(() => {
                        this.beginRenameProject(project);
                      })
                    Text('删除')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.danger)
                      .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                      .onClick(() => {
                        this.confirmDeleteProject(project);
                      })
                  }
                  .width('100%')
                  .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s4, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .borderRadius(AppTheme.radius.sm)
                }, (project: PlanProject) => `${project.id}_${project.name}`)
              }
              Row({ space: 8 }) {
                TextInput({
                  text: this.newProjectName,
                  placeholder: this.editingProjectId.length > 0 ? '新的项目名称' : '新项目名称'
                })
                  .id('plan_project_input')
                  .maxLength(30)
                  .layoutWeight(1)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.newProjectName = value;
                  })
                if (this.editingProjectId.length > 0) {
                  Text('取消')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.textSecondary)
                    .onClick(() => {
                      this.cancelRenameProject();
                    })
                }
                Text(this.editingProjectId.length > 0 ? '保存' : '添加')
                  .id('plan_project_add')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.primary)
                  .onClick(() => {
                    this.submitProject();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          if (this.currentNode() !== null) {
            SectionCard() {
              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(this.currentNode()!.status === PlanNodeStatus.OPEN ? '本周节点' : '最近节点')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                  Text(`第 ${this.currentNode()!.weekIndex} 周 · ${this.currentNode()!.done}/${this.currentNode()!.total}`)
                    .fontSize(AppTheme.font.title)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                  Text(`${this.currentNode()!.startDate} 至 ${this.currentNode()!.endDate}`)
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textMuted)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text(this.currentNode()!.status === PlanNodeStatus.OPEN ? '进入本周 ›' : '查看 ›')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.primary)
              }
              .width('100%')
              .onClick(() => {
                this.openNode(this.currentNode()!.nodeId);
              })
            }
          }

          if (this.nodes.length > 1) {
            Text('周节点')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            ForEach(this.nodes, (view: NodeProgress) => {
              this.nodeCard(view)
            }, (view: NodeProgress) =>
              `${view.nodeId}_${view.done}_${view.total}_${view.status}_${view.openCarried}`)
          }
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s24 })
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
        if (context.pathInfo.param === undefined) {
          this.missing = true;
          this.isLoading = false;
          return;
        }
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

function todayString(): string {
  const date = new Date();
  return `${date.getFullYear()}-${monthPad(date.getMonth() + 1)}-${monthPad(date.getDate())}`;
}

function monthPad(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
