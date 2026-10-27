import { Anchor } from '../../model/Anchor';
import { AnalysisContext } from '../types';

/** Inputs for the four-step contradiction review. */
export interface ContradictionInput {
  facts: string;
  interpretation: string;
  /** Anchors shown as the reference frame for the third step */
  anchors: Anchor[];
}

/** One place where the interpretation departs from the recorded facts. */
export interface ContradictionCandidate {
  /** Anchor used for this comparison; empty when no anchor applies */
  anchorId: string;
  /** What does not line up */
  gap: string;
  /** Follow-up question for the next review step */
  prompt: string;
}

/**
 * Contract for the contradiction analyzer.
 * The template implementation and the optional LLM implementation both land
 * in 6.2 and must stay behind this interface.
 */
export interface ContradictionAnalyzer {
  analyze(input: ContradictionInput, context: AnalysisContext): Promise<ContradictionCandidate[]>;
}
