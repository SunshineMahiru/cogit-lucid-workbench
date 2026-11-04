import { Plan } from '../model/Plan';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanNode } from '../model/PlanNode';

/** One plan with its nodes, checklist items and record links, prepared for export. */
export interface PlanExport {
  plan: Plan;
  nodes: PlanNode[];
  items: PlanItem[];
  links: PlanLink[];
}
