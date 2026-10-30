/** A status record for the monitoring panel: sleep, exercise and late-night alerts. */
import { SecurityLevel } from './SecurityLevel';

export interface StatusRecord {
  id: string;
  /** Date in YYYY-MM-DD */
  date: string;
  /** Sleep hours */
  sleepHours: number;
  /** Exercise count */
  exerciseCount: number;
  /** Late-night alert count (after 01:00) */
  alertCount: number;
  note: string;
  /** Security level controlling aggregation and export; absent values are local-only */
  level?: SecurityLevel;
}
