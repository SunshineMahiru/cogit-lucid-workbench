import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { budgetAllows, monthKey } from './LlmBudget';

const STORE_NAME = 'cogit_llm_spend';
const KEY_MONTH = 'spend_month';
const KEY_SPENT = 'spend_yuan';

/** Monthly ledger; resets when the calendar month changes. */
export interface LlmSpend {
  month: string;
  spentYuan: number;
}

/** Persists the estimated LLM spend so the cap survives restarts. */
export class LlmSpendStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<LlmSpendStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new LlmSpendStore(prefs);
  }

  /** Returns the current month's spend, resetting stale months to zero. */
  async load(now: number = Date.now()): Promise<LlmSpend> {
    const current = monthKey(now);
    const storedMonth = await this.prefs.get(KEY_MONTH, '');
    const storedSpent = await this.prefs.get(KEY_SPENT, 0);
    if (storedMonth !== current) {
      return { month: current, spentYuan: 0 };
    }
    return {
      month: current,
      spentYuan: typeof storedSpent === 'number' ? storedSpent : 0
    };
  }

  /** Checks the cap before a request. */
  async canAfford(budgetYuan: number, estimatedYuan: number, now: number = Date.now()): Promise<boolean> {
    const state = await this.load(now);
    return budgetAllows(budgetYuan, state.spentYuan, estimatedYuan);
  }

  /** Adds one estimated cost and persists it. */
  async record(costYuan: number, now: number = Date.now()): Promise<void> {
    const state = await this.load(now);
    const next = Math.round((state.spentYuan + Math.max(0, costYuan)) * 10000) / 10000;
    await this.prefs.put(KEY_MONTH, state.month);
    await this.prefs.put(KEY_SPENT, next);
    await this.prefs.flush();
  }
}
