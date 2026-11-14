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

/** Human label for one outcome; empty input reads as 未结算. */
export function outcomeLabel(outcome: string): string {
  if (outcome === 'hold') {
    return '成立';
  }
  if (outcome === 'fail') {
    return '未成立';
  }
  if (outcome === 'partial') {
    return '部分成立';
  }
  if (outcome === 'insufficient') {
    return '证据不足';
  }
  if (outcome === 'undecidable') {
    return '无法判断';
  }
  return '未结算';
}
