/**
 * 预测日志状态：未结算 → 已结算。
 */
export enum PredictionStatus {
  /** 未结算：判断已落盘，尚未到期对账 */
  PENDING = 'pending',
  /** 已结算：到期已对账，记录了实际结果与命中与否 */
  SETTLED = 'settled'
}
