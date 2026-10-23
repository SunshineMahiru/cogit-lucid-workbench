/**
 * 实体 ID 与引用类型别名。
 * 用语义化别名区分不同实体的 ID，避免裸 string 混用。
 */
export type EntityId = string;

export type EventId = EntityId;
export type DecisionId = EntityId;
export type RelationId = EntityId;
export type PredictionId = EntityId;
export type AnchorId = EntityId;
export type StatusRecordId = EntityId;
