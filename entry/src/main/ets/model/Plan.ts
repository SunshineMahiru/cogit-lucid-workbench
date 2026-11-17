import { SecurityLevel } from './SecurityLevel';
import { PlanStatus } from './PlanStatus';
import { WorkDepth } from './WorkDepth';

/** A long-running goal; only one plan is the primary goal at a time. */
export interface Plan {
  id: string;
  title: string;
  goal: string;
  /** Optional project grouping; empty means the nodes hang directly under the goal. */
  projectId?: string;
  /** Monday of the first seven-day node, YYYY-MM-DD */
  startDate: string;
  /** Optional end date used by the settlement progress; empty means no deadline */
  targetDate?: string;
  status: PlanStatus;
  /** Why the plan is paused; empty while active */
  pauseReason?: string;
  /** Optional date to look at it again, YYYY-MM-DD */
  resumeAt?: string;
  isPrimary: boolean;
  /** Security level controlling aggregation and export */
  level?: SecurityLevel;
  /** How much attention this plan is meant to take; absent reads as normal */
  depth?: WorkDepth;
  /** Minutes each session on this plan is allowed to take; 0 means no budget */
  timeBudget?: number;
  /** How the owner will know the goal is done */
  doneStandard?: string;
  /** Who or what the goal affects */
  impact?: string;
  /** Who the goal serves */
  beneficiary?: string;
  /** Who bears the cost of the goal */
  costBearer?: string;
  /** Milliseconds */
  createdAt: number;
}
