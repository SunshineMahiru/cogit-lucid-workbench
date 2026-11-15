/** Row-level rules for the portable backup; kept apart from the file and picker code. */

import { SecurityLevel } from '../model/SecurityLevel';
import { DB_TABLES } from '../db/DbConstants';
import { RecordState, isExportable, isLive } from '../policy/DeletionPolicy';

/**
 * Reads the state a row carries into the delete policy. A live row states its level in `level`;
 * a review material snapshot has no level column and stores it in `level_snapshot`.
 */
export function rowState(row: Record<string, string | null>): RecordState {
  const level = readLevel(row.level) ?? readLevel(row.level_snapshot) ?? SecurityLevel.LOCAL_ONLY;
  return { deleted: readDeleted(row.deleted), level: level };
}

/** A row carries sealed content when its level column says so. */
export function isSealedRow(row: Record<string, string | null>): boolean {
  return rowState(row).level === SecurityLevel.SEALED;
}

/** Soft-deleted rows stay out of every new bundle, so deleted text cannot travel. */
export function isDeletedRow(row: Record<string, string | null>): boolean {
  return !isLive(rowState(row));
}

/** True when a row may travel in a new bundle: neither deleted nor sealed. */
export function isExportableRow(row: Record<string, string | null>): boolean {
  return isExportable(rowState(row));
}

/**
 * Restore clears a table before inserting the bundle's rows. Tables with a level column keep
 * their sealed rows, so sealed content neither travels in a bundle nor disappears on restore.
 * Material snapshots carry the level in `level_snapshot`, so they follow the same rule.
 */
export function deleteSqlFor(table: string, leveled: boolean): string {
  if (table === DB_TABLES.REVIEW_MATERIAL) {
    return `DELETE FROM ${table} WHERE level_snapshot <> 'sealed'`;
  }
  return leveled ? `DELETE FROM ${table} WHERE level <> 'sealed'` : `DELETE FROM ${table}`;
}

/** Accepts the three known levels; anything else reads as unmarked. */
function readLevel(raw: string | null | undefined): SecurityLevel | null {
  if (raw === SecurityLevel.ANALYZABLE) {
    return SecurityLevel.ANALYZABLE;
  }
  if (raw === SecurityLevel.LOCAL_ONLY) {
    return SecurityLevel.LOCAL_ONLY;
  }
  if (raw === SecurityLevel.SEALED) {
    return SecurityLevel.SEALED;
  }
  return null;
}

/** Rows store the soft-delete flag as an integer string or null. */
function readDeleted(raw: string | null | undefined): boolean {
  return raw !== null && raw !== undefined && Number(raw) === 1;
}