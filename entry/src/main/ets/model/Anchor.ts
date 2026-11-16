/** A preset value anchor; referenced by review analysis. */
import { SecurityLevel } from './SecurityLevel';

export interface Anchor {
  id: string;
  /** Anchor sentence */
  text: string;
  /** Source */
  source: string;
  /** Order in the read-only list */
  order: number;
  /** Security level controlling aggregation and export; absent values are local-only */
  level?: SecurityLevel;
  /** Id of the first version; every revision shares it */
  rootId?: string;
  /** Version number, starting at 1 */
  version?: number;
  /** Active anchors appear in new reviews; retired ones stay in history only */
  status?: 'active' | 'retired';
  /** Where the anchor applies, written by its owner */
  context?: string;
  /** Why this version was written */
  revisionReason?: string;
  /** True for the built-in examples, so they never read as the owner's own words */
  synthetic?: boolean;
  /** When this version was written, in epoch milliseconds; absent reads as unknown */
  createdAt?: number;
}
