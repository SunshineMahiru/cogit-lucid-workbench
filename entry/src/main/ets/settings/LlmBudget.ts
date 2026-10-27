/** Conservative price used for local accounting; adjust when the provider changes. */
export const COST_PER_1K_CHARS = 0.002;

/** Estimated cost for one call, rounded to four decimals. */
export function estimateCostYuan(inputChars: number, outputChars: number): number {
  const chars = Math.max(0, inputChars) + Math.max(0, outputChars);
  return Math.round(chars / 1000 * COST_PER_1K_CHARS * 10000) / 10000;
}

/** True when the next estimated call still fits the monthly cap. */
export function budgetAllows(budgetYuan: number, spentYuan: number, estimatedYuan: number): boolean {
  return budgetYuan > 0 && spentYuan + estimatedYuan <= budgetYuan;
}

/** Current month key used to reset the ledger. */
export function monthKey(now: number = Date.now()): string {
  const date = new Date(now);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}`;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
