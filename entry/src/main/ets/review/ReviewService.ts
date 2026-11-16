import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Anchor } from '../model/Anchor';
import { CostDraft, CostNote } from '../model/CostNote';
import { Decision } from '../model/Decision';
import { DecisionDraft, DecisionRecord } from '../model/DecisionRecord';
import { Event } from '../model/Event';
import { EvidenceDraft, EvidenceItem } from '../model/EvidenceItem';
import { ExperienceMaterial, InteractionSource as MaterialInteractionSource } from '../model/ExperienceMaterial';
import { createReviewResult } from '../model/factories';
import { Prediction } from '../model/Prediction';
import { Relation } from '../model/Relation';
import { ReviewMaterial, REVIEW_ZONE } from '../model/ReviewMaterial';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { emptyReviewPayload, hasAnyZone } from '../model/ReviewPayload';
import { SecurityLevel } from '../model/SecurityLevel';
import { StatusRecord } from '../model/StatusRecord';
import { countReviewWindow, ReviewWindowCounts } from '../analysis/metrics/ReviewMetrics';
import { DbHelper } from '../db/DbHelper';
import { uniqueStrings } from '../db/SafeJson';
import { AnchorDao } from '../db/dao/AnchorDao';
import { CostNoteDao } from '../db/dao/CostNoteDao';
import { DecisionDao } from '../db/dao/DecisionDao';
import { DecisionRecordDao } from '../db/dao/DecisionRecordDao';
import { EventDao } from '../db/dao/EventDao';
import { EvidenceItemDao } from '../db/dao/EvidenceItemDao';
import { ExperienceMaterialDao } from '../db/dao/ExperienceMaterialDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { RelationDao } from '../db/dao/RelationDao';
import { ReviewDecisionDao } from '../db/dao/ReviewDecisionDao';
import { ReviewMaterialDao } from '../db/dao/ReviewMaterialDao';
import { ReviewResultDao } from '../db/dao/ReviewResultDao';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { ReviewDraft, ReviewStats } from './ReviewDraft';
import { MaterialSourceRow, buildRows, parseMaterialIds } from './ReviewMaterialSnapshot';
import { PeriodRange, rangeFor } from './ReviewRange';
import {
  ReviewDetailView,
  ReviewHistoryItem,
  toReviewDetailView,
  toReviewHistoryItem
} from './ReviewHistory';

/** Decision summary offered when a session picks what it cites. */
export interface RecentDecisionItem {
  id: string;
  title: string;
  choice: string;
}

/** A decision one saved review cited; missing marks an id whose decision no longer exists. */
export interface ReviewDecisionItem {
  id: string;
  title: string;
  choice: string;
  missing: boolean;
}

/** Loads review inputs and persists completed sessions. */
export class ReviewService {
  private store: relationalStore.RdbStore;
  private eventDao: EventDao;
  private decisionDao: DecisionDao;
  private predictionDao: PredictionDao;
  private anchorDao: AnchorDao;
  private reviewDao: ReviewResultDao;
  private reviewMaterialDao: ReviewMaterialDao;
  private reviewDecisionDao: ReviewDecisionDao;
  private decisionRecordDao: DecisionRecordDao;
  private experienceMaterialDao: ExperienceMaterialDao;
  private evidenceItemDao: EvidenceItemDao;
  private costNoteDao: CostNoteDao;
  private statusDao: StatusRecordDao;
  private relationDao: RelationDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.predictionDao = new PredictionDao(store);
    this.anchorDao = new AnchorDao(store);
    this.reviewDao = new ReviewResultDao(store);
    this.reviewMaterialDao = new ReviewMaterialDao(store);
    this.reviewDecisionDao = new ReviewDecisionDao(store);
    this.decisionRecordDao = new DecisionRecordDao(store);
    this.experienceMaterialDao = new ExperienceMaterialDao(store);
    this.evidenceItemDao = new EvidenceItemDao(store);
    this.costNoteDao = new CostNoteDao(store);
    this.statusDao = new StatusRecordDao(store);
    this.relationDao = new RelationDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<ReviewService> {
    const store = await DbHelper.init(context);
    return new ReviewService(store);
  }

  /** Returns the counts for the week or month containing now. */
  async loadStats(period: ReviewPeriod): Promise<ReviewStats> {
    return this.loadStatsFor(period, Date.now());
  }

