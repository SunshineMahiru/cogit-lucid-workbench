import { PredictionStatus } from './PredictionStatus';

/** A prediction committed before the outcome; immutable once submitted, settled on the due date. */
export interface Prediction {
  id: string;
  /** Predicted subject / proposition */
  target: string;
  /** Judgment with number and deadline */
  judgment: string;
  /** Confidence 0-100 */
  confidence: number;
  /** Reason */
  reason: string;
  /** Settlement date, fixed like a contract */
  settlementDate: string;
  status: PredictionStatus;
  /** Actual outcome, filled when settling */
  actualResult: string;
  /** Hit or miss; null while pending */
  hit: boolean | null;
  /** Version: edits are append-only, not in-place */
  version: number;
  /** Commit timestamp in milliseconds */
  createdAt: number;
}
