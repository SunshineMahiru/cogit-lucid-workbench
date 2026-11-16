import { SecurityLevel } from './SecurityLevel';
import { WorkDepth } from './WorkDepth';

/** The six choices one review decision may record. */
export type DecisionRecordType = 'continue' | 'switch' | 'pause' | 'discard' | 'exit' | 'joint';

/** Every decision type in display order. */
export const DECISION_RECORD_TYPES: DecisionRecordType[] = [
  'continue',
  'switch',
  'pause',
  'discard',
  'exit',
  'joint'
];

/** One main decision written by a review session. */
export interface DecisionRecord {
  id: string;
  /** Id of the review this decision belongs to. */
  reviewId: string;
  type: DecisionRecordType;
  reason: string;
  /** Optional next action; pause, discard and exit may leave it empty. */
  action?: string;
  /** Voluntary promise made where the narrative leaves a gap. */
  commitment?: string;
  /** Relation this decision is practised with; joint only. */
  relationId?: string;
  /** Plan item the action or commitment belongs to. */
  planItemId?: string;
  /** Actual result of a joint practice. */
  outcome?: string;
  /** Local date in YYYY-MM-DD for a later look-back. */
  reviewAt?: string;
  /** Session depth copied from the review payload; absent for old rows */
  depth?: WorkDepth;
  /** Session time budget in minutes; absent for old rows */
  timeBudget?: number;
  level: SecurityLevel;
  createdAt: number;
}

/** The decision fields a review session fills in before it is saved. */
export interface DecisionDraft {
  type: DecisionRecordType;
  reason: string;
  action?: string;
  commitment?: string;
  relationId?: string;
  planItemId?: string;
  outcome?: string;
  reviewAt?: string;
}