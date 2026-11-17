import { common } from '@kit.AbilityKit';
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
import { ItemDecision } from '../plan/PlanService';
import { buildPlanReviewFacts, writePlanReviewDraft } from '../plan/PlanReviewDraft';
import { planLinkModuleLabel } from '../plan/PlanLinkCatalog';
import { NodeDays, NodeProgress, buildNodeProgress, nodeDays } from '../plan/PlanInsights';
import { WeekAgendaGroup, WeekAgendaRow, buildWeekAgenda } from '../plan/WeekAgendaMapper';
import { AgendaTone } from '../home/AgendaMapper';
import { PredictionListItem, PredictionService } from '../prediction';
import { PREVIEW_RELATION_ITEMS } from '../preview/PreviewData';
import { previewStore } from '../preview/PreviewStore';
import { RelationListItem, RelationService } from '../relation';
import { ReviewHistoryItem, ReviewService } from '../review';
import { PlanLinkPickerParams, PlanNodeParams } from '../navigation/RouteParams';
import {
  NoteDetailParams,
  PlanReviewParams,
  PredictionDetailParams,
  PredictionSettleParams,
  RelationDetailParams,
  ReviewDetailParams,
  StatusEditParams
} from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { planPreviewStore } from '../preview/PlanPreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** How one pending item leaves the week that is being closed. */
type CloseAction = 'carry' | 'pause' | 'discard';

/** One pending item's choice on the close-week panel. */
@ObservedV2
class CloseDecisionRow {
  itemId: string;
  text: string;
  @Trace action: CloseAction;
  @Trace reason: string;

