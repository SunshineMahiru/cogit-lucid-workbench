import { ReviewPeriod } from './ReviewPeriod';
import { ReviewPayload } from './ReviewPayload';
import { SecurityLevel } from './SecurityLevel';

/** A completed review session: six zones, plus the four legacy steps kept for old records. */
export interface ReviewResult {
  id: string;
  period: ReviewPeriod;
  /** Human readable range, captured when the session was saved */
  rangeLabel: string;
  facts: string;
  interpretation: string;
  contradiction: string;
  action: string;
  /** Six-zone content; absent on records saved before zones existed */
  payload?: ReviewPayload;
  /** Anchors quoted during the contradiction step */
  anchorIds: string[];
  /** Optional plan context when the review came from a plan node */
  planId?: string;
  planNodeId?: string;
  /** Security level controlling aggregation and export; absent values are local-only */
  level?: SecurityLevel;
  createdAt: number;
}
