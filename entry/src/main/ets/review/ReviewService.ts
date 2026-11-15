import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Anchor } from '../model/Anchor';
import { CostDraft, CostNote } from '../model/CostNote';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { EvidenceDraft, EvidenceItem } from '../model/EvidenceItem';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { createReviewResult } from '../model/factories';
import { Prediction } from '../model/Prediction';
import { ReviewMaterial, REVIEW_ZONE } from '../model/ReviewMaterial';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { emptyReviewPayload, hasAnyZone } from '../model/ReviewPayload';
import { SecurityLevel } from '../model/SecurityLevel';
import { countReviewWindow, ReviewWindowCounts } from '../analysis/metrics/ReviewMetrics';
import { DbHelper } from '../db/DbHelper';
import { AnchorDao } from '../db/dao/AnchorDao';
import { CostNoteDao } from '../db/dao/CostNoteDao';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { EvidenceItemDao } from '../db/dao/EvidenceItemDao';
import { ExperienceMaterialDao } from '../db/dao/ExperienceMaterialDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { ReviewMaterialDao } from '../db/dao/ReviewMaterialDao';
import { ReviewResultDao } from '../db/dao/ReviewResultDao';
import { ReviewDraft, ReviewStats } from './ReviewDraft';
import { MaterialSourceRow, buildRows, parseMaterialIds } from './ReviewMaterialSnapshot';
import { PeriodRange, rangeFor } from './ReviewRange';
import {
  ReviewDetailView,
  ReviewHistoryItem,
  toReviewDetailView,
  toReviewHistoryItem
} from './ReviewHistory';

/** Loads review inputs and persists completed sessions. */
export class ReviewService {
  private store: relationalStore.RdbStore;
  private eventDao: EventDao;
  private decisionDao: DecisionDao;
  private predictionDao: PredictionDao;
  private anchorDao: AnchorDao;
  private reviewDao: ReviewResultDao;
  private reviewMaterialDao: ReviewMaterialDao;
  private experienceMaterialDao: ExperienceMaterialDao;
  private evidenceItemDao: EvidenceItemDao;
  private costNoteDao: CostNoteDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.predictionDao = new PredictionDao(store);
    this.anchorDao = new AnchorDao(store);
    this.reviewDao = new ReviewResultDao(store);
    this.reviewMaterialDao = new ReviewMaterialDao(store);
    this.experienceMaterialDao = new ExperienceMaterialDao(store);
    this.evidenceItemDao = new EvidenceItemDao(store);
    this.costNoteDao = new CostNoteDao(store);
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
    return this.experienceMaterialDao.queryRecentVisible(limit);
  }

  /** Persists a completed session and returns its id. */
  async save(period: ReviewPeriod, draft: ReviewDraft, rangeLabel: string,
    planId: string = '', planNodeId: string = ''): Promise<string> {
    const result = createReviewResult();
    result.period = period;
    result.rangeLabel = rangeLabel;
    result.payload = draft.payload ?? emptyReviewPayload();
    // Quoted materials ride with the payload so history and export can resolve them later.
    result.payload.materialIds = (draft.materialIds ?? []).slice();
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
    const citedIds = (draft.materialIds ?? []).slice();
    const evidenceDrafts = result.payload.evidenceDrafts ?? [];
    const costDrafts = result.payload.costDrafts ?? [];
    const evidenceLevel: SecurityLevel = result.level ?? SecurityLevel.LOCAL_ONLY;
    this.store.beginTransaction();
    try {
      await this.evidenceItemDao.deleteByTarget('review', result.id);
      await this.costNoteDao.deleteByReview(result.id);
      await this.reviewDao.insert(result);
      const sources = await this.loadMaterialSources(citedIds);
      const rows = ReviewService.withSceneZone(buildRows(result.id, result.createdAt, citedIds,
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

  /** Returns saved sessions, newest first. */
  async history(limit: number = 20): Promise<ReviewHistoryItem[]> {
    const results = await this.reviewDao.queryRecent(limit);
    return results.map((result) => toReviewHistoryItem(result));
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
