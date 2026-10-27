import { Prediction } from '../model/Prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { PredictionDetail, PredictionListItem, PredictionSummary } from './PredictionListItem';

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
  return predictionStatusText(item.status, item.hit);
}

/** Tag text for a status and hit pair, shared by the list and the detail page. */
export function predictionStatusText(status: PredictionStatus, hit: boolean | null): string {
  if (status === PredictionStatus.PENDING) {
    return '待结算';
  }
  return hit === true ? '命中' : '未命中';
}

/** Text for the settled flag, including the not-yet-settled case. */
export function predictionHitText(hit: boolean | null): string {
  if (hit === null) {
    return '未结算';
  }
  return hit ? '命中' : '未命中';
}

/** Projects one prediction into the read-only detail model. */
export function toPredictionDetail(prediction: Prediction): PredictionDetail {
  return {
    id: prediction.id,
    target: prediction.target,
    judgment: prediction.judgment,
    confidence: prediction.confidence,
    reason: prediction.reason,
    settlementDate: prediction.settlementDate,
    status: prediction.status,
    actualResult: prediction.actualResult,
    hit: prediction.hit,
    version: prediction.version,
    createdAtLabel: formatDateTime(prediction.createdAt)
  };
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

function formatDateTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ` +
    `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
