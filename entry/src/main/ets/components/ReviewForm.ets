import { Anchor } from '../model/Anchor';
import { CostDimension, CostDraft } from '../model/CostNote';
import { DECISION_RECORD_TYPES, DecisionDraft, DecisionRecordType } from '../model/DecisionRecord';
import { EvidenceDraft, EvidenceEffect, EvidenceSource } from '../model/EvidenceItem';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { PlanItem } from '../model/PlanItem';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppTheme } from '../theme/AppTheme';
import { formatHitRate } from '../model/HomeModel';
import { isPlanDate } from '../plan/PlanValidation';
import { PlanService } from '../plan/PlanService';
import { RelationListItem } from '../relation/RelationListItem';
import { RelationService } from '../relation/RelationService';
import { MaterialPicker } from './MaterialPicker';
import { ReviewPromptPanel } from './ReviewPromptPanel';
import { ReviewAgentPanel } from './ReviewAgentPanel';
import { AnchorCitation, hasAnyZone, MotivationKind, MOTIVATION_KINDS, motivationText, ReviewPayload, ReviewStanding, REVIEW_STANDINGS, standingText } from '../model/ReviewPayload';
import { WorkDepth, WORK_DEPTHS, workDepthText } from '../model/WorkDepth';
import {
  ReviewDraft,
  ReviewService,
  ReviewStats,
  emptyReviewStats
} from '../review';
import { PREVIEW_ANCHORS, PREVIEW_RELATION_ITEMS, PREVIEW_REVIEW_STATS } from '../preview/PreviewData';
import { previewStore } from '../preview/PreviewStore';
import { ReviewDraftStore } from '../review/ReviewDraftStore';
import { RecentDecisionItem } from '../review/ReviewService';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

const ZONE_LABELS: string[] = [
  '现场与既有行动',
  '当前模型',
  '关系与主要矛盾',
  '多源校正',
  '成本与动机',
  '调节与修订'
];
const ZONE_HINTS: string[] = [
  '先写现场：发生了什么，我已经做了什么。',
  '我现在的解释、预测、适用范围，以及什么能证明它错。',
  '这件事牵涉哪些人，主要矛盾在哪一条关系上。',
  '实践、他人、身体、时间、书里的说法，哪里和我的模型不一致。',
  '维持现状的代价是什么，我为什么要改。',
  '下一次遇到类似情况，准备怎么做。'
];
const ZONE_PLACEHOLDERS: string[] = [
  '例如：连续四天睡不到 7 小时，周三临时改期两次。',
  '例如：我把它归因于「最近状态差」，但没有具体证据。',
  '例如：我答应同事的事一拖再拖，和我在意的可靠冲突。',
  '例如：记录显示熬夜后的第二天效率更低。',
  '例如：拖延让我每天多耗两小时，代价是不被信任。',
  '例如：晚上十点后不再安排需要集中注意力的事。'
];
const LAST_ZONE: number = 5;

