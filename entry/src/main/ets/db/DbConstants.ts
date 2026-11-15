/** Table names for the relational store. */
export const DB_TABLES = {
  EVENT: 'event',
  DECISION: 'decision',
  RELATION: 'relation',
  PREDICTION: 'prediction',
  ANCHOR: 'anchor',
  STATUS_RECORD: 'status_record',
  REVIEW_RESULT: 'review_result',
  REVIEW_MATERIAL: 'review_material',
  PLAN: 'plan',
  PLAN_PROJECT: 'plan_project',
  PLAN_NODE: 'plan_node',
  PLAN_ITEM: 'plan_item',
  PLAN_LINK: 'plan_link',
  REQUEST_AUDIT: 'request_audit',
  EXPERIENCE_MATERIAL: 'experience_material',
  EVIDENCE_ITEM: 'evidence_item',
  COST_NOTE: 'cost_note'
} as const;

/**
 * Every table, children before parents, for operations that wipe the store.
 * Keep this list in sync with DB_TABLES; the fixture in `.test/check.js` asserts it.
 */
/**
 * Tables that carry a `level` column. Restore keeps their sealed rows in place while replacing
 * the rest; add a table here the moment it gains a security level.
 */
export const LEVELED_TABLES: string[] = [
  DB_TABLES.EVENT,
  DB_TABLES.DECISION,
  DB_TABLES.RELATION,
  DB_TABLES.PREDICTION,
  DB_TABLES.ANCHOR,
  DB_TABLES.STATUS_RECORD,
  DB_TABLES.REVIEW_RESULT,
  DB_TABLES.PLAN,
  DB_TABLES.PLAN_ITEM,
  DB_TABLES.EXPERIENCE_MATERIAL,
  DB_TABLES.EVIDENCE_ITEM
];

export const DB_TABLES_CHILD_FIRST: string[] = [
  DB_TABLES.REVIEW_MATERIAL,
  DB_TABLES.EXPERIENCE_MATERIAL,
  DB_TABLES.EVIDENCE_ITEM,
  DB_TABLES.COST_NOTE,
  DB_TABLES.REQUEST_AUDIT,
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
  DEPTH: 'depth',
  RELATED_DECISION_IDS: 'related_decision_ids',
  RELATED_RELATION_IDS: 'related_relation_ids',
  REVISION_OF: 'revision_of',
  VERSION: 'version',
  DELETED: 'deleted'
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
  REVIEWED: 'reviewed',
  DONE: 'done',
  KNOWN_CONDITIONS: 'known_conditions'
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
  CORRECTION: 'correction',
  CORRECTION_AT: 'correction_at',
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
  OUTCOME: 'outcome',
  SCOPE: 'scope',
  FALSIFICATION: 'falsification',
  UNKNOWNS: 'unknowns',
  REVISION_REASON: 'revision_reason',
  INVALIDATED: 'invalidated',
  PRESERVED: 'preserved',
  REPOSITIONED: 'repositioned',
  EVIDENCE_LEVEL: 'evidence_level',
  CREATED_AT: 'created_at'
} as const;

/** Column names for the anchor table. */
export const ANCHOR_COLS = {
  ID: 'id',
  TEXT: 'text',
  SOURCE: 'source',
  ORDER: 'sort_order',
  LEVEL: 'level',
  ROOT_ID: 'root_id',
  VERSION: 'version',
  STATUS: 'status',
  CONTEXT: 'context',
  REVISION_REASON: 'revision_reason',
  SYNTHETIC: 'synthetic'
} as const;

/** Column names for the status record table. */
export const STATUS_RECORD_COLS = {
  ID: 'id',
  DATE: 'date',
  SLEEP_HOURS: 'sleep_hours',
  EXERCISE_COUNT: 'exercise_count',
  ALERT_COUNT: 'alert_count',
  NOTE: 'note',
  BODY_SIGNALS: 'body_signals',
  FUNCTION_STATE: 'function_state',
  EMOTION: 'emotion',
  ENVIRONMENT: 'environment',
  CAPACITY: 'capacity',
  FUNCTION_GAIN: 'function_gain',
  COST_PAID: 'cost_paid',
  UNKNOWN_READINGS: 'unknown_readings',
  CORRECTED_AT: 'corrected_at',
  REVISIONS: 'revisions',
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
  PAYLOAD: 'payload',
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
  PAUSE_REASON: 'pause_reason',
  RESUME_AT: 'resume_at',
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
  LEVEL: 'level',
  DISPOSITION: 'disposition',
  DISCARD_REASON: 'discard_reason'
} as const;

/** Column names for the request audit table. */
export const REQUEST_AUDIT_COLS = {
  ID: 'id',
  PROVIDER: 'provider',
  HOST: 'host',
  MATERIAL_IDS: 'material_ids',
  LEVELS: 'levels',
  CHARS: 'chars',
  CONFIRMED: 'confirmed',
  FELL_BACK: 'fell_back',
  CREATED_AT: 'created_at'
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


/** Column names for the experience material table. */
export const MATERIAL_COLS = {
  ID: 'id',
  EVENT_ID: 'event_id',
  KIND: 'kind',
  FORM: 'form',
  TEXT: 'text',
  OBSERVED_AT: 'observed_at',
  SOURCE: 'source',
  SOURCE_STANCE: 'source_stance',
  INTERACTION_SOURCE: 'interaction_source',
  LEVEL: 'level',
  REVISION_OF: 'revision_of',
  DELETED: 'deleted',
  CREATED_AT: 'created_at'
} as const;

/** Column names for the evidence table. */
export const EVIDENCE_COLS = {
  ID: 'id',
  TARGET_TYPE: 'target_type',
  TARGET_ID: 'target_id',
  SOURCE_TYPE: 'source_type',
  NOTE: 'note',
  EFFECT: 'effect',
  LEVEL: 'level',
  ZONE: 'zone',
  CREATED_AT: 'created_at'
} as const;

/** Column names for the material snapshots a review cited. */
export const REVIEW_MATERIAL_COLS = {
  REVIEW_ID: 'review_id',
  MATERIAL_ID: 'material_id',
  KIND_SNAPSHOT: 'kind_snapshot',
  TEXT_SNAPSHOT: 'text_snapshot',
  SOURCE_SNAPSHOT: 'source_snapshot',
  LEVEL_SNAPSHOT: 'level_snapshot',
  ZONE: 'zone',
  CITED_AT: 'cited_at',
  SNAPSHOT_MISSING: 'snapshot_missing'
} as const;

/** Column names for the cost table. */
export const COST_COLS = {
  ID: 'id',
  REVIEW_ID: 'review_id',
  DIMENSION: 'dimension',
  TEXT: 'text',
  BEARABLE: 'bearable',
  CREATED_AT: 'created_at'
} as const;
