import { PredictionStatus } from '../model/PredictionStatus';
import { PredictionOutcome } from '../model/PredictionOutcome';

/** Row model rendered by the prediction list. */
export interface PredictionListItem {
  id: string;
  target: string;
  judgment: string;
  /** Null means the user could not quantify it */
  confidence: number | null;
  /** Due date in YYYY-MM-DD */
  settlementDate: string;
  status: PredictionStatus;
  hit: boolean | null;
  /** Settlement result; empty for records settled before outcomes existed */
  outcome?: PredictionOutcome;
  actualResult: string;
  createdAt: number;
}

/** Counts shown above the prediction list. */
export interface PredictionSummary {
  total: number;
  pending: number;
  /** Settled rows with a binary result; the hit rate denominator */
  settled: number;
  /** Settled rows with partial, insufficient or undecidable results, shown apart */
  nonBinarySettled?: number;
  hits: number;
  hitRate: number;
}

/** Read-only projection for the prediction detail page. */
export interface PredictionDetail {
  id: string;
  target: string;
  judgment: string;
  /** Null means the user could not quantify it */
  confidence: number | null;
  reason: string;
  settlementDate: string;
  status: PredictionStatus;
  actualResult: string;
  hit: boolean | null;
  version: number;
  createdAtLabel: string;
  /** Settlement result; empty for records settled before outcomes existed */
  outcome?: PredictionOutcome;
  /** Evidence source recorded beside the result */
  evidenceLevel?: string;
  /** Model card: where the prediction applies and what would falsify it */
  scope?: string;
  falsification?: string;
  unknowns?: string;
  /** Why this version was written, and what it cancels, keeps and repositions */
  revisionReason?: string;
  invalidated?: string;
  preserved?: string;
  repositioned?: string;
  missing?: string;
  explanatoryGain?: string;
}
