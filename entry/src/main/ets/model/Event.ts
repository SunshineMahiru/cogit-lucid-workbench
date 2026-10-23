import { SecurityLevel } from './SecurityLevel';

/**
 * 一等公民实体 · 事件（Event）。
 * 记录一件发生的事，可被决策与关系引用。
 */
export interface Event {
  id: string;
  title: string;
  content: string;
  /** 分类标签，如「人际」「身体」「情绪」 */
  type: string;
  /** 发生时间戳（毫秒） */
  timestamp: number;
  tags: string[];
  /** 数据密级，默认 LOCAL_ONLY */
  level: SecurityLevel;
  relatedDecisionIds: string[];
  relatedRelationIds: string[];
}
