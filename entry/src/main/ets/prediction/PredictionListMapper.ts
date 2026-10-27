import { Prediction } from '../model/Prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { PredictionListItem, PredictionSummary } from './PredictionListItem';

/** Converts one prediction into a list row. */
export function toPredictionListItem(prediction: Prediction): PredictionListItem {
  return {
    id: prediction.id,
    target: prediction.target,
    judgment: prediction.judgment,
    confidence: prediction.confidence,
    settlementDate: prediction.settlementDate,
    status: prediction.status,
    hit: prediction.hit,
    actualResult: prediction.actualResult,
    createdAt: prediction.createdAt
  };
}

/** Pending rows come first by due date; settled rows follow, newest first. */
export function toPredictionListItems(predictions: Prediction[]): PredictionListItem[] {
  const items: PredictionListItem[] = [];
  for (const prediction of predictions) {
    items.push(toPredictionListItem(prediction));
  }
  items.sort((left: PredictionListItem, right: PredictionListItem) => compareRows(left, right));
  return items;
}

/** Counts pending and settled rows plus the hit rate over settled rows. */
export function summarizePredictions(predictions: Prediction[]): PredictionSummary {
  let pending = 0;
  let hits = 0;
  for (const prediction of predictions) {
    if (prediction.status === PredictionStatus.PENDING) {
      pending += 1;
    } else if (prediction.hit === true) {
      hits += 1;
    }
  }
  const settled = predictions.length - pending;
  const hitRate = settled > 0 ? Math.round(hits / settled * 100) : 0;
  return { total: predictions.length, pending: pending, settled: settled, hits: hits, hitRate: hitRate };
}

/** Tag text shown on a prediction card. */
export function predictionStatusLabel(item: PredictionListItem): string {
  if (item.status === PredictionStatus.PENDING) {
    return '待结算';
  }
  return item.hit === true ? '命中' : '未命中';
}

function compareRows(left: PredictionListItem, right: PredictionListItem): number {
  const leftPending = left.status === PredictionStatus.PENDING;
  const rightPending = right.status === PredictionStatus.PENDING;
  if (leftPending !== rightPending) {
    return leftPending ? -1 : 1;
  }
  if (leftPending) {
    if (left.settlementDate === right.settlementDate) {
      return left.createdAt - right.createdAt;
    }
    return left.settlementDate < right.settlementDate ? -1 : 1;
  }
  return right.createdAt - left.createdAt;
}
