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
  )`
];
