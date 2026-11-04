import { PlanNodeStatus } from './PlanStatus';

/** One seven-day node, Monday through Sunday. */
export interface PlanNode {
  id: string;
  planId: string;
  projectId?: string;
  /** 1-based index within the plan */
  weekIndex: number;
  /** Monday, YYYY-MM-DD */
  startDate: string;
  /** Sunday, YYYY-MM-DD */
  endDate: string;
  status: PlanNodeStatus;
  /** Weekly review draft created when the node closes */
  reviewId?: string;
}
