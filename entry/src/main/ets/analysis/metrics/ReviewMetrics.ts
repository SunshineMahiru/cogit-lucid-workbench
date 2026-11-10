import { Decision } from '../../model/Decision';
import { Event } from '../../model/Event';
import { Prediction } from '../../model/Prediction';
import { PredictionStatus } from '../../model/PredictionStatus';
import { hitRatePercent } from './Rates';

/** Counts shown for one review window. */
export interface ReviewWindowCounts {
  noteCount: number;
  decisionCount: number;
  pendingPredictions: number;
  settledPredictions: number;
  hits: number;
  hitRate: number;
}

/**
 * Counts records for the half-open window [start, end).
 * Pending predictions are counted regardless of date; settled ones only when created inside the window.
 */
export function countReviewWindow(events: Event[], decisions: Decision[], predictions: Prediction[],
  start: number, end: number): ReviewWindowCounts {
  let noteCount = 0;
  for (const event of events) {
    if (event.timestamp >= start && event.timestamp < end) {
      noteCount += 1;
    }
  }
  let decisionCount = 0;
  for (const decision of decisions) {
    if (decision.timestamp >= start && decision.timestamp < end) {
      decisionCount += 1;
    }
  }
  let pending = 0;
  let settled = 0;
  let hits = 0;
  for (const prediction of predictions) {
    if (prediction.status === PredictionStatus.PENDING) {
      pending += 1;
    } else if (prediction.createdAt >= start && prediction.createdAt < end) {
      settled += 1;
      if (prediction.hit === true) {
        hits += 1;
      }
    }
  }
  return {
    noteCount: noteCount,
    decisionCount: decisionCount,
    pendingPredictions: pending,
    settledPredictions: settled,
    hits: hits,
    hitRate: hitRatePercent(hits, settled)
  };
}