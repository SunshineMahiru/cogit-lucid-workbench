import { InteractionLog } from '../model/Relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';

/** Row model rendered by the relation list. */
export interface RelationListItem {
  id: string;
  /** Sanitized alias; never a real name */
  name: string;
  trustLevel: TrustLevel;
  interactionCount: number;
  /** Latest interaction time, or 暂无互动 */
  lastInteractionLabel: string;
  /** Latest interaction timestamp in milliseconds; 0 when none */
  lastInteractionAt: number;
  rawMaterialTest: boolean;
  forbidAnalysis: boolean;
  level: SecurityLevel;
  notes: string;
  /** Latest correction from the other person */
  correction?: string;
  /** Epoch milliseconds of the latest correction; zero when never corrected */
  correctionAt?: number;
  /** 1 when a correction still has no own-response entry after it */
  pendingCorrections?: number;
}

/** Detail model with the full interaction log. */
export interface RelationDetail extends RelationListItem {
  /** Newest interaction first */
  interactionLog: InteractionLog[];
  /** How the other person corrected the author's understanding */
  correction: string;
  /** Epoch milliseconds of the latest correction; zero when never corrected */
  correctionAt: number;
  /** Titles of notes that reference this relation */
  linkedEvents: string[];
  /** Titles of decisions that reference this relation */
  linkedDecisions: string[];
}
