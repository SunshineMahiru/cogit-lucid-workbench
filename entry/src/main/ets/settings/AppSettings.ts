import { SecurityLevel } from '../model/SecurityLevel';

/** User options persisted through Preferences. */
export interface AppSettings {
  /** When false, reviews run on offline templates without a network call */
  llmEnabled: boolean;
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
  llmModel: 'glm-4.7-flash',
  llmMonthlyBudget: 30,
  defaultLevel: SecurityLevel.LOCAL_ONLY
};

/** Returns a fresh copy of the defaults so callers cannot mutate the shared constant. */
export function defaultAppSettings(): AppSettings {
  return {
    llmEnabled: DEFAULT_SETTINGS.llmEnabled,
    llmModel: DEFAULT_SETTINGS.llmModel,
    llmMonthlyBudget: DEFAULT_SETTINGS.llmMonthlyBudget,
    defaultLevel: DEFAULT_SETTINGS.defaultLevel
  };
}

/** Clamps persisted values back into their valid ranges before use. */
export function sanitizeAppSettings(settings: AppSettings): AppSettings {
  const model = settings.llmModel.trim();
  const budget = Number.isFinite(settings.llmMonthlyBudget) ?
    Math.floor(settings.llmMonthlyBudget) : DEFAULT_SETTINGS.llmMonthlyBudget;
  return {
    llmEnabled: settings.llmEnabled,
    llmModel: model.length > 0 ? model : DEFAULT_SETTINGS.llmModel,
    llmMonthlyBudget: Math.min(Math.max(budget, 0), MAX_MONTHLY_BUDGET),
    defaultLevel: isSecurityLevel(settings.defaultLevel) ? settings.defaultLevel : DEFAULT_SETTINGS.defaultLevel
  };
}

function isSecurityLevel(value: SecurityLevel): boolean {
  return value === SecurityLevel.ANALYZABLE || value === SecurityLevel.LOCAL_ONLY ||
    value === SecurityLevel.SEALED;
}
