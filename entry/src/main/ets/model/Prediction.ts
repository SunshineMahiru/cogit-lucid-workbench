import { PredictionStatus } from './PredictionStatus';

/**
 * 预测日志（Prediction Log）。
 * 判断事前落盘、禁止修改（版本追加式）、到期结算、统计命中率——本产品的核心亮点。
 */
export interface Prediction {
  id: string;
  /** 预测对象 / 命题 */
  target: string;
  /** 判断（含数字与期限） */
  judgment: string;
  /** 置信度 0-100 */
  confidence: number;
  /** 依据 */
  reason: string;
  /** 结算日期（合同式写死） */
  settlementDate: string;
  status: PredictionStatus;
  /** 实际结果（结算时填写） */
  actualResult: string;
  /** 命中与否，未结算时为 null */
  hit: boolean | null;
  /** 版本号：禁止修改已提交预测，修改走版本追加 */
  version: number;
  /** 落盘时间戳（毫秒） */
  createdAt: number;
}
