import { SecurityLevel } from './SecurityLevel';

/**
 * 一等公民实体 · 决策（Decision）。
 * 记录一次决策：背景、选项、选择与预期结果，可被事件与关系引用，可被复盘。
 */
export interface Decision {
  id: string;
  title: string;
  /** 决策背景 */
  background: string;
  /** 备选选项 */
  options: string[];
  /** 最终选择 */
  choice: string;
  /** 预期结果 */
  expectedOutcome: string;
  /** 决策时间戳（毫秒） */
  timestamp: number;
  relatedEventIds: string[];
  relatedRelationIds: string[];
  /** 数据密级，默认 LOCAL_ONLY */
  level: SecurityLevel;
  /** 是否已完成复盘 */
  reviewed: boolean;
}
