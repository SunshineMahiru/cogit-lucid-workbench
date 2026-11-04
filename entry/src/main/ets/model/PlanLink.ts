import { PlanLinkModule } from './PlanLinkModule';

/** A reference from a plan node to a record in one of the six modules. */
export interface PlanLink {
  id: string;
  planId: string;
  /** Empty when the link sits on the goal rather than one node */
  nodeId?: string;
  module: PlanLinkModule;
  targetId: string;
  /** Short label captured at link time */
  label: string;
  createdAt: number;
}
