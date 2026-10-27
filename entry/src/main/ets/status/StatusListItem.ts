import { ReadingFlag } from '../analysis/status/ReadingRules';

/** One rendered status day. */
export interface StatusDayRow {
  id: string;
  /** Date in YYYY-MM-DD */
  date: string;
  sleepHours: number;
  exerciseCount: number;
  alertCount: number;
  note: string;
  flags: ReadingFlag[];
}

/** Aggregate over the records currently shown. */
export interface StatusSummary {
  days: number;
  /** Average sleep hours, one decimal */
  averageSleep: number;
  totalExercise: number;
  totalAlerts: number;
  /** Days with at least one threshold flag */
  flaggedDays: number;
}

/** Panel payload: latest reading, aggregate and the recent rows. */
export interface StatusOverview {
  latest: StatusDayRow | null;
  summary: StatusSummary;
  recent: StatusDayRow[];
}
