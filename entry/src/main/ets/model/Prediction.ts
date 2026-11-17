import { PredictionOutcome } from './PredictionOutcome';
import { PredictionStatus } from './PredictionStatus';
import { SecurityLevel } from './SecurityLevel';

/** A prediction committed before the outcome; immutable once submitted, settled on the due date. */
export interface Prediction {
  id: string;
  /** Predicted subject / proposition */
  target: string;
  /** Judgment with number and deadline */
  judgment: string;
  /** Confidence 0-100; null means the user cannot quantify it */
  confidence: number | null;
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
  /** Id of the first version; all revisions share it so the latest can be resolved */
  rootId?: string;
  /** Settlement result; empty for records settled before outcomes existed */
  outcome?: PredictionOutcome;
  /** Where the model applies and what would falsify it */
  scope?: string;
  falsification?: string;
  unknowns?: string;
  /** Why this version was written, and what it cancels, keeps and repositions */
  revisionReason?: string;
  invalidated?: string;
  preserved?: string;
  repositioned?: string;
  /** Evidence source recorded beside the actual result */
  evidenceLevel?: string;
  /** Determinate negation: which relation, variable, body condition or response was missed */
  missing?: string;
  /** Determinate negation: what the new frame explains that the old one could not */
  explanatoryGain?: string;
  /** Security level controlling aggregation and export; absent values are local-only */
  level?: SecurityLevel;
  /** Commit timestamp in milliseconds */
  createdAt: number;
}
