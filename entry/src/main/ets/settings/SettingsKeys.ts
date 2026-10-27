/** Preference store name holding the user options. */
export const SETTINGS_STORE_NAME = 'cogit_settings';

/** Keys written into the settings store; values stay stable because they persist across upgrades. */
export const SETTINGS_KEYS = {
  LLM_ENABLED: 'llm_enabled',
  LLM_PROVIDER: 'llm_provider',
  LLM_BASE_URL: 'llm_base_url',
  LLM_API_KEY: 'llm_api_key',
  LLM_MODEL: 'llm_model',
  LLM_MONTHLY_BUDGET: 'llm_monthly_budget',
  DEFAULT_LEVEL: 'default_level'
} as const;
