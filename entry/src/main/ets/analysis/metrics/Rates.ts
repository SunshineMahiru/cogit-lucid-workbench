/** Rounded hit rate over settled samples, in percent; 0 when there is no sample. */
export function hitRatePercent(hits: number, settled: number): number {
  return settled > 0 ? Math.round(hits / settled * 100) : 0;
}