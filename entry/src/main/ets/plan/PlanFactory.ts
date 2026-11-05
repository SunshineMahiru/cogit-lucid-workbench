import { Plan } from '../model/Plan';
import { PlanProject } from '../model/PlanProject';
import { PlanNode } from '../model/PlanNode';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanNodeStatus, PlanProjectStatus, PlanStatus } from '../model/PlanStatus';
import { SecurityLevel } from '../model/SecurityLevel';

let seq = 0;

function newId(prefix: string): string {
  seq += 1;
  return `${prefix}_${Date.now()}_${seq}`;
}

function pad(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

/** Formats a local date as YYYY-MM-DD without going through UTC. */
export function formatPlanDate(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** Parses YYYY-MM-DD as a local date; returns an invalid date for impossible values. */
export function parsePlanDate(value: string): Date {
  const parts = value.split('-');
  if (parts.length !== 3) {
    return new Date(NaN);
  }
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const day = Number(parts[2]);
  const date = new Date(year, month - 1, day);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    return new Date(NaN);
  }
  return date;
}

/** Returns the Monday of the week containing the given date. */
export function mondayOf(value: string): string {
  const date = parsePlanDate(value);
  const offset = (date.getDay() + 6) % 7;
  date.setDate(date.getDate() - offset);
  return formatPlanDate(date);
}

/** Adds days to a YYYY-MM-DD date. */
export function addPlanDays(value: string, days: number): string {
  const date = parsePlanDate(value);
  date.setDate(date.getDate() + days);
  return formatPlanDate(date);
}

/** Creates a new goal, normalized to the Monday of its first week. */
export function createPlan(title: string, startDate: string, targetDate: string = ''): Plan {
  const plan: Plan = {
    id: newId('pl'),
    title: title.trim(),
    goal: '',
    startDate: mondayOf(startDate),
    status: PlanStatus.ACTIVE,
    isPrimary: false,
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: Date.now()
  };
  if (targetDate.length > 0) {
    plan.targetDate = targetDate;
  }
  return plan;
}

/** Creates an optional project under a goal. */
export function createPlanProject(planId: string, name: string, sortOrder: number): PlanProject {
  return {
    id: newId('pp'),
    planId: planId,
    name: name.trim(),
    goal: '',
    status: PlanProjectStatus.ACTIVE,
    sortOrder: sortOrder
  };
}

/** Creates one seven-day node; weekIndex starts at 1. */
export function createPlanNode(planId: string, weekIndex: number, monday: string, projectId?: string): PlanNode {
  const node: PlanNode = {
    id: newId('pn'),
    planId: planId,
    weekIndex: weekIndex,
    startDate: mondayOf(monday),
    endDate: addPlanDays(mondayOf(monday), 6),
    status: PlanNodeStatus.OPEN
  };
  if (projectId !== undefined && projectId.length > 0) {
    node.projectId = projectId;
  }
  return node;
}

/** Creates one checklist item. */
export function createPlanItem(nodeId: string, text: string, sortOrder: number, carriedFrom?: string): PlanItem {
  const item: PlanItem = {
    id: newId('pi'),
    nodeId: nodeId,
    text: text.trim(),
    done: false,
    sortOrder: sortOrder,
    level: SecurityLevel.LOCAL_ONLY
  };
  if (carriedFrom !== undefined && carriedFrom.length > 0) {
    item.carriedFrom = carriedFrom;
  }
  return item;
}

/** Creates a reference to a record in one of the six modules. */
export function createPlanLink(
  planId: string,
  nodeId: string,
  module: PlanLinkModule,
  targetId: string,
  label: string
): PlanLink {
  return {
    id: newId('lk'),
    planId: planId,
    nodeId: nodeId,
    module: module,
    targetId: targetId,
    label: label,
    createdAt: Date.now()
  };
}