  /** Returns the counts for the period containing the given anchor time. */
  async loadStatsFor(period: ReviewPeriod, now: number): Promise<ReviewStats> {
    const range = rangeFor(period, now);
    const events = (await this.eventDao.queryAll()).filter(e => e.level !== SecurityLevel.SEALED);
    const decisions = (await this.decisionDao.queryAll()).filter(d => d.level !== SecurityLevel.SEALED);
    const predictions = (await this.predictionDao.queryAll()).filter(p => p.level !== SecurityLevel.SEALED);
    const anchors = (await this.anchorDao.queryAll()).filter(a => a.level !== SecurityLevel.SEALED);
    return summarize(events, decisions, predictions, anchors.length, range);
  }

  /** Returns the anchors quoted during the contradiction step. */
  async loadAnchors(limit: number = 3): Promise<Anchor[]> {
    const anchors = (await this.anchorDao.queryAll()).filter(a => a.level !== SecurityLevel.SEALED);
    return anchors.slice(0, limit);
  }

  /** Returns the newest materials a session may quote; sealed and deleted ones stay out. */
  async recentMaterials(limit: number = 50): Promise<ExperienceMaterial[]> {
    const actual = await this.experienceMaterialDao.queryRecentVisible(limit);
    const statusRows = (await this.statusDao.queryAll())
      .filter((record: StatusRecord) => record.level !== SecurityLevel.SEALED && record.deleted !== true)
      .sort((left: StatusRecord, right: StatusRecord) => right.date.localeCompare(left.date))
      .slice(0, 10)
      .map((record: StatusRecord) => toStatusMaterial(record));
    const relationRows = (await this.relationDao.queryAll())
      .filter((relation: Relation) => relation.level !== SecurityLevel.SEALED && relation.deleted !== true)
      .slice(0, 10)
      .map((relation: Relation) => toRelationMaterial(relation));
    return statusRows.concat(relationRows, actual);
  }

  /** Returns the newest unsealed decisions a session may cite, capped at limit. */
  async recentDecisions(limit: number = 20): Promise<RecentDecisionItem[]> {
    if (limit <= 0) {
      return [];
    }
    const decisions = (await this.decisionDao.queryAll())
      .filter((decision: Decision) => decision.level !== SecurityLevel.SEALED)
      .sort((left: Decision, right: Decision) => right.timestamp - left.timestamp)
      .slice(0, limit);
    return decisions.map((decision: Decision) => {
      const item: RecentDecisionItem = {
        id: decision.id,
        title: decision.title,
        choice: decision.choice
      };
      return item;
    });
  }

