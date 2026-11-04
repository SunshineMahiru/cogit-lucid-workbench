import { DB_TABLES } from './DbConstants';

/** CREATE TABLE statements, executed in order on first open. */
export const TABLE_CREATE_SQLS: string[] = [
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.EVENT} (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    type TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    tags TEXT NOT NULL,
    level TEXT NOT NULL,
    related_decision_ids TEXT NOT NULL,
    related_relation_ids TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.DECISION} (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    background TEXT NOT NULL,
    options TEXT NOT NULL,
    choice TEXT NOT NULL,
    expected_outcome TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    related_event_ids TEXT NOT NULL,
    related_relation_ids TEXT NOT NULL,
    level TEXT NOT NULL,
    reviewed INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.RELATION} (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    trust_level TEXT NOT NULL,
    interaction_log TEXT NOT NULL,
    raw_material_test INTEGER NOT NULL,
    forbid_analysis INTEGER NOT NULL,
    level TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0,
    notes TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.PREDICTION} (
    id TEXT PRIMARY KEY,
    target TEXT NOT NULL,
    judgment TEXT NOT NULL,
    confidence INTEGER NOT NULL,
    reason TEXT NOT NULL,
    settlement_date TEXT NOT NULL,
    status TEXT NOT NULL,
    actual_result TEXT NOT NULL,
    hit INTEGER,
    version INTEGER NOT NULL,
    root_id TEXT NOT NULL DEFAULT '',
    level TEXT NOT NULL DEFAULT 'local_only',
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.ANCHOR} (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    source TEXT NOT NULL,
    sort_order INTEGER NOT NULL,
    level TEXT NOT NULL DEFAULT 'local_only'
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.STATUS_RECORD} (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    sleep_hours REAL NOT NULL,
    exercise_count INTEGER NOT NULL,
    alert_count INTEGER NOT NULL,
    note TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'local_only',
    deleted INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.REVIEW_RESULT} (
    id TEXT PRIMARY KEY,
    period TEXT NOT NULL,
    range_label TEXT NOT NULL,
    facts TEXT NOT NULL,
    interpretation TEXT NOT NULL,
    contradiction TEXT NOT NULL,
    next_action TEXT NOT NULL,
    anchor_ids TEXT NOT NULL,
    plan_id TEXT,
    plan_node_id TEXT,
    level TEXT NOT NULL DEFAULT 'local_only',
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.PLAN} (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    goal TEXT NOT NULL,
    project_id TEXT,
    start_date TEXT NOT NULL,
    status TEXT NOT NULL,
    is_primary INTEGER NOT NULL DEFAULT 0,
    level TEXT NOT NULL DEFAULT 'local_only',
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.PLAN_PROJECT} (
    id TEXT PRIMARY KEY,
    plan_id TEXT NOT NULL,
    name TEXT NOT NULL,
    goal TEXT NOT NULL,
    status TEXT NOT NULL,
    sort_order INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.PLAN_NODE} (
    id TEXT PRIMARY KEY,
    plan_id TEXT NOT NULL,
    project_id TEXT,
    week_index INTEGER NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    status TEXT NOT NULL,
    review_id TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.PLAN_ITEM} (
    id TEXT PRIMARY KEY,
    node_id TEXT NOT NULL,
    text TEXT NOT NULL,
    done INTEGER NOT NULL DEFAULT 0,
    carried_from TEXT,
    sort_order INTEGER NOT NULL,
    level TEXT NOT NULL DEFAULT 'local_only'
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.PLAN_LINK} (
    id TEXT PRIMARY KEY,
    plan_id TEXT NOT NULL,
    node_id TEXT,
    module TEXT NOT NULL,
    target_id TEXT NOT NULL,
    label TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`
];
