import { ReadingRules, ReadingSample } from '../analysis/status/ReadingRules';
import { isReadingUnknown, unknownList } from '../analysis/status/ReadingPresence';
import { StatusRecord } from '../model/StatusRecord';
import { toCapacityJudgment } from '../model/CapacityJudgment';
import { StatusDayRow, StatusOverview, StatusSummary } from './StatusListItem';
import { parseStatusRevisions } from './StatusRevisions';

/** Projects one record into a rendered day, applying the observation rules. */
export function toStatusDayRow(record: StatusRecord, rules: ReadingRules): StatusDayRow {
  const unknown = record.unknownReadings ?? '';
  const sample: ReadingSample = {
    date: record.date,
    sleepHours: record.sleepHours,
    exerciseCount: record.exerciseCount,
    alertCount: record.alertCount,
    unknownReadings: unknown
  };
  return {
    id: record.id,
    date: record.date,
    sleepHours: record.sleepHours,
    exerciseCount: record.exerciseCount,
    alertCount: record.alertCount,
    note: record.note,
    bodySignals: record.bodySignals ?? '',
    functionState: record.functionState ?? '',
    emotion: record.emotion ?? '',
    environment: record.environment ?? '',
    capacity: toCapacityJudgment(record.capacity ?? ''),
    functionGain: record.functionGain ?? '',
    costPaid: record.costPaid ?? '',
    unknownReadings: unknown,
    correctedAt: record.correctedAt ?? 0,
    revisions: parseStatusRevisions(record.revisions ?? ''),
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

/** Aggregates the given rows; unknown readings stay out of every total they belong to. */
export function summarizeStatus(rows: StatusDayRow[]): StatusSummary {
  if (rows.length === 0) {
    return {
      days: 0,
      averageSleep: 0,
      sleepDays: 0,
      totalExercise: 0,
      totalAlerts: 0,
      unknownDays: 0,
      flaggedDays: 0
    };
  }
  let sleepSum = 0;
  let sleepDays = 0;
  let exercise = 0;
  let alerts = 0;
  let unknownDays = 0;
  let flagged = 0;
  for (const row of rows) {
    if (!isReadingUnknown(row.unknownReadings, 'sleep')) {
      sleepSum += row.sleepHours;
      sleepDays += 1;
    }
    if (!isReadingUnknown(row.unknownReadings, 'exercise')) {
      exercise += row.exerciseCount;
    }
    if (!isReadingUnknown(row.unknownReadings, 'alert')) {
      alerts += row.alertCount;
    }
    if (unknownList(row.unknownReadings).length > 0) {
      unknownDays += 1;
    }
    if (row.flags.length > 0) {
      flagged += 1;
    }
  }
  return {
    days: rows.length,
    averageSleep: sleepDays === 0 ? 0 : Math.round(sleepSum / sleepDays * 10) / 10,
    sleepDays: sleepDays,
    totalExercise: exercise,
    totalAlerts: alerts,
    unknownDays: unknownDays,
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
