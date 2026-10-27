import { ReadingFlag, ReadingRules, ReadingSample } from './ReadingRules';

/** Sleep below this value raises a flag. */
export const SLEEP_MIN_HOURS = 6.5;
/** Any late-night alert raises a flag. */
export const ALERT_WARN_COUNT = 1;

/** Deterministic threshold rules; the configurable variant can replace it later. */
export class ThresholdReadingRules implements ReadingRules {
  evaluate(sample: ReadingSample): ReadingFlag[] {
    const flags: ReadingFlag[] = [];
    if (sample.sleepHours < SLEEP_MIN_HOURS) {
      flags.push({
        code: 'sleep_low',
        message: `睡眠 ${formatHours(sample.sleepHours)} 小时，低于 ${SLEEP_MIN_HOURS} 小时`
      });
    }
    if (sample.exerciseCount === 0) {
      flags.push({ code: 'exercise_none', message: '当天没有运动记录' });
    }
    if (sample.alertCount >= ALERT_WARN_COUNT) {
      flags.push({ code: 'alert_high', message: `凌晨报警 ${sample.alertCount} 次` });
    }
    return flags;
  }
}

function formatHours(value: number): string {
  return Number.isInteger(value) ? `${value}` : value.toFixed(1);
}
