import { AnalysisContext } from '../types';
import { CalibrationAnalyzer, CalibrationBucket, CalibrationReport, PredictionOutcome } from './CalibrationAnalyzer';

interface Band {
  min: number;
  max: number;
  label: string;
}

const BANDS: Band[] = [
  { min: 0, max: 49, label: '0–49%' },
  { min: 50, max: 69, label: '50–69%' },
  { min: 70, max: 84, label: '70–84%' },
  { min: 85, max: 100, label: '85–100%' }
];

/** Buckets settled predictions by stated confidence and reports a Brier score. */
export class ThresholdCalibrationAnalyzer implements CalibrationAnalyzer {
  analyze(outcomes: PredictionOutcome[], context: AnalysisContext): CalibrationReport {
    const buckets: CalibrationBucket[] = BANDS.map((band: Band) => {
      return { label: band.label, total: 0, hits: 0, hitRate: 0 };
    });
    let settled = 0;
    let hits = 0;
    let brier = 0;
    for (const outcome of outcomes) {
      const confidence = clamp(outcome.confidence, 0, 100);
      const hit = outcome.hit;
      const index = bandIndex(confidence);
      const bucket = buckets[index];
      bucket.total += 1;
      if (hit) {
        bucket.hits += 1;
        hits += 1;
      }
      brier += Math.pow(confidence / 100 - (hit ? 1 : 0), 2);
      settled += 1;
    }
    for (const bucket of buckets) {
      bucket.hitRate = bucket.total > 0 ? Math.round(bucket.hits / bucket.total * 100) : 0;
    }
    return {
      settled: settled,
      hits: hits,
      hitRate: settled > 0 ? Math.round(hits / settled * 100) : 0,
      brierScore: settled > 0 ? Math.round(brier / settled * 10000) / 10000 : 0,
      buckets: buckets
    };
  }
}

function bandIndex(confidence: number): number {
  for (let index = 0; index < BANDS.length; index += 1) {
    const band = BANDS[index];
    if (confidence >= band.min && confidence <= band.max) {
      return index;
    }
  }
  return BANDS.length - 1;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
