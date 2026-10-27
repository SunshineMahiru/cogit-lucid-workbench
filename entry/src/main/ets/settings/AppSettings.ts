import { SecurityLevel } from '../model/SecurityLevel';

/** Offline template, local mock or an OpenAI-compatible endpoint. */
export type LlmProvider = 'template' | 'mock' | 'model';

/** User options persisted through Preferences. */
export interface AppSettings {
  /** Legacy flag kept for compatibility; derived from llmProvider */
  llmEnabled: boolean;
  llmProvider: LlmProvider;
  /** Base URL for the OpenAI-compatible endpoint, without /chat/completions */
  llmBaseUrl: string;
  /** Optional bearer token; stored locally only */
  llmApiKey: string;
  /** Model identifier used when the LLM switch is on */
  llmModel: string;
  /** Hard monthly budget in yuan; zero disables paid calls */
  llmMonthlyBudget: number;
  /** Security level assigned to newly captured records */
  defaultLevel: SecurityLevel;
}

/** Upper bound accepted for the monthly budget, in yuan. */
export const MAX_MONTHLY_BUDGET = 500;

/** Options used before the user changes anything. */
export const DEFAULT_SETTINGS: AppSettings = {
  llmEnabled: false,
  llmProvider: 'template',
  llmBaseUrl: 'http://127.0.0.1:4523/v1',
  llmApiKey: '',
  llmModel: 'glm-4.7-flash',
  llmMonthlyBudget: 30,
  defaultLevel: SecurityLevel.LOCAL_ONLY
};

/** Returns a fresh copy of the defaults so callers cannot mutate the shared constant. */
export function defaultAppSettings(): AppSettings {
  return {
    llmEnabled: DEFAULT_SETTINGS.llmEnabled,
    llmProvider: DEFAULT_SETTINGS.llmProvider,
    llmBaseUrl: DEFAULT_SETTINGS.llmBaseUrl,
    llmApiKey: DEFAULT_SETTINGS.llmApiKey,
    llmModel: DEFAULT_SETTINGS.llmModel,
    llmMonthlyBudget: DEFAULT_SETTINGS.llmMonthlyBudget,
    defaultLevel: DEFAULT_SETTINGS.defaultLevel
  };
}

/** Clamps persisted values back into their valid ranges before use. */
export function sanitizeAppSettings(settings: AppSettings): AppSettings {
  const provider = isProvider(settings.llmProvider) ? settings.llmProvider :
    (settings.llmEnabled ? 'mock' : 'template');
  const model = settings.llmModel.trim();
  const baseUrl = typeof settings.llmBaseUrl === 'string' ? settings.llmBaseUrl.trim() : DEFAULT_SETTINGS.llmBaseUrl;
  const apiKey = typeof settings.llmApiKey === 'string' ? settings.llmApiKey.trim() : DEFAULT_SETTINGS.llmApiKey;
  const budget = Number.isFinite(settings.llmMonthlyBudget) ?
    Math.floor(settings.llmMonthlyBudget) : DEFAULT_SETTINGS.llmMonthlyBudget;
  return {
    llmEnabled: provider !== 'template',
    llmProvider: provider,
    llmBaseUrl: baseUrl.length > 0 ? baseUrl : DEFAULT_SETTINGS.llmBaseUrl,
    llmApiKey: apiKey,
    llmModel: model.length > 0 ? model : DEFAULT_SETTINGS.llmModel,
    llmMonthlyBudget: Math.min(Math.max(budget, 0), MAX_MONTHLY_BUDGET),
    defaultLevel: isSecurityLevel(settings.defaultLevel) ? settings.defaultLevel : DEFAULT_SETTINGS.defaultLevel
  };
}

function isProvider(value: LlmProvider): boolean {
  return value === 'template' || value === 'mock' || value === 'model';
}

function isSecurityLevel(value: SecurityLevel): boolean {
  return value === SecurityLevel.ANALYZABLE || value === SecurityLevel.LOCAL_ONLY ||
    value === SecurityLevel.SEALED;
}