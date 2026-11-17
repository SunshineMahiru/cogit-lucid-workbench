import { Prediction } from '../model/Prediction';
import { isBinaryOutcome, outcomeFromLegacy } from '../model/PredictionOutcome';
import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { CalibrationReport } from '../analysis/calibration/CalibrationAnalyzer';
import { buildPredictionMetrics, SettledSample } from '../analysis/metrics/PredictionMetrics';

/** One month of settled predictions. */
export interface PredictionMonthPoint {
  /** YYYY-MM */
  month: string;
  /** Short axis label such as 10月 */
  label: string;
  settled: number;
  hits: number;
  hitRate: number;
}

/** Aggregate used by the statistics page. */
export interface PredictionStats {
  settled: number;
  hits: number;
  misses: number;
  /** 0-100, rounded */
  hitRate: number;
  /** Counts per outcome; the three non-binary ones never enter hitRate */
  outcomes: OutcomeCounts;
  /** Months with at least one settled prediction, oldest first, capped by monthLimit */
  months: PredictionMonthPoint[];
  /** Confidence calibration over the same settled sample */
  calibration: CalibrationReport;
  /** Settled rows dropped because the outcome and the hit flag disagree */
  excluded?: number;
}

/** One counter per outcome value. */
export interface OutcomeCounts {
  hold: number;
  fail: number;
  partial: number;
  insufficient: number;
  undecidable: number;
}

/** Builds the chart payload from settled predictions only. */
export function buildPredictionStats(predictions: Prediction[], monthLimit: number = 6): PredictionStats {
  const samples: SettledSample[] = [];
  const outcomes: OutcomeCounts = { hold: 0, fail: 0, partial: 0, insufficient: 0, undecidable: 0 };
  let settledTotal = 0;
  let excluded = 0;
  for (const prediction of predictions) {
    if (prediction.status !== PredictionStatus.SETTLED || prediction.level === SecurityLevel.SEALED) {
      continue;
    }
    settledTotal += 1;
    const stored = prediction.outcome ?? '';
    const outcome = stored.length > 0 ? stored : outcomeFromLegacy(prediction.hit);
    // A binary outcome needs the matching hit flag; a non-binary one must leave it empty.
    const consistent = isBinaryOutcome(outcome) ?
      prediction.hit === (outcome === 'hold') : prediction.hit === null;
    if (!consistent) {
      excluded += 1;
      continue;
    }
    if (outcome === 'hold' || outcome === 'fail' || outcome === 'partial' ||
      outcome === 'insufficient' || outcome === 'undecidable') {
      outcomes[outcome] += 1;
    }
    if (!isBinaryOutcome(outcome)) {
      continue;
    }
    const month = prediction.settlementDate.length >= 7 ?
      prediction.settlementDate.slice(0, 7) : '未知';
    samples.push({ confidence: prediction.confidence, hit: outcome === 'hold', month: month });
  }

  const metrics = buildPredictionMetrics(samples, monthLimit);
  const months: PredictionMonthPoint[] = [];
  for (const month of metrics.months) {
    months.push({
      month: month.month,
      label: monthLabel(month.month),
      settled: month.settled,
      hits: month.hits,
      hitRate: month.hitRate
    });
  }

  return {
    settled: settledTotal,
    hits: metrics.hits,
    misses: metrics.misses,
    hitRate: metrics.hitRate,
    outcomes: outcomes,
    months: months,
    calibration: metrics.calibration,
    excluded: excluded
  };
}

function monthLabel(month: string): string {
  const parts = month.split('-');
  if (parts.length >= 2) {
    return `${Number(parts[1])}月`;
  }
  return month;
}