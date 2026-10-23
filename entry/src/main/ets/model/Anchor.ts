/** A preset value anchor; read-only, referenced by review analysis. */
export interface Anchor {
  id: string;
  /** Anchor sentence */
  text: string;
  /** Source */
  source: string;
  /** Order in the read-only list */
  order: number;
}
