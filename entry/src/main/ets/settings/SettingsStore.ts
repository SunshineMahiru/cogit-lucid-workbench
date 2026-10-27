import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppSettings, LlmProvider, defaultAppSettings, sanitizeAppSettings } from './AppSettings';
import { SETTINGS_KEYS, SETTINGS_STORE_NAME } from './SettingsKeys';

/** Reads and writes user options through Preferences. */
export class SettingsStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  /** Opens the settings store; values persist across launches. */
  static async open(context: common.Context): Promise<SettingsStore> {
    const prefs = await preferences.getPreferences(context, { name: SETTINGS_STORE_NAME });
    return new SettingsStore(prefs);
  }

  /** Returns stored options, falling back to defaults for missing or malformed keys. */
  async load(): Promise<AppSettings> {
    const defaults = defaultAppSettings();
    const enabled = await this.prefs.get(SETTINGS_KEYS.LLM_ENABLED, defaults.llmEnabled);
    const provider = await this.prefs.get(SETTINGS_KEYS.LLM_PROVIDER, defaults.llmProvider);
    const baseUrl = await this.prefs.get(SETTINGS_KEYS.LLM_BASE_URL, defaults.llmBaseUrl);
    const apiKey = await this.prefs.get(SETTINGS_KEYS.LLM_API_KEY, defaults.llmApiKey);
    const model = await this.prefs.get(SETTINGS_KEYS.LLM_MODEL, defaults.llmModel);
    const budget = await this.prefs.get(SETTINGS_KEYS.LLM_MONTHLY_BUDGET, defaults.llmMonthlyBudget);
    const level = await this.prefs.get(SETTINGS_KEYS.DEFAULT_LEVEL, defaults.defaultLevel);
    let providerValue = typeof provider === 'string' ? provider as LlmProvider : defaults.llmProvider;
    // Legacy installs only had llm_enabled; preserve "on" as the local mock provider.
    if (enabled === true && providerValue === 'template') {
      providerValue = 'mock';
    }
    return sanitizeAppSettings({
      llmEnabled: typeof enabled === 'boolean' ? enabled : defaults.llmEnabled,
      llmProvider: providerValue,
      llmBaseUrl: typeof baseUrl === 'string' ? baseUrl : defaults.llmBaseUrl,
      llmApiKey: typeof apiKey === 'string' ? apiKey : defaults.llmApiKey,
      llmModel: typeof model === 'string' ? model : defaults.llmModel,
      llmMonthlyBudget: typeof budget === 'number' ? budget : defaults.llmMonthlyBudget,
      defaultLevel: typeof level === 'string' ? level as SecurityLevel : defaults.defaultLevel
    });
  }

  /** Persists sanitized options and flushes them to disk. */
  async save(settings: AppSettings): Promise<void> {
    const safe = sanitizeAppSettings(settings);
    await this.prefs.put(SETTINGS_KEYS.LLM_ENABLED, safe.llmEnabled);
    await this.prefs.put(SETTINGS_KEYS.LLM_PROVIDER, safe.llmProvider);
    await this.prefs.put(SETTINGS_KEYS.LLM_BASE_URL, safe.llmBaseUrl);
    await this.prefs.put(SETTINGS_KEYS.LLM_API_KEY, safe.llmApiKey);
    await this.prefs.put(SETTINGS_KEYS.LLM_MODEL, safe.llmModel);
    await this.prefs.put(SETTINGS_KEYS.LLM_MONTHLY_BUDGET, safe.llmMonthlyBudget);
    await this.prefs.put(SETTINGS_KEYS.DEFAULT_LEVEL, safe.defaultLevel);
    await this.prefs.flush();
  }
}
