import { PlanProjectStatus } from './PlanStatus';

/** Optional project layer under one plan. */
export interface PlanProject {
  id: string;
  planId: string;
  name: string;
  goal: string;
  status: PlanProjectStatus;
  sortOrder: number;
}
