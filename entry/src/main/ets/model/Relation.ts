import { SecurityLevel } from './SecurityLevel';
import { TrustLevel } from './TrustLevel';

/** An interaction with someone, logged under a relation. */
export interface InteractionLog {
  timestamp: number;
  content: string;
}

/** Records a relationship: trust tier, interaction log and analysis flags. */
export interface Relation {
  id: string;
  /** Sanitized alias; never stores a real name */
  name: string;
  /** Trust tier: friendly / sincere / transparent */
  trustLevel: TrustLevel;
  interactionLog: InteractionLog[];
  /** Whether this person has held raw, unpolished material */
  rawMaterialTest: boolean;
  /** When true, the review agent refuses motive analysis for this person */
  forbidAnalysis: boolean;
  /** Security level, defaults to LOCAL_ONLY */
  level: SecurityLevel;
  /** Soft-delete marker; absent means active. */
  deleted?: boolean;
  notes: string;
}
