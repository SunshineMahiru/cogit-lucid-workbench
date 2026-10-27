import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Anchor } from '../model/Anchor';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { createReviewResult } from '../model/factories';
import { Prediction } from '../model/Prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { DbHelper } from '../db/DbHelper';
import { AnchorDao } from '../db/dao/AnchorDao';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { ReviewResultDao } from '../db/dao/ReviewResultDao';
import { ReviewDraft, ReviewStats } from './ReviewDraft';
import { PeriodRange, rangeFor } from './ReviewRange';

/** Loads review inputs and persists completed sessions. */
export class ReviewService {
  private eventDao: EventDao;
  private decisionDao: DecisionDao;
  private predictionDao: PredictionDao;
  private anchorDao: AnchorDao;
  private reviewDao: ReviewResultDao;

  private constructor(store: relationalStore.RdbStore) {
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.predictionDao = new PredictionDao(store);
    this.anchorDao = new AnchorDao(store);
    this.reviewDao = new ReviewResultDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<ReviewService> {
    const store = await DbHelper.init(context);
    return new ReviewService(store);
  }

  /** Returns the counts for the week or month containing now. */
  async loadStats(period: ReviewPeriod): Promise<ReviewStats> {
    const range = rangeFor(period, Date.now());
    const events = await this.eventDao.queryAll();
    const decisions = await this.decisionDao.queryAll();
    const predictions = await this.predictionDao.queryAll();
    const anchors = await this.anchorDao.queryAll();
    return summarize(events, decisions, predictions, anchors.length, range);
  }

  /** Returns the anchors quoted during the contradiction step. */
  async loadAnchors(limit: number = 3): Promise<Anchor[]> {
    const anchors = await this.anchorDao.queryAll();
    return anchors.slice(0, limit);
  }

  /** Persists a completed session and returns its id. */
  async save(period: ReviewPeriod, draft: ReviewDraft, rangeLabel: string): Promise<string> {
    const result = createReviewResult();
    result.period = period;
    result.rangeLabel = rangeLabel;
    result.facts = draft.facts.trim();
    result.interpretation = draft.interpretation.trim();
    result.contradiction = draft.contradiction.trim();
    result.action = draft.action.trim();
    result.anchorIds = draft.anchorIds.slice();
    await this.reviewDao.insert(result);
    return result.id;
  }
}

function summarize(events: Event[], decisions: Decision[], predictions: Prediction[],
  anchorCount: number, range: PeriodRange): ReviewStats {
  let noteCount = 0;
  for (const event of events) {
    if (event.timestamp >= range.start && event.timestamp < range.end) {
      noteCount += 1;
    }
  }
  let decisionCount = 0;
  for (const decision of decisions) {
    if (decision.timestamp >= range.start && decision.timestamp < range.end) {
      decisionCount += 1;
    }
  }
  let pending = 0;
  let settled = 0;
  let hits = 0;
  for (const prediction of predictions) {
    if (prediction.status === PredictionStatus.PENDING) {
      pending += 1;
    } else if (prediction.createdAt >= range.start && prediction.createdAt < range.end) {
      settled += 1;
      if (prediction.hit === true) {
        hits += 1;
      }
    }
  }
  const hitRate = settled > 0 ? Math.round(hits / settled * 100) : 0;
  return {
    rangeLabel: range.label,
    noteCount: noteCount,
    decisionCount: decisionCount,
    pendingPredictions: pending,
    settledPredictions: settled,
    hitRate: hitRate,
    anchorCount: anchorCount
  };
}
