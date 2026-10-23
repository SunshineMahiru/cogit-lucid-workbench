/** Display data structures and sample data for the home page. */

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

export const MOCK_READINGS: BodyReading[] = [
  { label: '睡眠', value: '7.5', unit: ' 小时' },
  { label: '运动', value: '1', unit: ' 次' },
  { label: '速记', value: '6', unit: ' 条' }
];

export const MOCK_PREDICTIONS: PredictionItem[] = [
  { id: 'p1', title: '本周内完成记录层建表与读写封装', confidence: 70, dueDate: '10 月 26 日结算' },
  { id: 'p2', title: '答辩前把首页的加载与空态调通', confidence: 45, dueDate: '11 月 02 日结算' },
  { id: 'p3', title: '每日速记连续七天不断', confidence: 60, dueDate: '10 月 30 日结算' }
];

const WEEK_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

export function todayLabel(): string {
  const now = new Date();
  return `${now.getMonth() + 1} 月 ${now.getDate()} 日 · 周${WEEK_LABELS[now.getDay()]}`;
}
