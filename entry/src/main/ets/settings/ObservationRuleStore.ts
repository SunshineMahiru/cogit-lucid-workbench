import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ObservationRule, defaultObservationRule, sanitizeObservationRule } from '../analysis/status/ObservationRule';
import { SETTINGS_KEYS, SETTINGS_STORE_NAME } from './SettingsKeys';

/** Reads and writes the personal observation thresholds of the status panel. */
export class ObservationRuleStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  /** Opens the settings store; values persist across launches. */
  static async open(context: common.Context): Promise<ObservationRuleStore> {
    const prefs = await preferences.getPreferences(context, { name: SETTINGS_STORE_NAME });
    return new ObservationRuleStore(prefs);
  }

  /** Returns the stored rule, falling back to defaults for missing or malformed values. */
  async load(): Promise<ObservationRule> {
    const defaults = defaultObservationRule();
    const sleep = await this.prefs.get(SETTINGS_KEYS.STATUS_SLEEP_MIN, defaults.sleepMinHours);
    const alerts = await this.prefs.get(SETTINGS_KEYS.STATUS_ALERT_WARN, defaults.alertWarnCount);
    const enabled = await this.prefs.get(SETTINGS_KEYS.STATUS_HINTS_ENABLED, defaults.hintsEnabled);
    return sanitizeObservationRule({
      sleepMinHours: typeof sleep === 'number' ? sleep : defaults.sleepMinHours,
      alertWarnCount: typeof alerts === 'number' ? alerts : defaults.alertWarnCount,
      hintsEnabled: typeof enabled === 'boolean' ? enabled : defaults.hintsEnabled
    });
  }

  /** Persists the rule after clamping it. */
  async save(rule: ObservationRule): Promise<void> {
    const safe = sanitizeObservationRule(rule);
    await this.prefs.put(SETTINGS_KEYS.STATUS_SLEEP_MIN, safe.sleepMinHours);
    await this.prefs.put(SETTINGS_KEYS.STATUS_ALERT_WARN, safe.alertWarnCount);
    await this.prefs.put(SETTINGS_KEYS.STATUS_HINTS_ENABLED, safe.hintsEnabled);
    await this.prefs.flush();
  }

  /** Restores the defaults and returns them. */
  async reset(): Promise<ObservationRule> {
    const defaults = defaultObservationRule();
    await this.save(defaults);
    return defaults;
  }
}
