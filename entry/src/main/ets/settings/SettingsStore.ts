import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppSettings, LlmProvider, defaultAppSettings, sanitizeAppSettings } from './AppSettings';
import { SETTINGS_KEYS, SETTINGS_STORE_NAME } from './SettingsKeys';
import { SecretStore } from './SecretStore';

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
    let baseUrlValue = typeof baseUrl === 'string' ? baseUrl : defaults.llmBaseUrl;
    if (baseUrlValue === 'http://127.0.0.1:4523/v1') {
      baseUrlValue = 'http://localhost:4523/v1';
    }
    const storedApiKey = await this.prefs.get(SETTINGS_KEYS.LLM_API_KEY, defaults.llmApiKey);
    let apiKey = await SecretStore.load();
    if (apiKey.length === 0 && typeof storedApiKey === 'string' && storedApiKey.length > 0) {
      // Migrate the old plaintext value once, then remove it from Preferences.
      const migrated = await SecretStore.save(storedApiKey);
      if (migrated) {
        await this.prefs.put(SETTINGS_KEYS.LLM_API_KEY, '');
        await this.prefs.flush();
        apiKey = storedApiKey;
      }
    }
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
      llmBaseUrl: baseUrlValue,
      llmApiKey: typeof apiKey === 'string' ? apiKey : defaults.llmApiKey,
      llmModel: typeof model === 'string' ? model : defaults.llmModel,
      llmMonthlyBudget: typeof budget === 'number' ? budget : defaults.llmMonthlyBudget,
      defaultLevel: typeof level === 'string' ? level as SecurityLevel : defaults.defaultLevel
    });
  }

  /** Persists sanitized options and flushes them to disk. */
  async save(settings: AppSettings): Promise<void> {
    const safe = sanitizeAppSettings(settings);
    const stored = await SecretStore.save(safe.llmApiKey);
    if (!stored) {
      throw new Error('无法写入系统密钥库');
    }
    await this.prefs.put(SETTINGS_KEYS.LLM_ENABLED, safe.llmEnabled);
    await this.prefs.put(SETTINGS_KEYS.LLM_PROVIDER, safe.llmProvider);
    await this.prefs.put(SETTINGS_KEYS.LLM_BASE_URL, safe.llmBaseUrl);
    await this.prefs.put(SETTINGS_KEYS.LLM_API_KEY, '');
    await this.prefs.put(SETTINGS_KEYS.LLM_MODEL, safe.llmModel);
    await this.prefs.put(SETTINGS_KEYS.LLM_MONTHLY_BUDGET, safe.llmMonthlyBudget);
    await this.prefs.put(SETTINGS_KEYS.DEFAULT_LEVEL, safe.defaultLevel);
    await this.prefs.flush();
  }
}
