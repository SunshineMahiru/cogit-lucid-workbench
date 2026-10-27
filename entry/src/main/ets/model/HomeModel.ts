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
  totalPredictions: number;
  pendingPredictions: number;
  settledPredictions: number;
  hitRate: number;
}

const WEEK_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

export function todayLabel(): string {
  const now = new Date();
  return `${now.getMonth() + 1} 月 ${now.getDate()} 日 · 周${WEEK_LABELS[now.getDay()]}`;
}
