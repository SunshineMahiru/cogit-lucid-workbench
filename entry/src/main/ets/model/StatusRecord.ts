/** A status record for the monitoring panel: sleep, exercise and late-night alerts. */
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
}