  constructor(itemId: string, text: string) {
    this.itemId = itemId;
    this.text = text;
    this.action = 'carry';
    this.reason = '';
  }
}

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
  @Local closePanelVisible: boolean = false;
  @Local closeRows: CloseDecisionRow[] = [];
  @Local weekPredictions: WeekAgendaRow[] = [];
  @Local weekRelations: WeekAgendaRow[] = [];
  @Local weekReviews: WeekAgendaRow[] = [];
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
      await this.loadWeekAgenda(hostContext, node);
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
      this.applyWeekAgenda(this.node, previewStore.listPredictions(null),
        PREVIEW_RELATION_ITEMS, previewStore.reviewHistory());
    }
    this.isLoading = false;
  }

  private async loadWeekAgenda(context: common.Context, node: PlanNode): Promise<void> {
    try {
      const predictionService = await PredictionService.open(context);
      const predictions = await predictionService.list(null);
      const relationService = await RelationService.open(context);
      const relations = await relationService.list(null);
      const reviewService = await ReviewService.open(context);
      const reviews = await reviewService.history(60);
      this.applyWeekAgenda(node, predictions, relations, reviews);
    } catch (error) {
      this.weekPredictions = [];
      this.weekRelations = [];
      this.weekReviews = [];
    }
  }

  private applyWeekAgenda(node: PlanNode, predictions: PredictionListItem[],
    relations: RelationListItem[], reviews: ReviewHistoryItem[]): void {
    const agenda = buildWeekAgenda({
      node: node,
      predictions: predictions,
      relations: relations,
      reviews: reviews
    });
    this.weekPredictions = agenda.predictions;
    this.weekRelations = agenda.relations;
    this.weekReviews = agenda.reviews;
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
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext !== undefined) {
      await this.loadWeekAgenda(hostContext, node);
    }
  }

  private openClosePanel(): void {
    const rows: CloseDecisionRow[] = [];
    for (const item of this.items) {
      if (!item.done) {
        rows.push(new CloseDecisionRow(item.id, item.text));
      }
    }
    this.closeRows = rows;
    this.closePanelVisible = true;
  }

  private setAllActions(action: CloseAction): void {
    for (const row of this.closeRows) {
      row.action = action;
    }
  }

  private setRowAction(row: CloseDecisionRow, action: CloseAction): void {
    row.action = action;
  }

  private setRowReason(row: CloseDecisionRow, reason: string): void {
    row.reason = reason;
  }

  private async closeWeek(decisions: ItemDecision[]): Promise<void> {
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
        next = await this.service.closeNodeWithDecisions(closedNode.id, decisions);
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
      this.closePanelVisible = false;
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

  private confirmClose(): void {
    const decisions: ItemDecision[] = [];
    for (const row of this.closeRows) {
      const decision: ItemDecision = { itemId: row.itemId, action: row.action };
      const reason = row.reason.trim();
      if (row.action === 'discard' && reason.length > 0) {
        decision.reason = reason;
      }
      decisions.push(decision);
    }
    this.closeWeek(decisions);
  }

  private closeMessage(next: PlanNode | null, draftFailed: boolean): string {
    if (draftFailed) {
      return '本周已结束，草稿写入失败，可稍后重试';
    }
    return next === null ? '本周已结束' : '本周已结束，清单已写入周复盘草稿';
  }

  private progressRow(): NodeProgress | null {
    if (this.node === null) {
      return null;
    }
    const rows = buildNodeProgress([this.node], this.items);
    return rows.length > 0 ? rows[0] : null;
  }

  private remainingDays(): NodeDays {
    if (this.node === null) {
      return { left: 0, total: 7, percent: 0 };
    }
    return nodeDays(this.node.startDate, this.node.endDate, todayString());
  }

  private openWeekRow(row: WeekAgendaRow): void {
    if (this.navStack === null) {
      return;
    }
    if (row.group === WeekAgendaGroup.PREDICTION) {
      const params: PredictionSettleParams = { predictionId: row.targetId };
      this.navStack.pushPathByName(ROUTES.PREDICTION_SETTLE, params);
    } else if (row.group === WeekAgendaGroup.RELATION) {
      const params: RelationDetailParams = { relationId: row.targetId };
      this.navStack.pushPathByName(ROUTES.RELATION_DETAIL, params);
    } else {
      const params: ReviewDetailParams = { reviewId: row.targetId };
      this.navStack.pushPathByName(ROUTES.REVIEW_DETAIL, params);
    }
  }

  private toneColor(tone: AgendaTone): string {
    if (tone === AgendaTone.TIME) {
      return AppTheme.color.evTime;
    }
    if (tone === AgendaTone.BOOK) {
      return AppTheme.color.evBook;
    }
    if (tone === AgendaTone.PUBLIC) {
      return AppTheme.color.evPublic;
    }
    if (tone === AgendaTone.PRACTICE) {
      return AppTheme.color.evPractice;
    }
    return AppTheme.color.evOther;
  }

  @Builder
  agendaRow(row: WeekAgendaRow) {
    Row({ space: AppTheme.spacing.s10 }) {
      Circle()
        .width(6)
        .height(6)
        .fill(this.toneColor(row.tone))
      Column({ space: 2 }) {
        Text(row.title)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(row.detail)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(14)
        .fontColor([AppTheme.color.textMuted])
    }
    .width('100%')
    .constraintSize({ minHeight: 46 })
    .onClick(() => {
      this.openWeekRow(row);
    })
  }

  @Builder
  agendaGroup(title: string, rows: WeekAgendaRow[], emptyText: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .padding({ top: AppTheme.spacing.s2 })
      if (rows.length === 0) {
        Text(emptyText)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
          .padding({ top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      } else {
        ForEach(rows, (row: WeekAgendaRow) => {
          this.agendaRow(row)
        }, (row: WeekAgendaRow) => row.key)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  itemRow(item: PlanItem) {
    Row({ space: 8 }) {
      Text(item.done ? '✓' : '○')
        .fontSize(AppTheme.font.title)
        .fontColor(item.done ? AppTheme.color.success : AppTheme.color.textMuted)
        .width(26)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.toggle(item);
        })
      Column({ space: 2 }) {
        Text(item.text)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(item.done ? AppTheme.color.textMuted : AppTheme.color.text)
          .decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          .width('100%')
        if (item.carriedFrom !== undefined) {
          Text('上周延续')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.warning)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('删除')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .onClick(() => {
          this.remove(item);
        })
    }
    .width('100%')
    .padding({ top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
  }

  @Builder
  closeActionChip(label: string, action: CloseAction, row: CloseDecisionRow) {
    Text(label)
      .fontSize(AppTheme.font.caption)
      .fontColor(row.action === action ? Color.White : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .backgroundColor(row.action === action ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.md)
      .onClick(() => {
        this.setRowAction(row, action);
      })
  }

  @Builder
  closePanel() {
    Column({ space: AppTheme.spacing.s8 }) {
      Text('结束本周')
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text('逐项选择延续、暂停或舍弃；没有列出的未完成项默认延续。')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')

      Row({ space: AppTheme.spacing.s6 }) {
        Text('全部延续')
          .id('node_close_all_carry')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.primary)
          .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.md)
          .onClick(() => {
            this.setAllActions('carry');
          })
        Text('全部暂停')
          .id('node_close_all_pause')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.primary)
          .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.md)
          .onClick(() => {
            this.setAllActions('pause');
          })
        Text('全部舍弃')
          .id('node_close_all_discard')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.danger)
          .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
          .backgroundColor(AppTheme.color.dangerSurface)
          .borderRadius(AppTheme.radius.md)
          .onClick(() => {
            this.setAllActions('discard');
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: AppTheme.spacing.s6 }) {
          if (this.closeRows.length === 0) {
            Text('本周没有未完成项，确认后直接结束。')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          } else {
            ForEach(this.closeRows, (row: CloseDecisionRow) => {
              Column({ space: AppTheme.spacing.s4 }) {
                Text(row.text)
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
                Row({ space: AppTheme.spacing.s6 }) {
                  this.closeActionChip('延续', 'carry', row)
                  this.closeActionChip('暂停', 'pause', row)
                  this.closeActionChip('舍弃', 'discard', row)
                }
                .width('100%')
                if (row.action === 'discard') {
                  TextInput({ text: row.reason, placeholder: '舍弃原因（可空）' })
                    .id(`node_close_reason_${row.itemId}`)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .onChange((value: string) => {
                      this.setRowReason(row, value);
                    })
                }
              }
              .width('100%')
              .padding(AppTheme.spacing.s8)
              .backgroundColor(AppTheme.color.surfaceAlt)
              .borderRadius(AppTheme.radius.sm)
              .alignItems(HorizontalAlign.Start)
            }, (row: CloseDecisionRow) => row.itemId)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      Row({ space: AppTheme.spacing.s8 }) {
        Text('取消')
          .id('node_close_cancel')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.closePanelVisible = false;
          })
        Text(this.isSaving ? '处理中…' : '确认结束本周')
          .id('node_close_confirm')
          .fontSize(AppTheme.font.body)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.confirmClose();
          })
      }
      .width('100%')
    }
    .id('node_close_panel')
    .width('100%')
    .height('100%')
    .padding(AppTheme.spacing.s16)
    .alignItems(HorizontalAlign.Start)
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
                  .fontSize(AppTheme.font.headline)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.color.text)
                  .layoutWeight(1)
                Text(this.node.status === PlanNodeStatus.OPEN ? '进行中' : '已结束')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(this.node.status === PlanNodeStatus.OPEN ? AppTheme.color.success : AppTheme.color.textMuted)
                  .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                  .backgroundColor(this.node.status === PlanNodeStatus.OPEN ? AppTheme.color.successSurface : AppTheme.color.chip)
                  .borderRadius(AppTheme.radius.sm)
              }
              .width('100%')
              Text(`${this.node.startDate} 至 ${this.node.endDate}`)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
              if (this.plan !== null) {
                Text(this.plan.title)
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
              }
              if (this.node.status === PlanNodeStatus.OPEN && this.projects.length > 0) {
                Text('所属项目')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                  .padding({ top: AppTheme.spacing.s2 })
                Scroll() {
                  Row({ space: 6 }) {
                    Text('不分组')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(this.selectedProjectId.length === 0 ? Color.White : AppTheme.color.textSecondary)
                      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                      .backgroundColor(this.selectedProjectId.length === 0 ? AppTheme.color.primary : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.md)
                      .onClick(() => {
                        this.assignProject('');
                      })
                    ForEach(this.projects, (project: PlanProject) => {
                      Text(project.name)
                        .fontSize(AppTheme.font.caption)
                        .fontColor(this.selectedProjectId === project.id ? Color.White : AppTheme.color.textSecondary)
                        .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                        .backgroundColor(this.selectedProjectId === project.id ? AppTheme.color.primary : AppTheme.color.chip)
                        .borderRadius(AppTheme.radius.md)
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
            Column({ space: 8 }) {
              Row() {
                Text('本周剩余')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                Blank()
                Text(`${this.remainingDays().left} 天 / ${this.remainingDays().total} 天`)
                  .fontSize(AppTheme.font.body)
                  .fontColor(this.remainingDays().left <= 1 ? AppTheme.color.warning : AppTheme.color.text)
              }
              .width('100%')

              Progress({ value: this.remainingDays().percent, total: 100, type: ProgressType.Linear })
                .height(6)
                .color(this.remainingDays().left <= 1 ? AppTheme.color.warning : AppTheme.color.primary)
                .backgroundColor(AppTheme.color.track)

              if (this.progressRow() !== null && this.progressRow()!.total > 0) {
                DataPanel({
                  values: [
                    this.progressRow()!.done,
                    this.progressRow()!.openCarried,
                    this.progressRow()!.openNew
                  ],
                  max: this.progressRow()!.total,
                  type: DataPanelType.Line
                })
                  .height(10)
                  .width('100%')
                  .valueColors([0xFF2F7D4F, 0xFFE0A85C, 0xFFB9C6D2])
                Text(`完成 ${this.progressRow()!.done} · 延续 ${this.progressRow()!.openCarried} · 新加 ${this.progressRow()!.openNew}`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              } else {
                Text('清单为空，还没有可统计的完成度。')
                  .fontSize(AppTheme.font.caption)
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
                Text('本周串联')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.color.text)
                Blank()
                Text(`共 ${this.weekPredictions.length + this.weekRelations.length + this.weekReviews.length} 条`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
              }
              .width('100%')

              Text('把这一周要结算的判断、要回应的人和要写下的复盘放在同一段时间里。')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')

              this.agendaGroup('要结算的预测', this.weekPredictions, '本周没有待结算的预测')
              Divider().color(AppTheme.color.track)
              this.agendaGroup('要回应的人', this.weekRelations, '本周没有待回应的人')
              Divider().color(AppTheme.color.track)
              this.agendaGroup('要复盘的记录', this.weekReviews, '本周没有要复盘的记录')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 4 }) {
              Text('本周清单')
                .fontSize(AppTheme.font.bodyStrong)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.color.text)
                .width('100%')
              if (this.items.length === 0) {
                Text('还没有清单项，先加一条')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                  .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
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
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.color.text)
                  .layoutWeight(1)
                Text('选择记录')
                  .id('plan_link_open')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.primary)
                  .onClick(() => {
                    this.openLinkPicker();
                  })
              }
              .width('100%')
              if (this.links.length === 0) {
                Text('还没有关联速记、预测、复盘、锚点、关系或状态')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              } else {
                ForEach(this.links, (link: PlanLink) => {
                  Text(`${planLinkModuleLabel(link.module)} · ${link.label}`)
                    .fontSize(AppTheme.font.body)
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
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.primary)
                  .onClick(() => {
                    this.addItem();
                  })
              }
              .width('100%')
            }
          }

          if (this.node.status === PlanNodeStatus.OPEN) {
            Text(this.isSaving ? '处理中…' : '结束本周')
              .id('plan_node_close')
              .fontSize(AppTheme.font.subtitle)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
              .borderRadius(AppTheme.radius.md)
              .onClick(() => {
                if (!this.isSaving) {
                  this.openClosePanel();
                }
              })
          } else {
            Text(this.isPreview ? '本周已结束' : '本周已结束，清单已写入周复盘草稿')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s6 })
            Text('去复盘')
              .id('plan_node_review')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.primary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s10 })
              .onClick(() => {
                if (this.navStack !== null && this.node !== null) {
                  const params: PlanReviewParams = { planId: this.node.planId, nodeId: this.node.id };
                  this.navStack.pushPathByName(ROUTES.REVIEW, params);
                }
              })
          }
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s24 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .bindSheet($$this.closePanelVisible, this.closePanel(), {
        height: 560,
        dragBar: false,
        backgroundColor: AppTheme.color.surface
      })
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

function todayString(): string {
  const date = new Date();
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const monthText = month < 10 ? `0${month}` : `${month}`;
  const dayText = day < 10 ? `0${day}` : `${day}`;
  return `${date.getFullYear()}-${monthText}-${dayText}`;
}
