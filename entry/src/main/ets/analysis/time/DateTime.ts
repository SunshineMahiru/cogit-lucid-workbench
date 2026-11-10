/** Local date as YYYY-MM-DD. */
export function formatDate(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/** Local clock as HH:mm. */
export function formatClock(timestamp: number): string {
  const date = new Date(timestamp);
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

/** Local month and day with clock as MM-DD HH:mm. */
export function formatMonthDayTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ${formatClock(timestamp)}`;
}

/** Local date and clock as YYYY-MM-DD HH:mm. */
export function formatDateTime(timestamp: number): string {
  return `${formatDate(timestamp)} ${formatClock(timestamp)}`;
}

/** Local date N days after now as YYYY-MM-DD. */
export function addDaysToDate(now: number, days: number): string {
  const date = new Date(now);
  date.setDate(date.getDate() + days);
  return formatDate(date.getTime());
}

/** True when both timestamps fall on the same local calendar day. */
export function isSameDay(left: number, right: number): boolean {
  const leftDate = new Date(left);
  const rightDate = new Date(right);
  return leftDate.getFullYear() === rightDate.getFullYear() &&
    leftDate.getMonth() === rightDate.getMonth() &&
    leftDate.getDate() === rightDate.getDate();
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}