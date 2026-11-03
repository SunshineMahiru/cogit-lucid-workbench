/** One legacy prediction row as stored before revisions shared a root id. */
export interface LegacyPredictionRow {
  id: string;
  target: string;
  version: number;
  rootId: string;
  createdAt: number;
}

/** A group that can be merged without guessing: versions 1..n, one row each. */
export interface LegacyMergePlan {
  rootId: string;
  ids: string[];
}

/**
 * Finds legacy rows that are provably one prediction's revisions: same target,
 * versions exactly 1..n with no duplicates, and every row still its own root.
 * Independent predictions that both start at v1 are left alone.
 */
export function planLegacyPredictionMerges(rows: LegacyPredictionRow[]): LegacyMergePlan[] {
  const groups: Map<string, LegacyPredictionRow[]> = new Map();
  for (const row of rows) {
    const legacy = row.rootId.length === 0 || row.rootId === row.id;
    if (!legacy) {
      continue;
    }
    const key = row.target.trim();
    if (key.length === 0) {
      continue;
    }
    const group = groups.get(key);
    if (group === undefined) {
      groups.set(key, [row]);
    } else {
      group.push(row);
    }
  }
  const plans: LegacyMergePlan[] = [];
  for (const group of groups.values()) {
    if (group.length < 2) {
      continue;
    }
    const versions: number[] = group.map((row: LegacyPredictionRow) => row.version).sort(
      (left: number, right: number) => left - right);
    let contiguous = versions[0] === 1;
    for (let index = 1; index < versions.length; index++) {
      if (versions[index] !== versions[index - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (!contiguous) {
      continue;
    }
    const sorted: LegacyPredictionRow[] = group.slice().sort(
      (left: LegacyPredictionRow, right: LegacyPredictionRow) => left.version - right.version);
    plans.push({
      rootId: sorted[0].id,
      ids: sorted.map((row: LegacyPredictionRow) => row.id)
    });
  }
  return plans;
}
