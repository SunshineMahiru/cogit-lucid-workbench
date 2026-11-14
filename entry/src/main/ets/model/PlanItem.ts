import { SecurityLevel } from './SecurityLevel';

/** A checklist item under one seven-day node. */
export interface PlanItem {
  id: string;
  nodeId: string;
  text: string;
  done: boolean;
  /** Source item id when the item was carried into this node */
  carriedFrom?: string;
  /** How the item was handled when its week closed: pending, carried, paused or discarded */
  disposition?: string;
  /** Why it was discarded; empty otherwise */
  discardReason?: string;
  sortOrder: number;
  level?: SecurityLevel;
}