/** Six-zone review form for one period; each tab owns its own draft. */
@ComponentV2
export struct ReviewForm {
  @Param period: ReviewPeriod = ReviewPeriod.WEEK;
  @Param planId: string = '';
  @Param planNodeId: string = '';
  @Event onBackToPlan: () => void = () => {};
  @Local stats: ReviewStats = emptyReviewStats();
  @Local anchors: Anchor[] = [];
  @Local materials: ExperienceMaterial[] = [];
  @Local selectedMaterialIds: string[] = [];
  @Local evidenceDrafts: EvidenceDraft[] = [];
  @Local evidenceRevision: number = 0;
  @Local costDrafts: CostDraft[] = [];
  @Local costRevision: number = 0;
  @Local step: number = 0;
  @Local promptVisible: boolean = true;
  @Local facts: string = '';
  @Local interpretation: string = '';
  @Local contradiction: string = '';
  @Local action: string = '';
  @Local zoneScene: string = '';
  @Local zoneModel: string = '';
  @Local zoneRelation: string = '';
  @Local zoneEvidence: string = '';
  @Local zoneCost: string = '';
  @Local zoneRevision: string = '';
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local saved: boolean = false;
  @Local selectedAnchorIds: string[] = [];
  @Local anchorCitations: AnchorCitation[] = [];
  @Local decisionIds: string[] = [];
  @Local decisions: RecentDecisionItem[] = [];
  @Local relations: RelationListItem[] = [];
  @Local decisionType: DecisionRecordType | null = null;
  @Local standing: ReviewStanding = 'decided';
  @Local decisionReason: string = '';
  @Local decisionAction: string = '';
  @Local decisionCommitment: string = '';
  @Local decisionRelationId: string = '';
  @Local decisionOutcome: string = '';
  @Local decisionReviewAt: string = '';
  @Local decisionParticipation: string = '';
  @Local motivation: MotivationKind | '' = '';
  @Local depth: WorkDepth = 'normal';
  @Local timeBudgetText: string = '';
  @Local planItems: PlanItem[] = [];
  @Local planItemId: string = '';
  @Local isPreview: boolean = false;
  private service: ReviewService | null = null;
  private draftStore: ReviewDraftStore | null = null;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.persistDraft();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await ReviewService.open(hostContext);
      this.draftStore = await ReviewDraftStore.open(hostContext);
      this.stats = await this.service.loadStats(this.period);
      this.anchors = await this.service.loadAnchors(3);
      this.selectedAnchorIds = [];
      this.syncAnchorCitations();
      this.materials = await this.service.recentMaterials(50);
      try {
        this.decisions = await this.service.recentDecisions(20);
      } catch (error) {
        this.decisions = [];
      }
      try {
        const relationService = await RelationService.open(hostContext);
        this.relations = await relationService.list(null);
      } catch (error) {
        this.relations = [];
      }
      try {
        const planService = await PlanService.open(hostContext);
        const primary = await planService.primaryPlan();
        if (primary !== null) {
          const node = await planService.currentNode(primary.id);
          if (node !== null) {
            const items = await planService.listItems(node.id);
            this.planItems = items.filter((item: PlanItem) => !item.done);
          }
        }
      } catch (error) {
        this.planItems = [];
      }
      const draft = await this.draftStore.loadFor(this.period, this.planNodeId);
      if (draft !== null) {
        this.facts = draft.facts;
        this.interpretation = draft.interpretation;
        this.contradiction = draft.contradiction;
        this.action = draft.action;
        if (draft.payload !== undefined) {
          this.zoneScene = draft.payload.scene;
          this.zoneModel = draft.payload.model;
          this.zoneRelation = draft.payload.relation;
          this.zoneEvidence = draft.payload.evidence;
          this.zoneCost = draft.payload.cost;
          this.zoneRevision = draft.payload.revision;
          this.evidenceDrafts = (draft.payload.evidenceDrafts ?? []).slice();
          this.costDrafts = (draft.payload.costDrafts ?? []).slice();
          this.decisionIds = (draft.payload.decisionIds ?? []).slice();
          this.standing = draft.payload.standing ?? 'decided';
          const decisionDraft = draft.payload.decisionDraft;
          if (decisionDraft !== undefined) {
            this.decisionType = decisionDraft.type;
            this.decisionReason = decisionDraft.reason;
            this.decisionAction = decisionDraft.action ?? '';
            this.decisionCommitment = decisionDraft.commitment ?? '';
            this.decisionRelationId = decisionDraft.relationId ?? '';
            this.decisionOutcome = decisionDraft.outcome ?? '';
            this.decisionReviewAt = decisionDraft.reviewAt ?? '';
            this.decisionParticipation = decisionDraft.participationMode ?? '';
            this.planItemId = decisionDraft.planItemId ?? '';
          }
          this.motivation = draft.payload.motivation ?? '';
          this.depth = draft.payload.depth ?? 'normal';
          this.timeBudgetText = draft.payload.timeBudget !== undefined ? String(draft.payload.timeBudget) : '';
        }
        if (draft.anchorIds.length > 0) {
          this.selectedAnchorIds = draft.anchorIds.slice();
          this.anchorCitations = draft.payload !== undefined ?
            (draft.payload.anchorCitations ?? []).slice() : [];
          this.syncAnchorCitations();
        }
        if (draft.materialIds !== undefined && draft.materialIds.length > 0) {
          this.selectedMaterialIds = draft.materialIds.slice();
        }
      }
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '复盘数据加载失败' });
    }
  }

  private currentPayload(): ReviewPayload {
    return {
      scene: this.zoneScene,
      model: this.zoneModel,
      relation: this.zoneRelation,
      evidence: this.zoneEvidence,
      cost: this.zoneCost,
      revision: this.zoneRevision,
      decisionIds: this.uniqueDecisionIds(),
      evidenceDrafts: this.evidenceDrafts.slice(),
      costDrafts: this.costDrafts.slice(),
      decisionDraft: this.currentDecisionDraft(),
      motivation: this.motivation === '' ? undefined : this.motivation,
      depth: this.depth,
      timeBudget: this.budgetValue(),
      anchorCitations: this.anchorCitations.slice(),
      standing: this.standing
    };
  }

  private budgetValue(): number | undefined {
    const value = Number(this.timeBudgetText.trim());
    return Number.isFinite(value) && value > 0 ? Math.round(value) : undefined;
  }

  private currentDecisionDraft(): DecisionDraft | undefined {
    if (this.standing !== 'decided' || this.decisionType === null) {
      return undefined;
    }
    return {
      type: this.decisionType,
      reason: this.decisionReason,
      action: this.decisionAction,
      commitment: this.decisionCommitment,
      relationId: this.decisionRelationId,
      planItemId: this.planItemId,
      outcome: this.decisionOutcome,
      reviewAt: this.decisionReviewAt,
      participationMode: this.decisionParticipation
    };
  }

  private decisionError(): string {
    if (this.standing !== 'decided' || this.decisionType === null) {
      return '';
    }
    if (this.decisionReason.trim().length === 0) {
      return '填写决定原因后再保存';
    }
    if (this.decisionType === 'joint' && this.decisionRelationId.length === 0) {
      return '共同实践要选一条关系';
    }
    const reviewAt = this.decisionReviewAt.trim();
    if (reviewAt.length > 0 && !isPlanDate(reviewAt)) {
      return '回看日期格式应为 YYYY-MM-DD';
    }
    return '';
  }

  private selectDecisionType(type: DecisionRecordType): void {
    this.decisionType = type;
    if (type !== 'joint') {
      this.decisionRelationId = '';
      this.decisionOutcome = '';
      this.decisionParticipation = '';
    }
    if (type !== 'joint' && type !== 'switch') {
      this.decisionReviewAt = '';
    }
    this.persistDraft();
  }

  private updateDecisionReason(value: string): void {
    this.decisionReason = value;
    this.persistDraft();
  }

  private updateDecisionAction(value: string): void {
    this.decisionAction = value;
    this.persistDraft();
  }

  private updateDecisionCommitment(value: string): void {
    this.decisionCommitment = value;
    this.persistDraft();
  }

  private updateDecisionRelation(id: string): void {
    this.decisionRelationId = id;
    this.persistDraft();
  }

  private updateDecisionOutcome(value: string): void {
    this.decisionOutcome = value;
    this.persistDraft();
  }

  private updateDecisionReviewAt(value: string): void {
    this.decisionReviewAt = value;
    this.persistDraft();
  }

  /** Picks one plan item, or clears it when the same item is tapped again. */
  private togglePlanItem(id: string): void {
    this.planItemId = this.planItemId === id ? '' : id;
    this.persistDraft();
  }

  private actionHint(): string {
    return this.decisionType === 'pause' || this.decisionType === 'discard' ||
      this.decisionType === 'exit' ? '可留空' : '下一步具体做什么';
  }

  /** Drops repeated decision ids while keeping the order they were picked in. */
  private uniqueDecisionIds(): string[] {
    const result: string[] = [];
    for (const id of this.decisionIds) {
      if (!result.includes(id)) {
        result.push(id);
      }
    }
    return result;
  }

  private buildDraft(): ReviewDraft {
    return {
      facts: this.facts,
      interpretation: this.interpretation,
      contradiction: this.contradiction,
      action: this.action,
      payload: this.currentPayload(),
      materialIds: this.selectedMaterialIds.slice(),
      anchorIds: this.selectedAnchorIds.slice(),
      planId: this.planId,
      planNodeId: this.planNodeId
    };
  }

  private persistDraft(): void {
    if (this.draftStore === null) {
      return;
    }
    const draft: ReviewDraft = this.buildDraft();
    this.draftStore.saveFor(this.period, this.planNodeId, draft).catch(() => {
    });
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.stats = PREVIEW_REVIEW_STATS;
    this.anchors = PREVIEW_ANCHORS.slice(0, 3);
    this.selectedAnchorIds = this.anchors.map((anchor: Anchor) => anchor.id);
    this.relations = PREVIEW_RELATION_ITEMS.slice();
    this.isLoading = false;
  }

  private currentText(): string {
    if (this.step === 0) {
      return this.zoneScene;
    }
    if (this.step === 1) {
      return this.zoneModel;
    }
    if (this.step === 2) {
      return this.zoneRelation;
    }
    if (this.step === 3) {
      return this.zoneEvidence;
    }
    if (this.step === 4) {
      return this.zoneCost;
    }
    return this.zoneRevision;
  }

  private updateCurrent(value: string): void {
    if (this.step === 0) {
      this.zoneScene = value;
    } else if (this.step === 1) {
      this.zoneModel = value;
    } else if (this.step === 2) {
      this.zoneRelation = value;
    } else if (this.step === 3) {
      this.zoneEvidence = value;
    } else if (this.step === 4) {
      this.zoneCost = value;
    } else {
      this.zoneRevision = value;
    }
    this.persistDraft();
  }

  private appendRelation(text: string): void {
    const current = this.zoneRelation.trim();
    this.zoneRelation = current.length > 0 ? `${current}\n${text}` : text;
    this.persistDraft();
  }

  private savedSummary(): string {
    if (this.zoneRevision.trim().length > 0) {
      return this.zoneRevision;
    }
    if (this.zoneScene.trim().length > 0) {
      return this.zoneScene;
    }
    return this.action;
  }

  private isAnchorSelected(id: string): boolean {
    return this.selectedAnchorIds.includes(id);
  }

  private toggleAnchor(id: string): void {
    if (this.isAnchorSelected(id)) {
      this.selectedAnchorIds = this.selectedAnchorIds.filter((item: string) => item !== id);
    } else {
      this.selectedAnchorIds = this.selectedAnchorIds.concat([id]);
    }
    this.syncAnchorCitations();
    this.persistDraft();
  }

  private syncAnchorCitations(): void {
    const next: AnchorCitation[] = [];
    for (const id of this.selectedAnchorIds) {
      const existing = this.anchorCitations.find((item: AnchorCitation) => item.anchorId === id);
      next.push({
        anchorId: id,
        reason: existing !== undefined ? existing.reason : '',
        supports: existing !== undefined ? (existing.supports ?? '') : '',
        limits: existing !== undefined ? (existing.limits ?? '') : '',
        notApplicable: existing !== undefined ? (existing.notApplicable ?? '') : ''
      });
    }
    this.anchorCitations = next;
  }

  private reasonOf(id: string): string {
    const existing = this.anchorCitations.find((item: AnchorCitation) => item.anchorId === id);
    return existing !== undefined ? existing.reason : '';
  }

  private supportsOf(id: string): string {
    const existing = this.anchorCitations.find((item: AnchorCitation) => item.anchorId === id);
    return existing !== undefined ? (existing.supports ?? '') : '';
  }

  private limitsOf(id: string): string {
    const existing = this.anchorCitations.find((item: AnchorCitation) => item.anchorId === id);
    return existing !== undefined ? (existing.limits ?? '') : '';
  }

  private notApplicableOf(id: string): string {
    const existing = this.anchorCitations.find((item: AnchorCitation) => item.anchorId === id);
    return existing !== undefined ? (existing.notApplicable ?? '') : '';
  }

  private updateAnchorField(id: string, field: 'reason' | 'supports' | 'limits' | 'notApplicable',
    value: string): void {
    const next: AnchorCitation[] = [];
    for (const citation of this.anchorCitations) {
      if (citation.anchorId !== id) {
        next.push(citation);
        continue;
      }
      next.push({
        anchorId: id,
        reason: field === 'reason' ? value : citation.reason,
        supports: field === 'supports' ? value : (citation.supports ?? ''),
        limits: field === 'limits' ? value : (citation.limits ?? ''),
        notApplicable: field === 'notApplicable' ? value : (citation.notApplicable ?? '')
      });
    }
    this.anchorCitations = next;
    this.persistDraft();
  }

  private updateAnchorReason(id: string, value: string): void {
    this.updateAnchorField(id, 'reason', value);
  }

  private toggleMaterial(id: string): void {
    if (this.selectedMaterialIds.includes(id)) {
      this.selectedMaterialIds = this.selectedMaterialIds.filter((item: string) => item !== id);
    } else {
      this.selectedMaterialIds = this.selectedMaterialIds.concat([id]);
    }
    this.persistDraft();
  }

  /** Relation rows cited by the selected `relation:` materials. */
  private selectedRelationMaterials(): RelationListItem[] {
    const ids: string[] = [];
    for (const id of this.selectedMaterialIds) {
      if (id.startsWith('relation:')) {
        ids.push(id.substring('relation:'.length));
      }
    }
    return this.relations.filter((item: RelationListItem) => ids.includes(item.id));
  }

  /** True when any selected material comes from a relation. */
  private hasRelationMaterial(): boolean {
    return this.selectedMaterialIds.some((id: string) => id.startsWith('relation:'));
  }

  /** True when any cited relation forbids motive, personality or outcome analysis. */
  private relationForbids(): boolean {
    const rows = this.selectedRelationMaterials();
    const ids = this.selectedMaterialIds.filter((id: string) => id.startsWith('relation:'));
    return rows.length < ids.length || rows.some((item: RelationListItem) => item.forbidAnalysis);
  }

  /** First cited relation id; the panel shows it as the binding. */
  private relationHintId(): string {
    const rows = this.selectedRelationMaterials();
    return rows.length > 0 ? rows[0].id : '';
  }

  /** Strictest level among the review body and its cited relation materials. */
  private relationMaxLevel(): SecurityLevel {
    const rows = this.selectedRelationMaterials();
    const ids = this.selectedMaterialIds.filter((id: string) => id.startsWith('relation:'));
    if (rows.length < ids.length) {
      return SecurityLevel.SEALED;
    }
    let level = SecurityLevel.LOCAL_ONLY;
    for (const row of rows) {
      if (row.level === SecurityLevel.SEALED) {
        return SecurityLevel.SEALED;
      }
      if (row.level === SecurityLevel.LOCAL_ONLY) {
        level = SecurityLevel.LOCAL_ONLY;
      }
    }
    return level;
  }

  private isDecisionSelected(id: string): boolean {
    return this.decisionIds.includes(id);
  }

  private toggleDecision(id: string): void {
    if (this.isDecisionSelected(id)) {
      this.decisionIds = this.decisionIds.filter((item: string) => item !== id);
    } else {
      this.decisionIds = this.decisionIds.concat([id]);
    }
    this.persistDraft();
  }

  private replaceEvidence(index: number, draft: EvidenceDraft): void {
    const next: EvidenceDraft[] = this.evidenceDrafts.slice();
    next[index] = draft;
    this.evidenceDrafts = next;
    this.persistDraft();
  }

  private updateEvidenceSource(index: number, sourceType: EvidenceSource): void {
    const current: EvidenceDraft = this.evidenceDrafts[index];
    const updated: EvidenceDraft = {
      sourceType: sourceType,
      note: current.note,
      effect: current.effect
    };
    this.replaceEvidence(index, updated);
  }

  private updateEvidenceNote(index: number, note: string): void {
    const current: EvidenceDraft = this.evidenceDrafts[index];
    const updated: EvidenceDraft = {
      sourceType: current.sourceType,
      note: note,
      effect: current.effect
    };
    this.replaceEvidence(index, updated);
  }

  private updateEvidenceEffect(index: number, effect: EvidenceEffect): void {
    const current: EvidenceDraft = this.evidenceDrafts[index];
    const updated: EvidenceDraft = {
      sourceType: current.sourceType,
      note: current.note,
      effect: effect
    };
    this.replaceEvidence(index, updated);
  }

  private addEvidence(): void {
    const blank: EvidenceDraft = { sourceType: 'practice', note: '', effect: 'unclear' };
    this.evidenceDrafts = this.evidenceDrafts.concat([blank]);
    this.evidenceRevision += 1;
    this.persistDraft();
  }

  private removeEvidence(index: number): void {
    this.evidenceDrafts = this.evidenceDrafts.filter((draft: EvidenceDraft, itemIndex: number) => itemIndex !== index);
    this.evidenceRevision += 1;
    this.persistDraft();
  }

  private replaceCost(index: number, draft: CostDraft): void {
    const next: CostDraft[] = this.costDrafts.slice();
    next[index] = draft;
    this.costDrafts = next;
    this.persistDraft();
  }

  private updateCostDimension(index: number, dimension: CostDimension): void {
    const current: CostDraft = this.costDrafts[index];
    const updated: CostDraft = {
      dimension: dimension,
      text: current.text,
      bearable: current.bearable
    };
    this.replaceCost(index, updated);
  }

  private updateCostText(index: number, text: string): void {
    const current: CostDraft = this.costDrafts[index];
    const updated: CostDraft = {
      dimension: current.dimension,
      text: text,
      bearable: current.bearable
    };
    this.replaceCost(index, updated);
  }

  private updateCostBearable(index: number, bearable: boolean): void {
    const current: CostDraft = this.costDrafts[index];
    const updated: CostDraft = {
      dimension: current.dimension,
      text: current.text,
      bearable: bearable
    };
    this.replaceCost(index, updated);
  }

  private addCost(): void {
    const blank: CostDraft = { dimension: 'time', text: '', bearable: true };
    this.costDrafts = this.costDrafts.concat([blank]);
    this.costRevision += 1;
    this.persistDraft();
  }

  private removeCost(index: number): void {
    this.costDrafts = this.costDrafts.filter((draft: CostDraft, itemIndex: number) => itemIndex !== index);
    this.costRevision += 1;
    this.persistDraft();
  }

  private async complete(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const decisionError = this.decisionError();
    if (decisionError.length > 0) {
      this.step = LAST_ZONE;
      this.getUIContext().getPromptAction().showToast({ message: decisionError });
      return;
    }
    if (!hasAnyZone(this.currentPayload()) && this.selectedMaterialIds.length === 0) {
      this.step = 0;
      this.getUIContext().getPromptAction().showToast({ message: '先写一句现场，或引用一条材料' });
      return;
    }
    if (this.isPreview) {
      previewStore.saveReview(this.period, this.buildDraft(), this.stats.rangeLabel);
      notifyHomeRefresh();
      this.saved = true;
      this.getUIContext().getPromptAction().showToast({ message: '演示模式：复盘已保存在当前会话' });
      return;
    }
    if (this.service === null) {
      this.getUIContext().getPromptAction().showToast({ message: '数据库尚未就绪' });
      return;
    }
    this.isSaving = true;
    try {
      await this.service.save(this.period, this.buildDraft(), this.stats.rangeLabel, this.planId, this.planNodeId);
      if (this.draftStore !== null) {
        await this.draftStore.clearFor(this.period, this.planNodeId);
      }
      notifyHomeRefresh();
      this.saved = true;
      this.getUIContext().getPromptAction().showToast({ message: '复盘已保存' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private restart(): void {
    this.step = 0;
    this.facts = '';
    this.interpretation = '';
    this.contradiction = '';
    this.action = '';
    this.zoneScene = '';
    this.zoneModel = '';
    this.zoneRelation = '';
    this.zoneEvidence = '';
    this.zoneCost = '';
    this.zoneRevision = '';
    this.evidenceDrafts = [];
    this.evidenceRevision += 1;
    this.costDrafts = [];
    this.costRevision += 1;
    this.decisionIds = [];
    this.anchorCitations = [];
    this.decisionType = null;
    this.decisionReason = '';
    this.decisionAction = '';
    this.decisionCommitment = '';
    this.decisionRelationId = '';
    this.decisionOutcome = '';
    this.decisionReviewAt = '';
    this.planItemId = '';
    this.motivation = '';
    this.depth = 'normal';
    this.timeBudgetText = '';
    this.saved = false;
    if (this.draftStore !== null) {
      this.draftStore.clearFor(this.period, this.planNodeId).catch(() => {
      });
    }
    this.load();
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

  private zoneFilled(index: number): boolean {
    const payload = this.currentPayload();
    const texts: string[] = [payload.scene, payload.model, payload.relation, payload.evidence, payload.cost, payload.revision];
    if (texts[index].trim().length > 0) {
      return true;
    }
    if (index === 0) {
      return this.selectedMaterialIds.length > 0;
    }
    if (index === 3) {
      return this.evidenceDrafts.length > 0;
    }
    if (index === 4) {
      return this.costDrafts.length > 0;
    }
    return false;
  }

  @Builder
  zoneTabs() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(ZONE_LABELS, (label: string, index: number) => {
          Row({ space: 6 }) {
            Circle()
              .width(6)
              .height(6)
              .fill(this.zoneFilled(index) ? AppTheme.color.primary : AppTheme.color.border)
            Text(label)
              .fontSize(AppTheme.font.body)
              .fontWeight(index === this.step ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(index === this.step ? AppTheme.color.text : AppTheme.color.textSecondary)
          }
          .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
          .backgroundColor(index === this.step ? AppTheme.color.tint : Color.Transparent)
          .borderRadius(20)
          .border({ width: index === this.step ? 1 : 0, color: AppTheme.color.borderSelected })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
          .onClick(() => {
            this.step = index;
          })
        }, (label: string) => label)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  evidenceSourceChip(index: number, value: EvidenceSource, label: string) {
    Text(label)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.evidenceDrafts[index].sourceType === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.evidenceDrafts[index].sourceType === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .id(`evidence_source_${index}_${value}`)
      .onClick(() => {
        this.updateEvidenceSource(index, value);
      })
  }

  @Builder
  evidenceEffectChip(index: number, value: EvidenceEffect, label: string) {
    Text(label)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.evidenceDrafts[index].effect === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.evidenceDrafts[index].effect === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .id(`evidence_effect_${index}_${value}`)
      .onClick(() => {
        this.updateEvidenceEffect(index, value);
      })
  }

  @Builder
  evidenceEditor() {
    Column({ space: 8 }) {
      Column({ space: 2 }) {
        Text('证据')
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text('把这一区的说法拆成一条条来源和它支持或挑战什么。')
          .fontSize(AppTheme.font.caption)
          .lineHeight(17)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.evidenceDrafts.length === 0) {
        Text('还没有证据，点下方「添加一条证据」。')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }

      ForEach(this.evidenceDrafts, (draft: EvidenceDraft, index: number) => {
        Column({ space: 6 }) {
          Flex({ wrap: FlexWrap.Wrap }) {
            this.evidenceSourceChip(index, 'practice', '实践')
            this.evidenceSourceChip(index, 'other_person', '他人')
            this.evidenceSourceChip(index, 'body', '身体')
            this.evidenceSourceChip(index, 'time', '时间')
            this.evidenceSourceChip(index, 'book', '书本')
            this.evidenceSourceChip(index, 'public', '公开资料')
          }
          .width('100%')

          TextInput({ text: draft.note, placeholder: '这条证据具体是什么' })
            .fontSize(AppTheme.font.bodyStrong)
            .padding(AppTheme.spacing.s10)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.sm)
            .border({ width: 0.5, color: AppTheme.color.border })
            .onChange((value: string) => {
              this.updateEvidenceNote(index, value);
            })

          Row({ space: 6 }) {
            Flex({ wrap: FlexWrap.Wrap }) {
              this.evidenceEffectChip(index, 'supports', '支持')
              this.evidenceEffectChip(index, 'challenges', '挑战')
              this.evidenceEffectChip(index, 'unclear', '不清楚')
            }
            .layoutWeight(1)

            Text('删除')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.danger)
              .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
              .id(`evidence_remove_${index}`)
              .onClick(() => {
                this.removeEvidence(index);
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppTheme.spacing.s10)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(AppTheme.radius.md)
      }, (draft: EvidenceDraft, index: number) => `${this.evidenceRevision}_${index}_${draft.sourceType}_${draft.effect}`)

      Text('添加一条证据')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
        .backgroundColor(AppTheme.color.tint)
        .borderRadius(AppTheme.radius.lg)
        .id('evidence_add')
        .onClick(() => {
          this.addEvidence();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  costDimensionChip(index: number, value: CostDimension, label: string) {
    Text(label)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.costDrafts[index].dimension === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.costDrafts[index].dimension === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .id(`cost_dimension_${index}_${value}`)
      .onClick(() => {
        this.updateCostDimension(index, value);
      })
  }

  @Builder
  costEditor() {
    Column({ space: 8 }) {
      Column({ space: 2 }) {
        Text('成本')
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text('把这一区的代价分成一条条，并标出是否承受得住。')
          .fontSize(AppTheme.font.caption)
          .lineHeight(17)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.costDrafts.length === 0) {
        Text('还没有成本，点下方「添加一条成本」。')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }

      ForEach(this.costDrafts, (draft: CostDraft, index: number) => {
        Column({ space: 6 }) {
          Flex({ wrap: FlexWrap.Wrap }) {
            this.costDimensionChip(index, 'meaning', '意义')
            this.costDimensionChip(index, 'body', '身体')
            this.costDimensionChip(index, 'relationship', '关系')
            this.costDimensionChip(index, 'time', '时间')
            this.costDimensionChip(index, 'public', '公共生活')
            this.costDimensionChip(index, 'other', '其他')
          }
          .width('100%')

          Row({ space: 8 }) {
            TextInput({ text: draft.text, placeholder: '这条成本具体是什么' })
              .fontSize(AppTheme.font.bodyStrong)
              .padding(AppTheme.spacing.s10)
              .layoutWeight(1)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.sm)
              .border({ width: 0.5, color: AppTheme.color.border })
              .onChange((value: string) => {
                this.updateCostText(index, value);
              })
            Text('可承受')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textSecondary)
            Toggle({ type: ToggleType.Switch, isOn: draft.bearable })
              .id(`cost_bearable_${index}`)
              .onChange((isOn: boolean) => {
                this.updateCostBearable(index, isOn);
              })
          }
          .width('100%')

          Row() {
            Text(draft.bearable ? '可承受' : '不可承受')
              .fontSize(AppTheme.font.caption)
              .fontColor(draft.bearable ? AppTheme.color.textSecondary : AppTheme.color.warning)
            Blank()
            Text('删除')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.danger)
              .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
              .id(`cost_remove_${index}`)
              .onClick(() => {
                this.removeCost(index);
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppTheme.spacing.s10)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(AppTheme.radius.md)
      }, (draft: CostDraft, index: number) => `${this.costRevision}_${index}_${draft.dimension}_${draft.bearable ? 1 : 0}`)

      Text('添加一条成本')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
        .backgroundColor(AppTheme.color.tint)
        .borderRadius(AppTheme.radius.lg)
        .id('cost_add')
        .onClick(() => {
          this.addCost();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  motivationChip(value: MotivationKind, label: string) {
    Text(label)
      .id(`review_motivation_${value}`)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.motivation === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.motivation === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .onClick(() => {
        this.motivation = this.motivation === value ? '' : value;
        this.persistDraft();
      })
  }

  @Builder
  motivationEditor() {
    Column({ space: 6 }) {
      Text('动机')
        .fontSize(AppTheme.font.bodyStrong)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .width('100%')
      Text('这次行动的动力来自哪里；可跳过，再点一次取消。')
        .fontSize(AppTheme.font.caption)
        .lineHeight(17)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(MOTIVATION_KINDS, (kind: MotivationKind) => {
          this.motivationChip(kind, motivationText(kind))
        }, (kind: MotivationKind) => kind)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  depthChip(value: WorkDepth, label: string) {
    Text(label)
      .id(`review_depth_${value}`)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.depth === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6 })
      .backgroundColor(this.depth === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .onClick(() => {
        this.depth = value;
        this.persistDraft();
      })
  }

  @Builder
  depthEditor() {
    Column({ space: 6 }) {
      Text('本次深度')
        .fontSize(AppTheme.font.bodyStrong)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .width('100%')
      Text('快速只写现场；普通走完六区；深入再回看模型与证据。')
        .fontSize(AppTheme.font.caption)
        .lineHeight(17)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(WORK_DEPTHS, (value: WorkDepth) => {
          this.depthChip(value, workDepthText(value))
        }, (value: WorkDepth) => value)
      }
      .width('100%')
      TextInput({ text: this.timeBudgetText, placeholder: '本次时间预算（分钟，可空）' })
        .id('review_depth_budget')
        .type(InputType.Number)
        .fontSize(AppTheme.font.bodyStrong)
        .padding(AppTheme.spacing.s10)
        .backgroundColor(AppTheme.color.surface)
        .borderRadius(AppTheme.radius.sm)
        .border({ width: 0.5, color: AppTheme.color.border })
        .onChange((value: string) => {
          this.timeBudgetText = value;
          this.persistDraft();
        })
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surfaceAlt)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  decisionTypeChip(value: DecisionRecordType, label: string) {
    Text(label)
      .id(`review_decision_type_${value}`)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.decisionType === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.decisionType === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .onClick(() => {
        this.selectDecisionType(value);
      })
  }

  @Builder
  relationChip(relation: RelationListItem) {
    Text(relation.name)
      .id(`review_decision_relation_${relation.id}`)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.decisionRelationId === relation.id ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6 })
      .backgroundColor(this.decisionRelationId === relation.id ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .onClick(() => {
        this.updateDecisionRelation(relation.id);
      })
  }

  @Builder
  standingChip(value: ReviewStanding) {
    Text(standingText(value))
      .id(`review_standing_${value}`)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.standing === value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.standing === value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .onClick(() => {
        this.standing = value;
        this.persistDraft();
      })
  }

  @Builder
  standingEditor() {
    Column({ space: 6 }) {
      Text('本次结果')
        .fontSize(AppTheme.font.bodyStrong)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .width('100%')
      Text('不形成决定也可以保存；选择后不会要求填写决定原因。')
        .fontSize(AppTheme.font.caption)
        .lineHeight(17)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(REVIEW_STANDINGS, (value: ReviewStanding) => {
          this.standingChip(value)
        }, (value: ReviewStanding) => value)
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surfaceAlt)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  decisionEditor() {
    Column({ space: 10 }) {
      Column({ space: 2 }) {
        Text('本次决定')
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text('选一种类型并写清原因；不选类型时只保存复盘。')
          .fontSize(AppTheme.font.caption)
          .lineHeight(17)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(DECISION_RECORD_TYPES, (type: DecisionRecordType) => {
          this.decisionTypeChip(type, decisionTypeLabel(type))
        }, (type: DecisionRecordType) => type)
      }
      .width('100%')

      if (this.decisionType !== null) {
        Text('原因')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        TextInput({ text: this.decisionReason, placeholder: '为什么这样选（必填）' })
          .id('review_decision_reason')
          .fontSize(AppTheme.font.bodyStrong)
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surface)
          .borderRadius(AppTheme.radius.sm)
          .border({ width: 0.5, color: AppTheme.color.border })
          .onChange((value: string) => {
            this.updateDecisionReason(value);
          })

        Text(`行动 · ${this.actionHint()}`)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        TextArea({ text: this.decisionAction, placeholder: this.actionHint() })
          .id('review_decision_action')
          .fontSize(AppTheme.font.bodyStrong)
          .height(90)
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surface)
          .borderRadius(AppTheme.radius.sm)
          .border({ width: 0.5, color: AppTheme.color.border })
          .onChange((value: string) => {
            this.updateDecisionAction(value);
          })

        Text('承诺')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        TextInput({ text: this.decisionCommitment, placeholder: '叙事真空处的主动承诺（可空）' })
          .id('review_decision_commitment')
          .fontSize(AppTheme.font.bodyStrong)
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surface)
          .borderRadius(AppTheme.radius.sm)
          .border({ width: 0.5, color: AppTheme.color.border })
          .onChange((value: string) => {
            this.updateDecisionCommitment(value);
          })

        if (this.planItems.length > 0) {
          Text('关联计划项 · 再点一次取消')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.planItems, (item: PlanItem) => {
              Text(item.text)
                .id(`review_decision_plan_item_${item.id}`)
                .fontSize(AppTheme.font.caption)
                .fontColor(this.planItemId === item.id ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
                .backgroundColor(this.planItemId === item.id ? AppTheme.color.tint : AppTheme.color.chip)
                .borderRadius(AppTheme.radius.sm)
                .onClick(() => {
                  this.togglePlanItem(item.id);
                })
            }, (item: PlanItem) => `${item.id}_${this.planItemId === item.id ? 1 : 0}`)
          }
          .width('100%')
        }

        if (this.decisionType === 'joint') {
          Text('关系')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
          if (this.relations.length === 0) {
            Text('还没有关系记录')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          } else {
            Scroll() {
              Row({ space: 6 }) {
                ForEach(this.relations, (relation: RelationListItem) => {
                  this.relationChip(relation)
                }, (relation: RelationListItem) => `${relation.id}_${this.decisionRelationId === relation.id ? 1 : 0}`)
              }
            }
            .width('100%')
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
          }

          Text('结果')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
          TextInput({ text: this.decisionOutcome, placeholder: '共同实践的实际结果（可空）' })
            .id('review_decision_outcome')
            .fontSize(AppTheme.font.bodyStrong)
            .padding(AppTheme.spacing.s10)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.sm)
            .border({ width: 0.5, color: AppTheme.color.border })
            .onChange((value: string) => {
              this.updateDecisionOutcome(value);
            })
          Text('对方可接受参与方式')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
          TextInput({ text: this.decisionParticipation, placeholder: '对方愿意以什么方式参与（可空）' })
            .id('review_decision_participation')
            .fontSize(AppTheme.font.bodyStrong)
            .padding(AppTheme.spacing.s10)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.sm)
            .border({ width: 0.5, color: AppTheme.color.border })
            .onChange((value: string) => {
              this.decisionParticipation = value;
              this.persistDraft();
            })
        }

        if (this.decisionType === 'joint' || this.decisionType === 'switch') {
          Text('回看日期')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
          TextInput({ text: this.decisionReviewAt, placeholder: 'YYYY-MM-DD（可空）' })
            .id('review_decision_review_at')
            .fontSize(AppTheme.font.bodyStrong)
            .padding(AppTheme.spacing.s10)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.sm)
            .border({ width: 0.5, color: AppTheme.color.border })
            .onChange((value: string) => {
              this.updateDecisionReviewAt(value);
            })
        }
      }
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  decisionPicker() {
    Column({ space: 8 }) {
      Text('涉及的决定')
        .fontSize(AppTheme.font.bodyStrong)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .width('100%')
      if (this.decisions.length === 0) {
        Text('还没有决策记录')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
          .id('review_decision_empty')
      }
      ForEach(this.decisions, (decision: RecentDecisionItem) => {
        Column({ space: 2 }) {
          Text(decision.title)
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(this.isDecisionSelected(decision.id) ? AppTheme.color.primaryDeep : AppTheme.color.text)
            .width('100%')
          Text(decision.choice)
            .fontSize(AppTheme.font.caption)
            .fontColor(this.isDecisionSelected(decision.id) ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
            .width('100%')
        }
        .width('100%')
        .padding(AppTheme.spacing.s10)
        .backgroundColor(this.isDecisionSelected(decision.id) ? AppTheme.color.tint : AppTheme.color.surfaceAlt)
        .borderRadius(AppTheme.radius.sm)
        .border({
          width: this.isDecisionSelected(decision.id) ? 1 : 0,
          color: AppTheme.color.borderSelected
        })
        .id(`review_decision_${decision.id}`)
        .onClick(() => {
          this.toggleDecision(decision.id);
        })
      }, (decision: RecentDecisionItem) => `${decision.id}_${this.isDecisionSelected(decision.id) ? 1 : 0}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if (this.planNodeId.length > 0) {
        Row({ space: 8 }) {
          Text('来自计划节点')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
          Blank()
          Text('返回节点 ›')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.onBackToPlan();
            })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s2 })
      }
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
      } else if (this.saved) {
        Column({ space: 12 }) {
          Text('本期复盘已完成')
            .fontSize(AppTheme.font.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text(this.stats.rangeLabel)
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.textSecondary)
          Text(this.savedSummary())
            .fontSize(AppTheme.font.subtitle)
            .lineHeight(22)
            .fontColor(AppTheme.color.text)
            .textAlign(TextAlign.Center)
          Text('再写一条')
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.primary)
            .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(AppTheme.radius.lg)
            .margin({ top: AppTheme.spacing.s8 })
            .onClick(() => {
              this.restart();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(AppTheme.spacing.s24)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 8 }) {
              Row() {
                Text(this.period === ReviewPeriod.WEEK ? '本周' : '本月')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.color.text)
                Blank()
                Text(this.stats.rangeLabel)
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
              }
              .width('100%')

              Row() {
                this.statItem(String(this.stats.noteCount), '速记')
                this.statItem(String(this.stats.decisionCount), '决策')
                this.statItem(String(this.stats.settledPredictions), '已结算')
                this.statItem(formatHitRate(this.stats.hitRate, this.stats.settledPredictions), '命中率')
              }
              .width('100%')
            }
            .width('100%')
            .padding(AppTheme.spacing.s16)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.md)

            this.depthEditor()

            this.zoneTabs()

            if (this.step === 0 && this.promptVisible) {
              ReviewPromptPanel({
                period: this.period,
                onDismiss: () => {
                  this.promptVisible = false;
                }
              })
            }

            Text(`${this.step + 1}. ${ZONE_LABELS[this.step]}`)
              .fontSize(AppTheme.font.title)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.color.text)
              .width('100%')
            Text(ZONE_HINTS[this.step])
              .fontSize(AppTheme.font.bodyStrong)
              .lineHeight(18)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')

            if (this.step === 2 && this.anchors.length > 0) {
              Column({ space: 8 }) {
                Text('对照锚点 · 点击选择本次真正用到的')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                ForEach(this.anchors, (anchor: Anchor) => {
                  Column({ space: 4 }) {
                    Row() {
                      Text(anchor.text)
                        .fontSize(AppTheme.font.bodyStrong)
                        .lineHeight(20)
                        .fontColor(AppTheme.color.text)
                        .layoutWeight(1)
                      if (this.isAnchorSelected(anchor.id)) {
                        Text('已对照')
                          .fontSize(AppTheme.font.caption)
                          .fontColor(AppTheme.color.primary)
                          .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                          .backgroundColor(AppTheme.color.tint)
                          .borderRadius(AppTheme.radius.sm)
                      }
                    }
                    .width('100%')
                    Text(anchor.source)
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                    if (this.isAnchorSelected(anchor.id)) {
                      TextInput({ text: this.reasonOf(anchor.id), placeholder: '为什么选这条锚点（可空）' })
                        .id(`review_anchor_reason_${anchor.id}`)
                        .fontSize(AppTheme.font.caption)
                        .padding(AppTheme.spacing.s8)
                        .backgroundColor(AppTheme.color.surface)
                        .borderRadius(AppTheme.radius.sm)
                        .onClick(() => {
                        })
                        .onChange((value: string) => {
                          this.updateAnchorReason(anchor.id, value);
                        })
                      TextInput({ text: this.supportsOf(anchor.id), placeholder: '支持什么（可空）' })
                        .id(`review_anchor_supports_${anchor.id}`)
                        .fontSize(AppTheme.font.caption)
                        .padding(AppTheme.spacing.s8)
                        .backgroundColor(AppTheme.color.surface)
                        .borderRadius(AppTheme.radius.sm)
                        .onChange((value: string) => {
                          this.updateAnchorField(anchor.id, 'supports', value);
                        })
                      TextInput({ text: this.limitsOf(anchor.id), placeholder: '限制什么（可空）' })
                        .id(`review_anchor_limits_${anchor.id}`)
                        .fontSize(AppTheme.font.caption)
                        .padding(AppTheme.spacing.s8)
                        .backgroundColor(AppTheme.color.surface)
                        .borderRadius(AppTheme.radius.sm)
                        .onChange((value: string) => {
                          this.updateAnchorField(anchor.id, 'limits', value);
                        })
                      TextInput({ text: this.notApplicableOf(anchor.id), placeholder: '何处不适用（可空）' })
                        .id(`review_anchor_not_applicable_${anchor.id}`)
                        .fontSize(AppTheme.font.caption)
                        .padding(AppTheme.spacing.s8)
                        .backgroundColor(AppTheme.color.surface)
                        .borderRadius(AppTheme.radius.sm)
                        .onChange((value: string) => {
                          this.updateAnchorField(anchor.id, 'notApplicable', value);
                        })
                    }
                  }
                  .width('100%')
                  .padding(AppTheme.spacing.s10)
                  .backgroundColor(this.isAnchorSelected(anchor.id) ? AppTheme.color.selectedSurface : AppTheme.color.surfaceWarm)
                  .borderRadius(AppTheme.radius.sm)
                  .border({
                    width: this.isAnchorSelected(anchor.id) ? 1 : 0,
                    color: AppTheme.color.borderSelected
                  })
                  .onClick(() => {
                    this.toggleAnchor(anchor.id);
                  })
                }, (anchor: Anchor) => `${anchor.id}_${this.isAnchorSelected(anchor.id) ? 1 : 0}`)
              }
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surfaceWarm)
              .borderRadius(AppTheme.radius.md)
              .alignItems(HorizontalAlign.Start)
            }

            if (this.step === 2) {
              ReviewAgentPanel({
                facts: this.zoneScene,
                interpretation: this.zoneModel,
                anchors: this.anchors,
                relationForbidsAnalysis: this.relationForbids(),
                relationInvolvedByMaterial: this.hasRelationMaterial(),
                relationIdHint: this.relationHintId(),
                maxLevel: this.relationMaxLevel(),
                onInsert: (text: string) => {
                  this.appendRelation(text);
                }
              })
            }

            if (this.step === LAST_ZONE) {
              this.standingEditor()
              if (this.standing === 'decided') {
                this.decisionEditor()
              } else {
                Text('本次不形成决定，决定区不会写入；仍可补充现场、模型或修订。')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              }
              this.decisionPicker()
            }

            TextArea({ text: this.currentText(), placeholder: ZONE_PLACEHOLDERS[this.step] })
              .fontSize(AppTheme.font.bodyStrong)
              .height(180)
              .padding(AppTheme.spacing.s12)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.md)
              .border({ width: 0.5, color: AppTheme.color.border })
              .onChange((value: string) => {
                this.updateCurrent(value);
              })

            if (this.step === 3) {
              this.evidenceEditor()
            }

            if (this.step === 4) {
              this.costEditor()
              this.motivationEditor()
            }

            if (this.step === 0) {
              MaterialPicker({
                materials: this.materials,
                selectedIds: this.selectedMaterialIds,
                onToggle: (id: string) => {
                  this.toggleMaterial(id);
                }
              })
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.s16)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        Row({ space: 12 }) {
          Text(`${this.step + 1} / ${LAST_ZONE + 1}`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
          Text('保存复盘')
            .id('review_save')
            .fontSize(AppTheme.font.subtitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
            .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
            .borderRadius(20)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
            .accessibilityText('保存复盘')
            .onClick(() => {
              if (this.isSaving) {
                return;
              }
              this.complete();
            })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

function decisionTypeLabel(type: DecisionRecordType): string {
  if (type === 'continue') {
    return '继续';
  }
  if (type === 'switch') {
    return '切换';
  }
  if (type === 'pause') {
    return '暂停';
  }
  if (type === 'discard') {
    return '舍弃';
  }
  if (type === 'exit') {
    return '退出';
  }
  return '共同实践';
}
