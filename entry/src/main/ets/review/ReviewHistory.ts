import { Anchor } from '../model/Anchor';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewResult } from '../model/ReviewResult';

/** Row model for the saved review list. */
export interface ReviewHistoryItem {
  id: string;
  period: ReviewPeriod;
  periodLabel: string;
  rangeLabel: string;
  action: string;
  createdAtLabel: string;
  anchorCount: number;
}

/** Read-only review with resolved anchors for the contrast section. */
export interface ReviewDetailView extends ReviewHistoryItem {
  facts: string;
  interpretation: string;
  contradiction: string;
  anchors: Anchor[];
}

/** Projects a saved result into a history row. */
export function toReviewHistoryItem(result: ReviewResult): ReviewHistoryItem {
  return {
    id: result.id,
    period: result.period,
    periodLabel: result.period === ReviewPeriod.WEEK ? '周复盘' : '月复盘',
    rangeLabel: result.rangeLabel,
    action: result.action,
    createdAtLabel: formatReviewTime(result.createdAt),
    anchorCount: result.anchorIds.length
  };
}

/** Resolves anchor ids in their saved order and drops ids that no longer exist. */
export function toReviewDetailView(result: ReviewResult, anchors: Anchor[]): ReviewDetailView {
  const resolved: Anchor[] = [];
  for (const id of result.anchorIds) {
    const anchor = anchors.find((item: Anchor) => item.id === id);
    if (anchor !== undefined) {
      resolved.push(anchor);
    }
  }
  return {
    id: result.id,
    period: result.period,
    periodLabel: result.period === ReviewPeriod.WEEK ? '周复盘' : '月复盘',
    rangeLabel: result.rangeLabel,
    action: result.action,
    createdAtLabel: formatReviewTime(result.createdAt),
    anchorCount: result.anchorIds.length,
    facts: result.facts,
    interpretation: result.interpretation,
    contradiction: result.contradiction,
    anchors: resolved
  };
}

/** Local date-time label used in both the list and the detail header. */
export function formatReviewTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ` +
    `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
