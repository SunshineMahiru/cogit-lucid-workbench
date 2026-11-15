import { SecurityLevel } from './SecurityLevel';

/** A material as it read when a review cited it; later edits to the source do not reach it. */
export interface ReviewMaterial {
  reviewId: string;
  materialId: string;
  /** Text copied at citation time; empty when the source was missing, deleted or sealed. */
  textSnapshot: string;
  /** Origin copied at citation time; empty when no snapshot could be taken. */
  sourceSnapshot: string;
  /** Security level copied at citation time, or the source's level when the text was withheld. */
  levelSnapshot: SecurityLevel;
  /** Review zone the material supports; 0 while the review flow does not assign one. */
  zone: number;
  /** Timestamp the review was created. */
  citedAt: number;
  /** True when the source could not be read, so the snapshot keeps no text. */
  snapshotMissing: boolean;
}

/** Review zones; only UNASSIGNED is written today. */
export const REVIEW_ZONE = {
  UNASSIGNED: 0,
  SCENE: 1,
  MODEL: 2,
  RELATION: 3,
  EVIDENCE: 4,
  COST: 5,
  REVISION: 6
} as const;