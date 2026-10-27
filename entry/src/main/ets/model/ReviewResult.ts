import { ReviewPeriod } from './ReviewPeriod';

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
  createdAt: number;
}
