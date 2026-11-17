import { Prediction } from '../model/Prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { isBinaryOutcome, isNonBinaryOutcome, outcomeFromLegacy, outcomeLabel, PredictionOutcome } from '../model/PredictionOutcome';
import { hitRatePercent } from '../analysis/metrics/Rates';
import { formatDateTime } from '../analysis/time/DateTime';
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
    outcome: prediction.outcome ?? '',
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

/** Counts pending and settled rows; the hit rate covers binary settled rows only. */
export function summarizePredictions(predictions: Prediction[]): PredictionSummary {
  let pending = 0;
  let hits = 0;
  let binarySettled = 0;
  let nonBinarySettled = 0;
  let total = 0;
  for (const prediction of predictions) {
    if (prediction.level === SecurityLevel.SEALED) {
      continue;
    }
    total += 1;
    if (prediction.status === PredictionStatus.PENDING) {
      pending += 1;
      continue;
    }
    const outcome = effectiveOutcome(prediction.outcome ?? '', prediction.hit);
    if (isBinaryOutcome(outcome)) {
      binarySettled += 1;
      if (outcome === 'hold') {
        hits += 1;
      }
    } else if (isNonBinaryOutcome(outcome)) {
      nonBinarySettled += 1;
    }
  }
  const hitRate = hitRatePercent(hits, binarySettled);
  return {
    total: total,
    pending: pending,
    settled: binarySettled,
    nonBinarySettled: nonBinarySettled,
    hits: hits,
    hitRate: hitRate
  };
}

/** Tag text shown on a prediction card; records without an outcome fall back to the hit flag. */
export function predictionStatusLabel(item: PredictionListItem): string {
  return predictionStatusText(item.status, effectiveOutcome(item.outcome ?? '', item.hit));
}

/** Tag text for a status and settlement outcome pair, shared by the list and the detail page. */
export function predictionStatusText(status: PredictionStatus, outcome: PredictionOutcome): string {
  if (status === PredictionStatus.PENDING) {
    return '待结算';
  }
  return outcomeLabel(outcome);
}

/** Text for the settlement result, covering all five outcomes. */
export function predictionHitText(outcome: PredictionOutcome): string {
  return outcomeLabel(outcome);
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
    createdAtLabel: formatDateTime(prediction.createdAt),
    outcome: prediction.outcome ?? '',
    evidenceLevel: prediction.evidenceLevel ?? '',
    scope: prediction.scope ?? '',
    falsification: prediction.falsification ?? '',
    unknowns: prediction.unknowns ?? '',
    revisionReason: prediction.revisionReason ?? '',
    invalidated: prediction.invalidated ?? '',
    preserved: prediction.preserved ?? '',
    repositioned: prediction.repositioned ?? '',
    missing: prediction.missing ?? '',
    explanatoryGain: prediction.explanatoryGain ?? '',
    termOnly: prediction.version > 1 && (prediction.explanatoryGain ?? '').trim().length === 0
  };
}

/** Stored outcome, or the hit flag for records settled before outcomes existed. */
function effectiveOutcome(outcome: PredictionOutcome, hit: boolean | null): PredictionOutcome {
  return outcome.length > 0 ? outcome : outcomeFromLegacy(hit);
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
