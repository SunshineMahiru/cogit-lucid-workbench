import { Anchor } from '../../model/Anchor';

/** One anchor ranked against a piece of review text. */
export interface AnchorMatch {
  anchorId: string;
  /** 0-1 relevance score */
  score: number;
  /** Why this anchor matched, kept short for the UI */
  reason: string;
}

/**
 * Contract for anchor matching used by the contradiction step.
 * The keyword implementation lands in 6.2; the LLM variant must keep this shape.
 */
export interface AnchorMatcher {
  match(text: string, anchors: Anchor[], limit: number): AnchorMatch[];
}
