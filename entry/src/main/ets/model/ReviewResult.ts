import { ReviewPeriod } from './ReviewPeriod';
import { SecurityLevel } from './SecurityLevel';

/** A completed review session: four steps plus the anchors it referenced. */
export interface ReviewResult {
  id: string;
  period: ReviewPeriod;
  /** Human readable range, captured when the session was saved */
  rangeLabel: string;
  facts: string;
  interpretation: string;
  contradiction: string;
  action: string;
  /** Anchors quoted during the contradiction step */
  anchorIds: string[];
  /** Optional plan context when the review came from a plan node */
  planId?: string;
  planNodeId?: string;
  /** Security level controlling aggregation and export; absent values are local-only */
  level?: SecurityLevel;
  createdAt: number;
}
