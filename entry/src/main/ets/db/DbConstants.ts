/** Table names for the relational store. */
export const DB_TABLES = {
  EVENT: 'event',
  DECISION: 'decision',
  RELATION: 'relation',
  PREDICTION: 'prediction',
  ANCHOR: 'anchor',
  STATUS_RECORD: 'status_record'
} as const;

/** Column names for the event table. */
export const EVENT_COLS = {
  ID: 'id',
  TITLE: 'title',
  CONTENT: 'content',
  TYPE: 'type',
  TIMESTAMP: 'timestamp',
  TAGS: 'tags',
  LEVEL: 'level',
  RELATED_DECISION_IDS: 'related_decision_ids',
  RELATED_RELATION_IDS: 'related_relation_ids'
} as const;

/** Column names for the decision table. */
export const DECISION_COLS = {
  ID: 'id',
  TITLE: 'title',
  BACKGROUND: 'background',
  OPTIONS: 'options',
  CHOICE: 'choice',
  EXPECTED_OUTCOME: 'expected_outcome',
  TIMESTAMP: 'timestamp',
  RELATED_EVENT_IDS: 'related_event_ids',
  RELATED_RELATION_IDS: 'related_relation_ids',
  LEVEL: 'level',
  REVIEWED: 'reviewed'
} as const;

/** Column names for the relation table. */
export const RELATION_COLS = {
  ID: 'id',
  NAME: 'name',
  TRUST_LEVEL: 'trust_level',
  INTERACTION_LOG: 'interaction_log',
  RAW_MATERIAL_TEST: 'raw_material_test',
  FORBID_ANALYSIS: 'forbid_analysis',
  LEVEL: 'level',
  NOTES: 'notes'
} as const;

/** Column names for the prediction table. */
export const PREDICTION_COLS = {
  ID: 'id',
  TARGET: 'target',
  JUDGMENT: 'judgment',
  CONFIDENCE: 'confidence',
  REASON: 'reason',
  SETTLEMENT_DATE: 'settlement_date',
  STATUS: 'status',
  ACTUAL_RESULT: 'actual_result',
  HIT: 'hit',
  VERSION: 'version',
  CREATED_AT: 'created_at'
} as const;

/** Column names for the anchor table. */
export const ANCHOR_COLS = {
  ID: 'id',
  TEXT: 'text',
  SOURCE: 'source',
  ORDER: 'order'
} as const;

/** Column names for the status record table. */
export const STATUS_RECORD_COLS = {
  ID: 'id',
  DATE: 'date',
  SLEEP_HOURS: 'sleep_hours',
  EXERCISE_COUNT: 'exercise_count',
  ALERT_COUNT: 'alert_count',
  NOTE: 'note'
} as const;
