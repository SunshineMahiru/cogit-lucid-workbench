/** One day of physiological readings. */
export interface ReadingSample {
  date: string;
  sleepHours: number;
  exerciseCount: number;
  alertCount: number;
}

/** A rule hit shown on the status panel. */
export interface ReadingFlag {
  code: string;
  message: string;
}

/**
 * Contract for reading thresholds.
 * The implementation lands with the status panel work in 2.8/6.x.
 */
export interface ReadingRules {
  evaluate(sample: ReadingSample): ReadingFlag[];
}
