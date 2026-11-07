/** Prefix shared by every exported document. */
export const EXPORT_FILE_PREFIX = 'cogit-export';

/** Sandbox copies kept for re-sharing; older ones are removed after each export. */
export const EXPORT_RETENTION = 10;

/**
 * Returns the export names outside the retention window, oldest first.
 * Names embed a sortable timestamp, so lexicographic order is chronological.
 */
export function expiredExports(names: string[], keepName: string, retention: number = EXPORT_RETENTION): string[] {
  const candidates = names
    .filter((name: string) => name.startsWith(EXPORT_FILE_PREFIX) && name.endsWith('.md') && name !== keepName)
    .sort();
  const excess = candidates.length - (retention - 1);
  return excess > 0 ? candidates.slice(0, excess) : [];
}
