/**
 * On-device heuristic for suggesting subtraction mode: interpretation-heavy
 * writing, frequent prompt refusals, or late-night writing.
 *
 * This is a heuristic and may misjudge. The user can turn it off in one step.
 * Leaving the mode is handled by the UI at the point of writing scene or
 * feeling, not by this function.
 */

/** One scheduled writing sample; kind is scene, feeling, interpretation, or other. */
export interface WriteSample {
  kind: string;
  chars: number;
  hour: number;
}

/** Prompt exposure counters: how many prompts were shown and refused. */
export interface PromptStats {
  shown: number;
  refused: number;
}

/** Input for the subtraction-mode decision. */
export interface SubtractionInput {
  writes: WriteSample[];
  prompts: PromptStats;
}

/** Returns true when the writing pattern suggests subtraction mode. */
export function shouldEnterSubtraction(input: SubtractionInput): boolean {
  const writes = input.writes;
  if (writes.length === 0 && input.prompts.shown === 0) {
    return false;
  }
  let sceneFeelingChars = 0;
  let interpretationChars = 0;
  for (let i = 0; i < writes.length; i += 1) {
    const sample = writes[i];
    if (sample.kind === 'scene' || sample.kind === 'feeling') {
      sceneFeelingChars += sample.chars;
    } else if (sample.kind === 'interpretation') {
      interpretationChars += sample.chars;
    }
  }
  let nightWrites = 0;
  for (let i = 0; i < writes.length; i += 1) {
    const hour = writes[i].hour;
    if (hour >= 23 || hour < 5) {
      nightWrites += 1;
    }
  }
  const interpRatio = interpretationChars / Math.max(1, sceneFeelingChars);
  const refusalRate = input.prompts.refused / Math.max(1, input.prompts.shown);
  const nightRatio = nightWrites / Math.max(1, writes.length);
  return interpRatio >= 1.5 || refusalRate >= 0.6 || nightRatio >= 0.5;
}