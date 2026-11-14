import { SecurityLevel } from './SecurityLevel';
import { TrustLevel } from './TrustLevel';

/** Where an interaction entry came from; absent values read as the author's own observation. */
export type InteractionSource = 'observation' | 'stated' | 'joint' | 'inference';

/** How far one entry may travel: only here, summarized outside, or quoted verbatim. */
export type CitationScope = 'hidden' | 'paraphrase' | 'quote';

/** An interaction with someone, logged under a relation. */
export interface InteractionLog {
  timestamp: number;
  content: string;
  /** Who the entry belongs to; absent values read as observation */
  source?: InteractionSource;
  /** Citation scope outside the device; absent values read as hidden */
  citation?: CitationScope;
  /** Whether the entry may enter a model request; absent values read as no */
  allowContext?: boolean;
}

/** Records a relationship: disclosure tier, interaction log and analysis flags. */
export interface Relation {
  id: string;
  /** Sanitized alias; never stores a real name */
  name: string;
  /** Disclosure tier: friendly / sincere / transparent */
  trustLevel: TrustLevel;
  interactionLog: InteractionLog[];
  /** Whether this person has held raw, unpolished material; kept as history only */
  rawMaterialTest: boolean;
  /** When true, no path may infer motive, personality or the outcome of this relation */
  forbidAnalysis: boolean;
  /** How the other person corrected the author's understanding */
  correction?: string;
  /** Epoch milliseconds of the latest correction */
  correctionAt?: number;
  /** Security level, defaults to LOCAL_ONLY */
  level: SecurityLevel;
  /** Soft-delete marker; absent means active. */
  deleted?: boolean;
  notes: string;
}
