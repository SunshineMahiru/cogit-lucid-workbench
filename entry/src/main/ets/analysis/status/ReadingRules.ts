/** One day of physiological readings and the readings the author left unknown. */
export interface ReadingSample {
  date: string;
  sleepHours: number;
  exerciseCount: number;
  alertCount: number;
  /** Comma-separated readings marked unknown: sleep, exercise, alert */
  unknownReadings?: string;
}

/** A rule hit shown on the status panel. */
export interface ReadingFlag {
  code: string;
  message: string;
}

/** Contract for reading thresholds. */
export interface ReadingRules {
  evaluate(sample: ReadingSample): ReadingFlag[];
}
