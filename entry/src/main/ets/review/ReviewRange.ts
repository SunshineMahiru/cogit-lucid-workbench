import { ReviewPeriod } from '../model/ReviewPeriod';

/** Half-open date range for one review period, in milliseconds. */
export interface PeriodRange {
  start: number;
  /** Exclusive end */
  end: number;
  /** Short label such as 2026-10-26 ~ 2026-11-01 */
  label: string;
}

/** Returns the week (Monday based) or month range that contains now. */
export function rangeFor(period: ReviewPeriod, now: number): PeriodRange {
  const date = new Date(now);
  if (period === ReviewPeriod.MONTH) {
    const start = new Date(date.getFullYear(), date.getMonth(), 1);
    const next = new Date(date.getFullYear(), date.getMonth() + 1, 1);
    return {
      start: start.getTime(),
      end: next.getTime(),
      label: `${formatDate(start)} ~ ${formatDate(dayBefore(next))}`
    };
  }
  const weekday = date.getDay();
  const offset = weekday === 0 ? 6 : weekday - 1;
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate() - offset);
  const next = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 7);
  return {
    start: start.getTime(),
    end: next.getTime(),
    label: `${formatDate(start)} ~ ${formatDate(dayBefore(next))}`
  };
}

function dayBefore(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() - 1);
}

function formatDate(date: Date): string {
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${date.getFullYear()}-${month < 10 ? `0${month}` : `${month}`}-${day < 10 ? `0${day}` : `${day}`}`;
}
