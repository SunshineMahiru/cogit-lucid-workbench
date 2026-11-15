import { SecurityLevel } from './SecurityLevel';

/** Where a piece of evidence came from. */
export type EvidenceSource = 'practice' | 'other_person' | 'body' | 'time' | 'book' | 'public';

/** How a piece of evidence bears on the record it points at. */
export type EvidenceEffect = 'supports' | 'challenges' | 'unclear';

/** The record kinds an evidence item may point at. */
export type EvidenceTargetType = 'review' | 'prediction';

/** The evidence fields a review session fills in before it is saved. */
export interface EvidenceDraft {
  sourceType: EvidenceSource;
  note: string;
  effect: EvidenceEffect;
}

/** One piece of evidence kept against a review or a prediction. */
export interface EvidenceItem {
  id: string;
  targetType: EvidenceTargetType;
  /** Id of the review or prediction this evidence bears on. */
  targetId: string;
  sourceType: EvidenceSource;
  note: string;
  effect: EvidenceEffect;
  level: SecurityLevel;
  /** Review zone the evidence belongs to; 0 when not assigned. */
  zone: number;
  createdAt: number;
}