/** Settlement result of one prediction; the first two feed the binary hit rate. */
export type PredictionOutcome = 'hold' | 'fail' | 'partial' | 'insufficient' | 'undecidable' | '';

/** Empty value, kept as a named constant so callers do not spell the literal. */
export const NO_OUTCOME: PredictionOutcome = '';

/** Outcomes that count toward the binary hit rate. */
export function isBinaryOutcome(outcome: PredictionOutcome): boolean {
  return outcome === 'hold' || outcome === 'fail';
}

/** Outcomes that stay out of the binary denominator but are shown on their own. */
export function isNonBinaryOutcome(outcome: PredictionOutcome): boolean {
  return outcome === 'partial' || outcome === 'insufficient' || outcome === 'undecidable';
}

/** Maps a record settled before outcomes existed; unknown values stay empty. */
export function outcomeFromLegacy(hit: boolean | null): PredictionOutcome {
  if (hit === true) {
    return 'hold';
  }
  if (hit === false) {
    return 'fail';
  }
  return NO_OUTCOME;
}
