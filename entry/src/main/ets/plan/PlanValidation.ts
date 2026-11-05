import { mondayOf, parsePlanDate } from './PlanFactory';

/** Result of checking one goal draft before it is written. */
export interface PlanDraftCheck {
  ok: boolean;
  message: string;
}

/** Validates the goal form; the end date is optional but must be later than the first week. */
export function validatePlanDraft(title: string, startDate: string, targetDate: string): PlanDraftCheck {
  if (title.trim().length === 0) {
    return { ok: false, message: '请填写目标名称' };
  }
  if (!isPlanDate(startDate)) {
    return { ok: false, message: '起始日期格式应为 YYYY-MM-DD' };
  }
  const target = targetDate.trim();
  if (target.length > 0 && !isPlanDate(target)) {
    return { ok: false, message: '结束日期格式应为 YYYY-MM-DD，或留空' };
  }
  if (target.length > 0 && target <= mondayOf(startDate)) {
    return { ok: false, message: '结束日期需晚于起始日期' };
  }
  return { ok: true, message: '' };
}

/** True when the text is a real YYYY-MM-DD date. */
export function isPlanDate(value: string): boolean {
  if (value.length !== 10) {
    return false;
  }
  return !Number.isNaN(parsePlanDate(value).getTime());
}
