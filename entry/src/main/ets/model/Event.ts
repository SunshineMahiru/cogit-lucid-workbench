import { SecurityLevel } from './SecurityLevel';

/** Records something that happened; may be referenced by decisions and relations. */
export interface Event {
  id: string;
  title: string;
  content: string;
  /** Category label, e.g. interpersonal / body / emotion */
  type: string;
  /** Occurrence timestamp in milliseconds */
  timestamp: number;
  tags: string[];
  /** Security level, defaults to LOCAL_ONLY */
  level: SecurityLevel;
  relatedDecisionIds: string[];
  relatedRelationIds: string[];
  /** True once the note is deleted; the row stays so history can point at it */
  deleted?: boolean;
}
