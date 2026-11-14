/** A status record for the monitoring panel: readings, body evidence and the author's own judgment. */
import { SecurityLevel } from './SecurityLevel';
import { CapacityJudgment } from './CapacityJudgment';

/** One earlier reading kept after a same-day correction. */
export interface StatusRevision {
  /** When the reading was replaced, in epoch milliseconds */
  at: number;
  sleepHours: number;
  exerciseCount: number;
  alertCount: number;
  note: string;
  capacity: CapacityJudgment;
}

export interface StatusRecord {
  id: string;
  /** Date in YYYY-MM-DD */
  date: string;
  /** Sleep hours; ignored when `unknownReadings` lists sleep */
  sleepHours: number;
  /** Exercise count; ignored when `unknownReadings` lists exercise */
  exerciseCount: number;
  /** Late-night alert count (after 01:00); ignored when `unknownReadings` lists alert */
  alertCount: number;
  note: string;
  /** Body signals recorded as free text */
  bodySignals?: string;
  /** What the author could still do in this state */
  functionState?: string;
  /** Feelings the author names for the day */
  emotion?: string;
  /** Environment factors worth remembering */
  environment?: string;
  /** The author's own judgment; empty means not filled in */
  capacity?: CapacityJudgment;
  /** What the load made possible */
  functionGain?: string;
  /** What the load cost */
  costPaid?: string;
  /** Comma-separated readings the author marked as unknown: sleep, exercise, alert */
  unknownReadings?: string;
  /** Epoch milliseconds of the latest correction; zero when never corrected */
  correctedAt?: number;
  /** JSON array of StatusRevision entries */
  revisions?: string;
  /** Security level controlling aggregation and export; absent values are local-only */
  level?: SecurityLevel;
  /** Soft-delete marker; absent means active. */
  deleted?: boolean;
}
