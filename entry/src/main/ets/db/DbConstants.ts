/** Table names for the relational store. */
export const DB_TABLES = {
  EVENT: 'event',
  DECISION: 'decision',
  RELATION: 'relation',
  PREDICTION: 'prediction',
  ANCHOR: 'anchor',
  STATUS_RECORD: 'status_record',
  REVIEW_RESULT: 'review_result',
  PLAN: 'plan',
  PLAN_PROJECT: 'plan_project',
  PLAN_NODE: 'plan_node',
  PLAN_ITEM: 'plan_item',
  PLAN_LINK: 'plan_link'
} as const;

/**
 * Every table, children before parents, for operations that wipe the store.
 * Keep this list in sync with DB_TABLES; the fixture in `.test/check.js` asserts it.
 */
export const DB_TABLES_CHILD_FIRST: string[] = [
  DB_TABLES.PLAN_LINK,
  DB_TABLES.PLAN_ITEM,
  DB_TABLES.PLAN_NODE,
  DB_TABLES.PLAN_PROJECT,
  DB_TABLES.PLAN,
  DB_TABLES.EVENT,
  DB_TABLES.DECISION,
  DB_TABLES.RELATION,
  DB_TABLES.PREDICTION,
  DB_TABLES.ANCHOR,
  DB_TABLES.STATUS_RECORD,
  DB_TABLES.REVIEW_RESULT
];

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
  DELETED: 'deleted',
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
  ROOT_ID: 'root_id',
  LEVEL: 'level',
  CREATED_AT: 'created_at'
} as const;

/** Column names for the anchor table. */
export const ANCHOR_COLS = {
  ID: 'id',
  TEXT: 'text',
  SOURCE: 'source',
  ORDER: 'sort_order',
  LEVEL: 'level'
} as const;

/** Column names for the status record table. */
export const STATUS_RECORD_COLS = {
  ID: 'id',
  DATE: 'date',
  SLEEP_HOURS: 'sleep_hours',
  EXERCISE_COUNT: 'exercise_count',
  ALERT_COUNT: 'alert_count',
  NOTE: 'note',
  LEVEL: 'level',
  DELETED: 'deleted'
} as const;

/** Column names for the review result table. */
export const REVIEW_COLS = {
  ID: 'id',
  PERIOD: 'period',
  RANGE_LABEL: 'range_label',
  FACTS: 'facts',
  INTERPRETATION: 'interpretation',
  CONTRADICTION: 'contradiction',
  ACTION: 'next_action',
  ANCHOR_IDS: 'anchor_ids',
  PLAN_ID: 'plan_id',
  PLAN_NODE_ID: 'plan_node_id',
  LEVEL: 'level',
  CREATED_AT: 'created_at'
} as const;

/** Column names for the plan goal table. */
export const PLAN_COLS = {
  ID: 'id',
  TITLE: 'title',
  GOAL: 'goal',
  PROJECT_ID: 'project_id',
  START_DATE: 'start_date',
  TARGET_DATE: 'target_date',
  STATUS: 'status',
  IS_PRIMARY: 'is_primary',
  LEVEL: 'level',
  CREATED_AT: 'created_at'
} as const;

/** Column names for the optional plan project table. */
export const PLAN_PROJECT_COLS = {
  ID: 'id',
  PLAN_ID: 'plan_id',
  NAME: 'name',
  GOAL: 'goal',
  STATUS: 'status',
  SORT_ORDER: 'sort_order'
} as const;

/** Column names for the seven-day node table. */
export const PLAN_NODE_COLS = {
  ID: 'id',
  PLAN_ID: 'plan_id',
  PROJECT_ID: 'project_id',
  WEEK_INDEX: 'week_index',
  START_DATE: 'start_date',
  END_DATE: 'end_date',
  STATUS: 'status',
  REVIEW_ID: 'review_id'
} as const;

/** Column names for the checklist item table. */
export const PLAN_ITEM_COLS = {
  ID: 'id',
  NODE_ID: 'node_id',
  TEXT: 'text',
  DONE: 'done',
  CARRIED_FROM: 'carried_from',
  SORT_ORDER: 'sort_order',
  LEVEL: 'level'
} as const;

/** Column names for the record link table. */
export const PLAN_LINK_COLS = {
  ID: 'id',
  PLAN_ID: 'plan_id',
  NODE_ID: 'node_id',
  MODULE: 'module',
  TARGET_ID: 'target_id',
  LABEL: 'label',
  CREATED_AT: 'created_at'
} as const;
