import { ReadingFlag, ReadingRules, ReadingSample } from './ReadingRules';
import { ObservationRule, defaultObservationRule } from './ObservationRule';
import { isReadingUnknown } from './ReadingPresence';

/** Sleep below this value raises a hint with the default rule. */
export const SLEEP_MIN_HOURS = 6.5;
/** Any late-night alert raises a hint with the default rule. */
export const ALERT_WARN_COUNT = 1;

/** Threshold rules using the author's observation settings. */
export class ThresholdReadingRules implements ReadingRules {
  private rule: ObservationRule;

  constructor(rule: ObservationRule = defaultObservationRule()) {
    this.rule = rule;
  }

  evaluate(sample: ReadingSample): ReadingFlag[] {
    const flags: ReadingFlag[] = [];
    if (!this.rule.hintsEnabled) {
      return flags;
    }
    const unknown = sample.unknownReadings ?? '';
    if (!isReadingUnknown(unknown, 'sleep') && sample.sleepHours < this.rule.sleepMinHours) {
      flags.push({
        code: 'sleep_low',
        message: `睡眠 ${formatHours(sample.sleepHours)} 小时，低于观察下限 ${this.rule.sleepMinHours} 小时`
      });
    }
    if (!isReadingUnknown(unknown, 'exercise') && sample.exerciseCount === 0) {
      flags.push({ code: 'exercise_none', message: '当天没有运动记录' });
    }
    if (!isReadingUnknown(unknown, 'alert') && sample.alertCount >= this.rule.alertWarnCount) {
      flags.push({ code: 'alert_high', message: `凌晨报警 ${sample.alertCount} 次，达到观察上限 ${this.rule.alertWarnCount} 次` });
    }
    return flags;
  }
}

function formatHours(value: number): string {
  return Number.isInteger(value) ? `${value}` : value.toFixed(1);
}
