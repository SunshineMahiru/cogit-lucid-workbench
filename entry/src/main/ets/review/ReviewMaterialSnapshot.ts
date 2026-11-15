import { ReviewMaterial, REVIEW_ZONE } from '../model/ReviewMaterial';
import { SecurityLevel } from '../model/SecurityLevel';

/** One material as the database holds it; `deleted` stays visible so snapshots can record it. */
export interface MaterialSourceRow {
  id: string;
  text: string;
  source: string;
  level: SecurityLevel;
  deleted: boolean;
}

/** Resolves a material id to its current row, or null when it never existed. */
export type MaterialLookup = (id: string) => MaterialSourceRow | null;

/**
 * Reads `materialIds` out of a parsed review payload. Only string elements are kept, repeated
 * ids collapse to their first position, and anything that is not an array yields no ids.
 */
export function parseMaterialIds(payload: Object | undefined): string[] {
  if (payload === undefined) {
    return [];
  }
  const entry = payload as Record<string, Object>;
  const value = entry.materialIds;
  if (!Array.isArray(value)) {
    return [];
  }
  const items: Object[] = value as Object[];
  const seen = new Set<string>();
  const ids: string[] = [];
  for (const item of items) {
    if (typeof item !== 'string') {
      continue;
    }
    if (seen.has(item)) {
      continue;
    }
    seen.add(item);
    ids.push(item);
  }
  return ids;
}

/**
 * Builds the snapshot rows a review should cite. A live, non-sealed source contributes its text,
 * origin and level; a deleted, sealed or missing source keeps no text and marks the snapshot
 * missing, so the review can still say it once cited something it can no longer quote.
 */
export function buildRows(reviewId: string, citedAt: number, ids: string[],
  lookup: MaterialLookup): ReviewMaterial[] {
  const seen = new Set<string>();
  const rows: ReviewMaterial[] = [];
  for (const id of ids) {
    if (seen.has(id)) {
      continue;
    }
    seen.add(id);
    rows.push(toSnapshotRow(reviewId, citedAt, id, lookup(id)));
  }
  return rows;
}

/** Drops rows whose material already has a snapshot, keeping the first snapshot in place. */
export function mergeExisting(rows: ReviewMaterial[], existingIds: string[]): ReviewMaterial[] {
  const existing = new Set<string>();
  for (const id of existingIds) {
    existing.add(id);
  }
  const result: ReviewMaterial[] = [];
  for (const row of rows) {
    if (existing.has(row.materialId)) {
      continue;
    }
    result.push(row);
  }
  return result;
}

function toSnapshotRow(reviewId: string, citedAt: number, materialId: string,
  source: MaterialSourceRow | null): ReviewMaterial {
  if (source === null) {
    return {
      reviewId: reviewId,
      materialId: materialId,
      textSnapshot: '',
      sourceSnapshot: '',
      levelSnapshot: SecurityLevel.LOCAL_ONLY,
      zone: REVIEW_ZONE.UNASSIGNED,
      citedAt: citedAt,
      snapshotMissing: true
    };
  }
  const citable = !source.deleted && source.level !== SecurityLevel.SEALED;
  return {
    reviewId: reviewId,
    materialId: materialId,
    textSnapshot: citable ? source.text : '',
    sourceSnapshot: citable ? source.source : '',
    levelSnapshot: source.level,
    zone: REVIEW_ZONE.UNASSIGNED,
    citedAt: citedAt,
    snapshotMissing: !citable
  };
}