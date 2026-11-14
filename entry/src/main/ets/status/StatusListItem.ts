import { ReadingFlag } from '../analysis/status/ReadingRules';
import { CapacityJudgment } from '../model/CapacityJudgment';
import { StatusRevision } from '../model/StatusRecord';

/** One rendered status day. */
export interface StatusDayRow {
  id: string;
  /** Date in YYYY-MM-DD */
  date: string;
  sleepHours: number;
  exerciseCount: number;
  alertCount: number;
  note: string;
  /** Body signals the author recorded */
  bodySignals: string;
  /** What the author could still do */
  functionState: string;
  /** Feelings named for the day */
  emotion: string;
  /** Environment factors */
  environment: string;
  /** The author's own judgment; empty when not filled in */
  capacity: CapacityJudgment;
  /** What the load made possible */
  functionGain: string;
  /** What the load cost */
  costPaid: string;
  /** Comma-separated readings marked unknown */
  unknownReadings: string;
  /** Epoch milliseconds of the latest correction; zero when never corrected */
  correctedAt: number;
  /** Earlier readings kept after corrections */
  revisions: StatusRevision[];
  flags: ReadingFlag[];
}

/** Aggregate over the records currently shown. */
export interface StatusSummary {
  days: number;
  /** Average sleep hours over the days with a known sleep reading, one decimal */
  averageSleep: number;
  /** Days whose sleep reading is known */
  sleepDays: number;
  totalExercise: number;
  totalAlerts: number;
  /** Days carrying at least one unknown reading */
  unknownDays: number;
  /** Days with at least one observation hint */
  flaggedDays: number;
}

/** Panel payload: latest reading, aggregate and the recent rows. */
export interface StatusOverview {
  latest: StatusDayRow | null;
  summary: StatusSummary;
  recent: StatusDayRow[];
}
