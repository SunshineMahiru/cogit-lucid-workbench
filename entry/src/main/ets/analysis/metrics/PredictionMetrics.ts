import { CalibrationAnalyzer, CalibrationReport, PredictionOutcome } from '../calibration/CalibrationAnalyzer';
import { ThresholdCalibrationAnalyzer } from '../calibration/ThresholdCalibrationAnalyzer';
import { hitRatePercent } from './Rates';

/** One settled prediction handed to the aggregator. */
export interface SettledSample {
  /** Declared confidence, 0-100 */
  confidence: number;
  hit: boolean;
  /** YYYY-MM, or a caller-provided key such as 未知 */
  month: string;
}

/** Aggregated accuracy for one month. */
export interface MonthlyHitRate {
  month: string;
  settled: number;
  hits: number;
  hitRate: number;
}

/** Prediction accuracy over the settled sample. */
export interface PredictionMetrics {
  settled: number;
  hits: number;
  misses: number;
  /** 0-100, rounded */
  hitRate: number;
  /** Months with at least one settled prediction, oldest first, capped by monthLimit */
  months: MonthlyHitRate[];
  /** Confidence calibration over the same settled sample */
  calibration: CalibrationReport;
}

interface MonthAccumulator {
  month: string;
  settled: number;
  hits: number;
}

/** Aggregates settled samples in one pass; the caller filters pending and sealed rows. */
export function buildPredictionMetrics(samples: SettledSample[], monthLimit: number,
  analyzer: CalibrationAnalyzer = new ThresholdCalibrationAnalyzer()): PredictionMetrics {
  const buckets: Map<string, MonthAccumulator> = new Map<string, MonthAccumulator>();
  const outcomes: PredictionOutcome[] = [];
  let settled = 0;
  let hits = 0;
  for (const sample of samples) {
    settled += 1;
    if (sample.hit) {
      hits += 1;
    }
    outcomes.push({ confidence: sample.confidence, hit: sample.hit });
    let bucket = buckets.get(sample.month);
    if (bucket === undefined) {
      bucket = { month: sample.month, settled: 0, hits: 0 };
      buckets.set(sample.month, bucket);
    }
    bucket.settled += 1;
    if (sample.hit) {
      bucket.hits += 1;
    }
  }

  const months: MonthlyHitRate[] = [];
  for (const bucket of buckets.values()) {
    months.push({
      month: bucket.month,
      settled: bucket.settled,
      hits: bucket.hits,
      hitRate: hitRatePercent(bucket.hits, bucket.settled)
    });
  }
  months.sort((left: MonthlyHitRate, right: MonthlyHitRate) =>
    left.month < right.month ? -1 : (left.month > right.month ? 1 : 0));
  const limited = months.length > monthLimit ? months.slice(months.length - monthLimit) : months;

  return {
    settled: settled,
    hits: hits,
    misses: settled - hits,
    hitRate: hitRatePercent(hits, settled),
    months: limited,
    calibration: analyzer.analyze(outcomes, { now: Date.now() })
  };
}