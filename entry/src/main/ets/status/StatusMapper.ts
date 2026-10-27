import { ReadingRules, ReadingSample } from '../analysis/status/ReadingRules';
import { StatusRecord } from '../model/StatusRecord';
import { StatusDayRow, StatusOverview, StatusSummary } from './StatusListItem';

/** Projects one record into a rendered day, applying the threshold rules. */
export function toStatusDayRow(record: StatusRecord, rules: ReadingRules): StatusDayRow {
  const sample: ReadingSample = {
    date: record.date,
    sleepHours: record.sleepHours,
    exerciseCount: record.exerciseCount,
    alertCount: record.alertCount
  };
  return {
    id: record.id,
    date: record.date,
    sleepHours: record.sleepHours,
    exerciseCount: record.exerciseCount,
    alertCount: record.alertCount,
    note: record.note,
    flags: rules.evaluate(sample)
  };
}

/** Projects rows and sorts them newest first. */
export function toStatusDayRows(records: StatusRecord[], rules: ReadingRules): StatusDayRow[] {
  const rows: StatusDayRow[] = [];
  for (const record of records) {
    rows.push(toStatusDayRow(record, rules));
  }
  rows.sort((left: StatusDayRow, right: StatusDayRow) => left.date < right.date ? 1 : (left.date > right.date ? -1 : 0));
  return rows;
}

/** Aggregates the given rows. */
export function summarizeStatus(rows: StatusDayRow[]): StatusSummary {
  if (rows.length === 0) {
    return { days: 0, averageSleep: 0, totalExercise: 0, totalAlerts: 0, flaggedDays: 0 };
  }
  let sleepSum = 0;
  let exercise = 0;
  let alerts = 0;
  let flagged = 0;
  for (const row of rows) {
    sleepSum += row.sleepHours;
    exercise += row.exerciseCount;
    alerts += row.alertCount;
    if (row.flags.length > 0) {
      flagged += 1;
    }
  }
  return {
    days: rows.length,
    averageSleep: Math.round(sleepSum / rows.length * 10) / 10,
    totalExercise: exercise,
    totalAlerts: alerts,
    flaggedDays: flagged
  };
}

/** Builds the panel payload from the newest records. */
export function buildStatusOverview(records: StatusRecord[], rules: ReadingRules, limit: number): StatusOverview {
  const rows = toStatusDayRows(records, rules).slice(0, limit);
  return {
    latest: rows.length > 0 ? rows[0] : null,
    summary: summarizeStatus(rows),
    recent: rows
  };
}
