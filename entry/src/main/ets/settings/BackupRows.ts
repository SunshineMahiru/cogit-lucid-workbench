/** Row-level rules for the portable backup; kept apart from the file and picker code. */

/** A row carries sealed content when its level column says so. */
export function isSealedRow(row: Record<string, string | null>): boolean {
  return row.level === 'sealed';
}

/** Soft-deleted rows stay out of every new bundle, so deleted text cannot travel. */
export function isDeletedRow(row: Record<string, string | null>): boolean {
  const flag = row.deleted;
  return flag !== undefined && flag !== null && Number(flag) === 1;
}

/**
 * Restore clears a table before inserting the bundle's rows. Tables with a level column keep
 * their sealed rows, so sealed content neither travels in a bundle nor disappears on restore.
 */
export function deleteSqlFor(table: string, leveled: boolean): string {
  return leveled ? `DELETE FROM ${table} WHERE level <> 'sealed'` : `DELETE FROM ${table}`;
}
