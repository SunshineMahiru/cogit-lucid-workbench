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

/** Four-step review draft; only the facts and the action are required. */
export interface ReviewDraft {
  facts: string;
  interpretation: string;
  contradiction: string;
  action: string;
  anchorIds: string[];
}

/** Returns an empty draft with no anchors referenced. */
export function createReviewDraft(): ReviewDraft {
  return {
    facts: '',
    interpretation: '',
    contradiction: '',
    action: '',
    anchorIds: []
  };
}
