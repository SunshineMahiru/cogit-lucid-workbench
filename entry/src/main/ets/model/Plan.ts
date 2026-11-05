import { SecurityLevel } from './SecurityLevel';
import { PlanStatus } from './PlanStatus';

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
  isPrimary: boolean;
  /** Security level controlling aggregation and export */
  level?: SecurityLevel;
  /** Milliseconds */
  createdAt: number;
}
