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
  )`
];
