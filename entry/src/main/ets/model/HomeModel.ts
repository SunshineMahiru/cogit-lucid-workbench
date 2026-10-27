/** Display data structures for the home page. */

export interface BodyReading {
  label: string;
  value: string;
  unit: string;
}

export interface PredictionItem {
  id: string;
  title: string;
  confidence: number;
  dueDate: string;
}

export interface HomeSummary {
  totalNotes: number;
  /** Notes captured today, paired with the total on the module tile */
  todayNotes: number;
  totalPredictions: number;
  pendingPredictions: number;
  settledPredictions: number;
  hitRate: number;
  /** Decisions captured but not reviewed yet */
  unreviewedDecisions: number;
  totalAnchors: number;
  totalRelations: number;
}

/** A dashboard tile: the route it opens plus its live summary line. */
export interface HomeModule {
  route: string;
  icon: string;
  title: string;
  summary: string;
}

/** Placeholder shown when a rate has no settled records behind it. */
export const NO_RATE_TEXT = '—';

/** Formats the hit rate, falling back to a placeholder until something is settled. */
export function formatHitRate(hitRate: number, settledCount: number): string {
  return settledCount > 0 ? `${hitRate}%` : NO_RATE_TEXT;
}

/** Caption under the hit rate, carrying the sample size so a small sample stays visible. */
export function hitRateCaption(settledCount: number): string {
  return settledCount > 0 ? `命中率 · ${settledCount} 条` : '命中率';
}

/** Note tile summary: today's captures against the all-time total. */
export function formatNoteCount(todayCount: number, totalCount: number): string {
  return `今日 ${todayCount} · 共 ${totalCount}`;
}

const WEEK_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

export function todayLabel(): string {
  const now = new Date();
  return `${now.getMonth() + 1} 月 ${now.getDate()} 日 · 周${WEEK_LABELS[now.getDay()]}`;
}
