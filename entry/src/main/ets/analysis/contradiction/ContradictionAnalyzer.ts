import { Anchor } from '../../model/Anchor';
import { SecurityLevel } from '../../model/SecurityLevel';
import { AnalysisContext } from '../types';

/** Inputs for the four-step contradiction review. */
export interface ContradictionInput {
  facts: string;
  interpretation: string;
  /** Anchors shown as the reference frame for the third step */
  anchors: Anchor[];
  factsLevel: SecurityLevel;
  interpretationLevel: SecurityLevel;
  relationForbidsAnalysis: boolean;
}

/** How sure the analyzer is about one candidate. */
export type CandidateUncertainty = 'low' | 'medium' | 'high' | '';

/** One place where the interpretation departs from the recorded facts. */
export interface ContradictionCandidate {
  /** Anchor used for this comparison; empty when no anchor applies */
  anchorId: string;
  /** What does not line up */
  gap: string;
  /** Follow-up question for the next review step */
  prompt: string;
  /** Which recorded material supports this candidate; empty when it is a generic prompt */
  basis?: string;
  /** What the analyzer could not check; empty when nothing is missing */
  unknowns?: string;
  /** Self-reported confidence; empty when the analyzer did not say */
  uncertainty?: CandidateUncertainty;
}

/**
 * Contract for the contradiction analyzer.
 * The template implementation and the optional LLM implementation both land
 * in 6.2 and must stay behind this interface.
 */
export interface ContradictionAnalyzer {
  analyze(input: ContradictionInput, context: AnalysisContext): Promise<ContradictionCandidate[]>;
}
