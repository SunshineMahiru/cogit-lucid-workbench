import { Prediction } from '../model/Prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { CalibrationReport, PredictionOutcome } from '../analysis/calibration/CalibrationAnalyzer';
import { ThresholdCalibrationAnalyzer } from '../analysis/calibration/ThresholdCalibrationAnalyzer';

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
  /** Months with at least one settled prediction, oldest first, capped by monthLimit */
  months: PredictionMonthPoint[];
  /** Confidence calibration over the same settled sample */
  calibration: CalibrationReport;
}

interface MonthAccumulator {
  month: string;
  settled: number;
  hits: number;
}

/** Builds the chart payload from settled predictions only. */
export function buildPredictionStats(predictions: Prediction[], monthLimit: number = 6): PredictionStats {
  const buckets: Map<string, MonthAccumulator> = new Map<string, MonthAccumulator>();
  let settled = 0;
  let hits = 0;
  const outcomes: PredictionOutcome[] = [];
  for (const prediction of predictions) {
    if (prediction.status !== PredictionStatus.SETTLED || prediction.level === SecurityLevel.SEALED) {
      continue;
    }
    settled += 1;
    if (prediction.hit === true) {
      hits += 1;
    }
    outcomes.push({ confidence: prediction.confidence, hit: prediction.hit === true });
    const month = prediction.settlementDate.length >= 7 ?
      prediction.settlementDate.slice(0, 7) : '未知';
    let bucket = buckets.get(month);
    if (bucket === undefined) {
      bucket = { month: month, settled: 0, hits: 0 };
      buckets.set(month, bucket);
    }
    bucket.settled += 1;
    if (prediction.hit === true) {
      bucket.hits += 1;
    }
  }

  const months: PredictionMonthPoint[] = [];
  for (const bucket of buckets.values()) {
    months.push({
      month: bucket.month,
      label: monthLabel(bucket.month),
      settled: bucket.settled,
      hits: bucket.hits,
      hitRate: Math.round(bucket.hits / bucket.settled * 100)
    });
  }
  months.sort((left: PredictionMonthPoint, right: PredictionMonthPoint) =>
    left.month < right.month ? -1 : (left.month > right.month ? 1 : 0));
  const limited = months.length > monthLimit ? months.slice(months.length - monthLimit) : months;
  const calibration = new ThresholdCalibrationAnalyzer().analyze(outcomes, { now: Date.now() });

  return {
    settled: settled,
    hits: hits,
    misses: settled - hits,
    hitRate: settled > 0 ? Math.round(hits / settled * 100) : 0,
    months: limited,
    calibration: calibration
  };
}

function monthLabel(month: string): string {
  const parts = month.split('-');
  if (parts.length >= 2) {
    return `${Number(parts[1])}月`;
  }
  return month;
}
