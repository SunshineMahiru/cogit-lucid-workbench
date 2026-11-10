import { Prediction } from '../model/Prediction';
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
  /** Months with at least one settled prediction, oldest first, capped by monthLimit */
  months: PredictionMonthPoint[];
  /** Confidence calibration over the same settled sample */
  calibration: CalibrationReport;
}

/** Builds the chart payload from settled predictions only. */
export function buildPredictionStats(predictions: Prediction[], monthLimit: number = 6): PredictionStats {
  const samples: SettledSample[] = [];
  for (const prediction of predictions) {
    if (prediction.status !== PredictionStatus.SETTLED || prediction.level === SecurityLevel.SEALED) {
      continue;
    }
    const month = prediction.settlementDate.length >= 7 ?
      prediction.settlementDate.slice(0, 7) : '未知';
    samples.push({ confidence: prediction.confidence, hit: prediction.hit === true, month: month });
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
    settled: metrics.settled,
    hits: metrics.hits,
    misses: metrics.misses,
    hitRate: metrics.hitRate,
    months: months,
    calibration: metrics.calibration
  };
}

function monthLabel(month: string): string {
  const parts = month.split('-');
  if (parts.length >= 2) {
    return `${Number(parts[1])}月`;
  }
  return month;
}