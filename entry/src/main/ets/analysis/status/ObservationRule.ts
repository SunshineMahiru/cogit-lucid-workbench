/** Personal observation thresholds; they describe data conditions and never diagnose. */

export interface ObservationRule {
  /** Sleep below this many hours gets a hint */
  sleepMinHours: number;
  /** Alerts at or above this count get a hint */
  alertWarnCount: number;
  /** When false, the panel shows no hints at all */
  hintsEnabled: boolean;
}

/** Values used before the author changes anything. */
export const DEFAULT_OBSERVATION_RULE: ObservationRule = {
  sleepMinHours: 6.5,
  alertWarnCount: 1,
  hintsEnabled: true
};

/** Shown next to every hint so the rule never reads as a medical judgment. */
export const OBSERVATION_RULE_NOTE = '观察规则只描述数据条件，不做医学判断，也不替你决定是否继续。';

/** Returns a fresh copy of the defaults. */
export function defaultObservationRule(): ObservationRule {
  return {
    sleepMinHours: DEFAULT_OBSERVATION_RULE.sleepMinHours,
    alertWarnCount: DEFAULT_OBSERVATION_RULE.alertWarnCount,
    hintsEnabled: DEFAULT_OBSERVATION_RULE.hintsEnabled
  };
}

/** Clamps stored values into a range the panel can explain. */
export function sanitizeObservationRule(rule: ObservationRule): ObservationRule {
  const sleep = Number.isFinite(rule.sleepMinHours) ? rule.sleepMinHours : DEFAULT_OBSERVATION_RULE.sleepMinHours;
  const alerts = Number.isFinite(rule.alertWarnCount) ? Math.floor(rule.alertWarnCount) : DEFAULT_OBSERVATION_RULE.alertWarnCount;
  return {
    sleepMinHours: Math.min(Math.max(sleep, 3), 10),
    alertWarnCount: Math.min(Math.max(alerts, 1), 10),
    hintsEnabled: rule.hintsEnabled === true
  };
}
