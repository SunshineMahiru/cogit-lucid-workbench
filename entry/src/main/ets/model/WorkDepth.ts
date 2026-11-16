/** How much attention one session or one plan is meant to take. */
export type WorkDepth = 'quick' | 'normal' | 'deep';

/** Every depth in display order. */
export const WORK_DEPTHS: WorkDepth[] = ['quick', 'normal', 'deep'];

/** Narrows a stored value; absent or unknown values read as normal. */
export function toWorkDepth(value: string | undefined): WorkDepth {
  if (value === 'quick' || value === 'deep') {
    return value;
  }
  return 'normal';
}

/** Human label for one depth. */
export function workDepthText(value: WorkDepth): string {
  if (value === 'quick') {
    return '快速';
  }
  if (value === 'deep') {
    return '深入';
  }
  return '普通';
}