  /** Persists a completed session and returns its id. */
  async save(period: ReviewPeriod, draft: ReviewDraft, rangeLabel: string,
    planId: string = '', planNodeId: string = ''): Promise<string> {
    const result = createReviewResult();
    result.period = period;
    result.rangeLabel = rangeLabel;
    result.payload = draft.payload ?? emptyReviewPayload();
    const materialIds = uniqueStrings(draft.materialIds ?? []);
    const decisionIds = uniqueStrings(result.payload.decisionIds ?? []);
    result.payload.materialIds = [];
    result.payload.decisionIds = [];
    if (hasAnyZone(result.payload)) {
      // Zone content is the source of truth for new sessions; the four legacy columns mirror it
      // so history rows and Markdown export keep reading something meaningful.
      result.facts = result.payload.scene.trim();
      result.interpretation = result.payload.model.trim();
      result.contradiction = result.payload.relation.trim();
      result.action = result.payload.revision.trim();
    } else {
      result.facts = draft.facts.trim();
      result.interpretation = draft.interpretation.trim();
      result.contradiction = draft.contradiction.trim();
      result.action = draft.action.trim();
    }
    result.anchorIds = draft.anchorIds.slice();
    if (planId.length > 0) {
      result.planId = planId;
    }
    if (planNodeId.length > 0) {
      result.planNodeId = planNodeId;
    }
    const evidenceDrafts = result.payload.evidenceDrafts ?? [];
    const costDrafts = result.payload.costDrafts ?? [];
    const evidenceLevel: SecurityLevel = result.level ?? SecurityLevel.LOCAL_ONLY;
    const decisionDraft = result.payload.decisionDraft;
    const decision: DecisionRecord | null = decisionDraft === undefined ||
      decisionDraft.reason.trim().length === 0 ? null :
      ReviewService.decisionRow(result.id, result.createdAt, decisionDraft,
        decisionLevelFor(result.level));
    this.store.beginTransaction();
    try {
      await this.evidenceItemDao.deleteByTarget('review', result.id);
      await this.costNoteDao.deleteByReview(result.id);
      await this.reviewDecisionDao.deleteByReview(result.id);
      await this.decisionRecordDao.deleteByReview(result.id);
      await this.reviewDao.insert(result);
      for (const decisionId of decisionIds) {
        await this.reviewDecisionDao.insert(result.id, decisionId);
      }
      if (decision !== null) {
        await this.decisionRecordDao.insert(decision);
      }
      const sources = await this.loadMaterialSources(materialIds);
      const rows = ReviewService.withSceneZone(buildRows(result.id, result.createdAt, materialIds,
        (id: string) => sources.get(id) ?? null));
      for (const row of rows) {
        await this.reviewMaterialDao.insert(row);
      }
      for (let index = 0; index < evidenceDrafts.length; index += 1) {
        await this.evidenceItemDao.insert(ReviewService.evidenceRow(result.id, result.createdAt, index,
          evidenceDrafts[index], evidenceLevel));
      }
      for (let index = 0; index < costDrafts.length; index += 1) {
        await this.costNoteDao.insert(ReviewService.costRow(result.id, result.createdAt, index,
          costDrafts[index]));
      }
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
    return result.id;
  }

  /**
   * Returns the material snapshots one review cited, ordered by zone and citation time. A review
   * saved before snapshots existed resolves its payload ids against the live materials, so history
   * still shows what the session quoted without writing those rows.
   */
  async materials(reviewId: string): Promise<ReviewMaterial[]> {
    const snapshots = await this.reviewMaterialDao.queryByReview(reviewId);
    if (snapshots.length > 0) {
      return snapshots;
    }
    const review = await this.reviewDao.queryById(reviewId);
    if (review === null) {
      return [];
    }
    const ids = parseMaterialIds(review.payload);
    if (ids.length === 0) {
      return [];
    }
    const sources = await this.loadMaterialSources(ids);
    const rows = ReviewService.withSceneZone(buildRows(reviewId, review.createdAt, ids,
      (id: string) => sources.get(id) ?? null));
    return orderSnapshots(rows);
  }

  /** Returns the costs one review charged, oldest first. */
  async costs(reviewId: string): Promise<CostNote[]> {
    return this.costNoteDao.queryByReview(reviewId);
  }

  /**
   * Returns the decisions one review cited, in citation order. A review saved before the link table
   * existed resolves its payload ids directly, so history keeps reading without writing new rows.
   */
  async decisions(reviewId: string): Promise<string[]> {
    const cited = await this.reviewDecisionDao.queryByReview(reviewId);
    if (cited.length > 0) {
      return cited;
    }
    const review = await this.reviewDao.queryById(reviewId);
    if (review === null) {
      return [];
    }
    const payload = review.payload;
    if (payload === undefined || payload.decisionIds === undefined) {
      return [];
    }
    return uniqueStrings(payload.decisionIds);
  }

  /** Resolves the decisions one review cited; an id whose decision is gone reads back as missing. */
  async reviewDecisions(reviewId: string): Promise<ReviewDecisionItem[]> {
    const ids = await this.decisions(reviewId);
    const decisions = await this.decisionDao.queryAll();
    const byId = new Map<string, Decision>();
    for (const decision of decisions) {
      byId.set(decision.id, decision);
    }
    const result: ReviewDecisionItem[] = [];
    for (const id of ids) {
      const found = byId.get(id);
      if (found === undefined) {
        const gap: ReviewDecisionItem = { id: id, title: '', choice: '', missing: true };
        result.push(gap);
      } else {
        const item: ReviewDecisionItem = {
          id: id,
          title: found.title,
          choice: found.choice,
          missing: false
        };
        result.push(item);
      }
    }
    return result;
  }

  /** Returns the main decision one review recorded, or null when it has none. */
  async reviewDecision(reviewId: string): Promise<DecisionRecord | null> {
    const records = await this.decisionRecordDao.queryByReview(reviewId);
    return records.length > 0 ? records[0] : null;
  }

  /** Returns saved sessions, newest first. */
  async history(limit: number = 20): Promise<ReviewHistoryItem[]> {
    const results = await this.reviewDao.queryRecent(limit);
    return results.map((result) => toReviewHistoryItem(result));
  }

  /** Returns the saved sessions that cited one decision, newest first. */
  async historyByDecision(decisionId: string): Promise<ReviewHistoryItem[]> {
    if (decisionId.length === 0) {
      return [];
    }
    const citedIds = await this.reviewDecisionDao.queryByDecision(decisionId);
    if (citedIds.length === 0) {
      return [];
    }
    const items = await this.history();
    return items.filter((item: ReviewHistoryItem) => citedIds.indexOf(item.id) >= 0);
  }

  /** Returns one saved session with its anchors resolved, or null when missing. */
  async find(id: string): Promise<ReviewDetailView | null> {
    const result = await this.reviewDao.queryById(id);
    if (result === null) {
      return null;
    }
    return toReviewDetailView(result, await this.anchorDao.queryAll());
  }

  /** Reads the cited materials into a lookup; a missing id stays absent so its row reads missing. */
  private async loadMaterialSources(ids: string[]): Promise<Map<string, MaterialSourceRow>> {
    const sources = new Map<string, MaterialSourceRow>();
    for (const id of ids) {
      if (id.startsWith('status:')) {
        const records = await this.statusDao.queryAll();
        const record = records.find((item: StatusRecord) => item.id === id.substring(7));
        if (record !== undefined) {
          sources.set(id, {
            id: id,
            text: statusText(record),
            source: 'direct',
            level: record.level ?? SecurityLevel.LOCAL_ONLY,
            deleted: record.deleted === true,
            kind: 'body'
          });
        }
        continue;
      }
      if (id.startsWith('relation:')) {
        const relation = await this.relationDao.queryById(id.substring(9));
        if (relation !== null) {
          sources.set(id, {
            id: id,
            text: relationText(relation),
            source: 'interaction',
            level: relation.level,
            deleted: relation.deleted === true,
            kind: 'unclassified'
          });
        }
        continue;
      }
      const material = await this.experienceMaterialDao.queryById(id);
      if (material === null) {
        continue;
      }
      sources.set(id, {
        id: material.id,
        text: material.text,
        source: material.source,
        level: material.level,
        deleted: material.deleted,
        kind: material.kind
      });
    }
    return sources;
  }

  /** Cited materials belong to the review's scene zone; buildRows leaves the zone unassigned. */
  private static withSceneZone(rows: ReviewMaterial[]): ReviewMaterial[] {
    for (const row of rows) {
      row.zone = REVIEW_ZONE.SCENE;
    }
    return rows;
  }

  /** Builds one evidence row for a review; index keeps the session order readable. */
  private static evidenceRow(reviewId: string, createdAt: number, index: number,
    draft: EvidenceDraft, level: SecurityLevel): EvidenceItem {
    return {
      id: `${reviewId}_evidence_${index}`,
      targetType: 'review',
      targetId: reviewId,
      sourceType: draft.sourceType,
      note: draft.note,
      effect: draft.effect,
      level: level,
      zone: REVIEW_ZONE.EVIDENCE,
      createdAt: createdAt + index
    };
  }

  /** Builds one cost row for a review; index keeps the session order readable. */
  private static costRow(reviewId: string, createdAt: number, index: number, draft: CostDraft): CostNote {
    return {
      id: `${reviewId}_cost_${index}`,
      reviewId: reviewId,
      dimension: draft.dimension,
      text: draft.text,
      bearable: draft.bearable,
      createdAt: createdAt + index
    };
  }

  /** Builds the single main decision row a review records. */
  private static decisionRow(reviewId: string, createdAt: number, draft: DecisionDraft,
    level: SecurityLevel): DecisionRecord {
    return {
      id: `${reviewId}_decision`,
      reviewId: reviewId,
      type: draft.type,
      reason: draft.reason.trim(),
      action: (draft.action ?? '').trim(),
      commitment: (draft.commitment ?? '').trim(),
      relationId: draft.relationId ?? '',
      planItemId: draft.planItemId ?? '',
      outcome: (draft.outcome ?? '').trim(),
      reviewAt: (draft.reviewAt ?? '').trim(),
      level: level,
      createdAt: createdAt
    };
  }
}

/** Narrows a decision to LOCAL_ONLY or stricter, following the review it belongs to. */
export function decisionLevelFor(reviewLevel: SecurityLevel | undefined): SecurityLevel {
  return reviewLevel === SecurityLevel.SEALED ? SecurityLevel.SEALED : SecurityLevel.LOCAL_ONLY;
}

/** Orders snapshots the way the table reads them back: zone, citation time, material id. */
function orderSnapshots(rows: ReviewMaterial[]): ReviewMaterial[] {
  const ordered = rows.slice();
  ordered.sort((left: ReviewMaterial, right: ReviewMaterial) => {
    if (left.zone !== right.zone) {
      return left.zone - right.zone;
    }
    if (left.citedAt !== right.citedAt) {
      return left.citedAt - right.citedAt;
    }
    if (left.materialId === right.materialId) {
      return 0;
    }
    return left.materialId < right.materialId ? -1 : 1;
  });
  return ordered;
}

function summarize(events: Event[], decisions: Decision[], predictions: Prediction[],
  anchorCount: number, range: PeriodRange): ReviewStats {
  const counts: ReviewWindowCounts = countReviewWindow(events, decisions, predictions, range.start, range.end);
  return {
    rangeLabel: range.label,
    noteCount: counts.noteCount,
    decisionCount: counts.decisionCount,
    pendingPredictions: counts.pendingPredictions,
    settledPredictions: counts.settledPredictions,
    hitRate: counts.hitRate,
    anchorCount: anchorCount
  };
}

/** One status record as citable text; it keeps whatever the author actually filled in. */
function statusText(record: StatusRecord): string {
  const parts: string[] = [];
  if ((record.functionState ?? '').trim().length > 0) {
    parts.push(record.functionState as string);
  }
  if ((record.bodySignals ?? '').trim().length > 0) {
    parts.push(record.bodySignals as string);
  }
  if (record.note.trim().length > 0) {
    parts.push(record.note);
  }
  if ((record.costPaid ?? '').trim().length > 0) {
    parts.push(`代价：${record.costPaid as string}`);
  }
  return parts.length > 0 ? parts.join('；') : record.date;
}

/** The latest interaction of a relation, or its correction when no entry exists. */
function relationText(relation: Relation): string {
  if (relation.interactionLog.length > 0) {
    const latest = relation.interactionLog[relation.interactionLog.length - 1];
    if (latest.content.trim().length > 0) {
      return latest.content;
    }
  }
  if ((relation.correction ?? '').trim().length > 0) {
    return relation.correction as string;
  }
  return relation.notes;
}

function interactionSourceOf(relation: Relation): MaterialInteractionSource {
  if (relation.interactionLog.length === 0) {
    return 'observed';
  }
  const latest = relation.interactionLog[relation.interactionLog.length - 1];
  if (latest.source === 'stated') {
    return 'stated';
  }
  if (latest.source === 'joint') {
    return 'shared_activity';
  }
  if (latest.source === 'inference') {
    return 'inferred';
  }
  return 'observed';
}

function toStatusMaterial(record: StatusRecord): ExperienceMaterial {
  return {
    id: `status:${record.id}`,
    eventId: '',
    kind: 'body',
    form: '',
    text: statusText(record),
    observedAt: 0,
    source: 'direct',
    sourceStance: '',
    level: record.level ?? SecurityLevel.LOCAL_ONLY,
    revisionOf: '',
    deleted: record.deleted === true,
    createdAt: 0
  };
}

function toRelationMaterial(relation: Relation): ExperienceMaterial {
  const observedAt = relation.interactionLog.length > 0
    ? relation.interactionLog[relation.interactionLog.length - 1].timestamp : 0;
  return {
    id: `relation:${relation.id}`,
    eventId: '',
    kind: 'unclassified',
    form: 'dialogue',
    text: relationText(relation),
    observedAt: observedAt,
    source: 'interaction',
    sourceStance: '',
    interactionSource: interactionSourceOf(relation),
    level: relation.level,
    revisionOf: '',
    deleted: relation.deleted === true,
    createdAt: observedAt
  };
}
