/**
 * One threshold for every "not enough samples" hint in the app. It is a display convention,
 * not a scientific boundary, and the copy that uses it says so.
 */
export const SAMPLE_FLOOR = 10;

/** True when a sample is large enough to read a rate from it. */
export function hasEnoughSamples(count: number): boolean {
  return count >= SAMPLE_FLOOR;
}

/** One sentence for charts and cards; keeps the wording identical everywhere. */
export function sampleHint(count: number): string {
  return hasEnoughSamples(count) ?
    `样本 ${count} 条` :
    `样本 ${count} 条，不足 ${SAMPLE_FLOOR} 条，仅作观察`;
}
