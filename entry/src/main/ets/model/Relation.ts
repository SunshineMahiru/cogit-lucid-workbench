import { SecurityLevel } from './SecurityLevel';
import { TrustLevel } from './TrustLevel';

/** 互动日志：一条与某人的互动记录 */
export interface InteractionLog {
  timestamp: number;
  content: string;
}

/**
 * 一等公民实体 · 关系（Relation）。
 * 记录与他者的关系：信任分层、互动日志、未加工材料测试标记、禁析开关。
 */
export interface Relation {
  id: string;
  /** 脱敏化名，不存真实姓名 */
  name: string;
  /** 信任分层：友善 / 真诚 / 透明 */
  trustLevel: TrustLevel;
  interactionLog: InteractionLog[];
  /** 未加工材料测试标记：此人是否接住过混乱态原始文本 */
  rawMaterialTest: boolean;
  /** 禁析开关：闲逛态对象的互动记录，复盘 Agent 拒绝生成动机分析 */
  forbidAnalysis: boolean;
  /** 数据密级，默认 LOCAL_ONLY（关系层的人名默认仅本地） */
  level: SecurityLevel;
  notes: string;
}
