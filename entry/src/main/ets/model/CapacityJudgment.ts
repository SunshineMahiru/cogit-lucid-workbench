/** The author's own reading of what today's state leaves them able to do. */
export type CapacityJudgment = '' | 'bearable' | 'limited' | 'pause' | 'unknown';

/** Options in display order; the system never preselects one from the numbers. */
export const CAPACITY_OPTIONS: CapacityJudgment[] = ['bearable', 'limited', 'pause', 'unknown'];

/** Returns the label shown for one judgment. */
export function capacityText(value: CapacityJudgment): string {
  if (value === 'bearable') {
    return '可以承受';
  }
  if (value === 'limited') {
    return '需要限量';
  }
  if (value === 'pause') {
    return '需要暂停';
  }
  if (value === 'unknown') {
    return '无法判断';
  }
  return '未填写';
}

/** Narrows a stored string back into the allowed set. */
export function isCapacityJudgment(value: string): boolean {
  return value === 'bearable' || value === 'limited' || value === 'pause' || value === 'unknown';
}

/** Normalizes a stored value; anything unknown becomes "not filled in". */
export function toCapacityJudgment(value: string): CapacityJudgment {
  return isCapacityJudgment(value) ? value as CapacityJudgment : '';
}
