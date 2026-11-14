import { SecurityLevel } from './SecurityLevel';

/** What kind of material a record carries; see 04 §5.2 for the meaning of each. */
export type MaterialKind =
  | 'scene'
  | 'feeling'
  | 'body'
  | 'existing_action'
  | 'interpretation'
  | 'unclassified';

/** How the material was written; kept so exports can show its evidentiary weight. */
export type MaterialForm = 'first_person' | 'dialogue' | 'third_person' | 'poem' | 'reading_note' | 'public_claim' | '';

/** Where the material came from. */
export type MaterialSource = 'direct' | 'reading' | 'exercise' | 'interaction' | 'reflection' | 'external';

/** Stance a reading note takes toward the user's current position. */
export type MaterialStance = 'support' | 'challenge' | 'undecided' | '';

/** One piece of experience kept inside an event; the unit the review flow cites. */
export interface ExperienceMaterial {
  id: string;
  eventId: string;
  kind: MaterialKind;
  form: MaterialForm;
  text: string;
  observedAt: number;
  source: MaterialSource;
  sourceStance: MaterialStance;
  level: SecurityLevel;
  /** Points at the material this one revises; empty for originals. */
  revisionOf: string;
  deleted: boolean;
  createdAt: number;
}
