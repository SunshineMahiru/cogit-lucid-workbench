import { AnalysisContext } from '../types';

/** One settled prediction used for calibration. */
export interface PredictionOutcome {
  /** Declared confidence, 0-100 */
  confidence: number;
  hit: boolean;
}

/** Aggregated accuracy for one confidence band. */
export interface CalibrationBucket {
  label: string;
  total: number;
  hits: number;
  hitRate: number;
}

/** Calibration summary for the prediction log. */
export interface CalibrationReport {
  settled: number;
  hits: number;
  hitRate: number;
  /** Brier score over 0-1 probabilities; 0 when there is no sample */
  brierScore: number;
  buckets: CalibrationBucket[];
}

/** Contract for confidence calibration; implementation lands in 6.3. */
export interface CalibrationAnalyzer {
  analyze(outcomes: PredictionOutcome[], context: AnalysisContext): CalibrationReport;
}
