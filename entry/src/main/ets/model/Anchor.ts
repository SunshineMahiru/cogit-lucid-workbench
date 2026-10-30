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
}
