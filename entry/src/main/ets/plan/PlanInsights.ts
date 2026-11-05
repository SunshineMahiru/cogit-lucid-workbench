import { PlanNode } from '../model/PlanNode';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanNodeStatus } from '../model/PlanStatus';
import { addPlanDays, formatPlanDate, parsePlanDate } from './PlanFactory';

/** One week's checklist split, used by the segmented bar and the carry-over line. */
export interface NodeProgress {
  nodeId: string;
  weekIndex: number;
  startDate: string;
  endDate: string;
  status: PlanNodeStatus;
  done: number;
  openCarried: number;
  openNew: number;
  total: number;
}

/** Carry-over ratio of one week, in whole percent. */
export interface CarryPoint {
  label: string;
  percent: number;
  carried: number;
  total: number;
}

/** Countdown state of one goal; `hasTarget` is false when no end date is set. */
export interface DeadlineProgress {
  hasTarget: boolean;
  percent: number;
  remainingDays: number;
  totalDays: number;
  overdue: boolean;
}

/** Remaining days inside one seven-day node. */
export interface NodeDays {
  left: number;
  total: number;
  percent: number;
}

/** One day inside the week view. */
export interface DayActivity {
  date: string;
  weekday: string;
  noteCount: number;
  hasReading: boolean;
  sleepHours: number;
  exerciseCount: number;
}

/** Reading values used by the week view; zero hours means no record that day. */
export interface DayReading {
  date: string;
  sleepHours: number;
  exerciseCount: number;
}

const WEEKDAYS: string[] = ['一', '二', '三', '四', '五', '六', '日'];
const MODULE_ORDER: PlanLinkModule[] = [
  PlanLinkModule.NOTE,
  PlanLinkModule.PREDICTION,
  PlanLinkModule.REVIEW,
  PlanLinkModule.ANCHOR,
  PlanLinkModule.RELATION,
  PlanLinkModule.STATUS
];

/** Counts links per module in a fixed order, so the bar chart keeps a stable axis. */
export interface LinkCount {
  module: PlanLinkModule;
  count: number;
}

/** Splits every node's checklist into done, open-carried and open-new. */
export function buildNodeProgress(nodes: PlanNode[], items: PlanItem[]): NodeProgress[] {
  const rows: NodeProgress[] = [];
  for (const node of nodes) {
    let done = 0;
    let openCarried = 0;
    let openNew = 0;
    let total = 0;
    for (const item of items) {
      if (item.nodeId !== node.id) {
        continue;
      }
      total += 1;
      if (item.done) {
        done += 1;
      } else if (item.carriedFrom !== undefined && item.carriedFrom.length > 0) {
        openCarried += 1;
      } else {
        openNew += 1;
      }
    }
    rows.push({
      nodeId: node.id,
      weekIndex: node.weekIndex,
      startDate: node.startDate,
      endDate: node.endDate,
      status: node.status,
      done: done,
      openCarried: openCarried,
      openNew: openNew,
      total: total
    });
  }
  rows.sort((left, right) => left.weekIndex - right.weekIndex);
  return rows;
}

/** Carry-over share of one week; zero when the week has no checklist. */
export function carryRatePercent(row: NodeProgress): number {
  if (row.total === 0) {
    return 0;
  }
  return Math.round(row.openCarried / row.total * 100);
}

/** Carry-over series for the line chart; weeks without items are skipped. */
export function carrySeries(rows: NodeProgress[]): CarryPoint[] {
  const points: CarryPoint[] = [];
  for (const row of rows) {
    if (row.total === 0) {
      continue;
    }
    points.push({
      label: `第${row.weekIndex}周`,
      percent: carryRatePercent(row),
      carried: row.openCarried,
      total: row.total
    });
  }
  return points;
}

/** Counts links per module, keeping the six-module order. */
export function linkCounts(links: PlanLink[]): LinkCount[] {
  const rows: LinkCount[] = [];
  for (const module of MODULE_ORDER) {
    let count = 0;
    for (const link of links) {
      if (link.module === module) {
        count += 1;
      }
    }
    rows.push({ module: module, count: count });
  }
  return rows;
}

/** Days between two YYYY-MM-DD dates; negative when the second date is earlier. */
export function daysBetween(from: string, to: string): number {
  const start = parsePlanDate(from).getTime();
  const end = parsePlanDate(to).getTime();
  return Math.round((end - start) / 86400000);
}

/** Elapsed share of the goal window; without an end date nothing is computed. */
export function deadlineProgress(startDate: string, targetDate: string, today: string): DeadlineProgress {
  if (targetDate.length === 0) {
    return { hasTarget: false, percent: 0, remainingDays: 0, totalDays: 0, overdue: false };
  }
  const totalDays = daysBetween(startDate, targetDate);
  if (totalDays <= 0) {
    const remaining = daysBetween(today, targetDate);
    return {
      hasTarget: true,
      percent: 100,
      remainingDays: remaining,
      totalDays: 0,
      overdue: remaining < 0
    };
  }
  const elapsed = daysBetween(startDate, today);
  const percent = Math.min(100, Math.max(0, Math.round(elapsed / totalDays * 100)));
  return {
    hasTarget: true,
    percent: percent,
    remainingDays: daysBetween(today, targetDate),
    totalDays: totalDays,
    overdue: daysBetween(today, targetDate) < 0
  };
}

/** Remaining days of one node, clamped to its seven-day window. */
export function nodeDays(left: string, right: string, today: string): NodeDays {
  const total = Math.max(1, daysBetween(left, right) + 1);
  const raw = daysBetween(today, right) + 1;
  const clamped = Math.min(total, Math.max(0, raw));
  return {
    left: clamped,
    total: total,
    percent: Math.round(clamped / total * 100)
  };
}

/** Seven dates of one week starting on the given Monday. */
export function weekDates(monday: string): string[] {
  const dates: string[] = [];
  for (let offset = 0; offset < 7; offset += 1) {
    dates.push(addPlanDays(monday, offset));
  }
  return dates;
}

/** Joins note timestamps and reading rows into the seven day cells. */
export function buildDayActivity(dates: string[], noteTimestamps: number[],
  readings: DayReading[]): DayActivity[] {
  const rows: DayActivity[] = [];
  for (let index = 0; index < dates.length; index += 1) {
    const date = dates[index];
    let notes = 0;
    for (const stamp of noteTimestamps) {
      if (formatPlanDate(new Date(stamp)) === date) {
        notes += 1;
      }
    }
    let sleepHours = 0;
    let exerciseCount = 0;
    for (const reading of readings) {
      if (reading.date === date) {
        sleepHours = reading.sleepHours;
        exerciseCount = reading.exerciseCount;
        break;
      }
    }
    rows.push({
      date: date,
      weekday: WEEKDAYS[index % 7],
      noteCount: notes,
      hasReading: sleepHours > 0 || exerciseCount > 0,
      sleepHours: sleepHours,
      exerciseCount: exerciseCount
    });
  }
  return rows;
}
