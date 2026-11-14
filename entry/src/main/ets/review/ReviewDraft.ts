import { emptyReviewPayload, ReviewPayload } from '../model/ReviewPayload';

/** Counts shown at the top of a review session. */
export interface ReviewStats {
  rangeLabel: string;
  noteCount: number;
  decisionCount: number;
  pendingPredictions: number;
  settledPredictions: number;
  hitRate: number;
  anchorCount: number;
}

/** Zeroed stats used before the first load. */
export function emptyReviewStats(): ReviewStats {
  return {
    rangeLabel: '',
    noteCount: 0,
    decisionCount: 0,
    pendingPredictions: 0,
    settledPredictions: 0,
    hitRate: 0,
    anchorCount: 0
  };
}

/** Review draft: the four legacy steps plus the six zones; only one zone needs text. */
export interface ReviewDraft {
  facts: string;
  interpretation: string;
  contradiction: string;
  action: string;
  /** Six-zone content; absent while a draft still uses the four steps */
  payload?: ReviewPayload;
  anchorIds: string[];
  /** Plan context when the draft belongs to one plan node */
  planId?: string;
  planNodeId?: string;
}

/** Returns an empty draft with no anchors referenced. */
export function createReviewDraft(): ReviewDraft {
  return {
    facts: '',
    interpretation: '',
    contradiction: '',
    action: '',
    payload: emptyReviewPayload(),
    anchorIds: []
  };
}
