/**
 * 价值锚点（Anchor）。
 * 用户预置的「北极星句段库」，只读；复盘分析必须对照锚点。
 */
export interface Anchor {
  id: string;
  /** 北极星句段 */
  text: string;
  /** 出处 */
  source: string;
  /** 排序（只读区） */
  order: number;
}
