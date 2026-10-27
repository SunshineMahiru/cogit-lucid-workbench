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
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.ANCHOR} (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    source TEXT NOT NULL,
    sort_order INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS ${DB_TABLES.STATUS_RECORD} (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    sleep_hours REAL NOT NULL,
    exercise_count INTEGER NOT NULL,
    alert_count INTEGER NOT NULL,
    note TEXT NOT NULL
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
    created_at INTEGER NOT NULL
  )`
];
