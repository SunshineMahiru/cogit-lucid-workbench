import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DB_TABLES, REVIEW_COLS } from '../db/DbConstants';
import { ExperienceMaterialDao } from '../db/dao/ExperienceMaterialDao';
import { ReviewMaterialDao } from '../db/dao/ReviewMaterialDao';
import { ReviewMaterial, REVIEW_ZONE } from '../model/ReviewMaterial';
import {
  MaterialSourceRow,
  buildRows,
  mergeExisting,
  parseMaterialIds
} from './ReviewMaterialSnapshot';

const DOMAIN = 0x0000;
const TAG = 'CogitLucidReviewMaterial';

interface LegacyReviewRow {
  id: string;
  payload: string;
  createdAt: number;
}

/**
 * Copies `payload.materialIds` of older reviews into `review_material`. Every launch retries the
 * scan; rows already copied are skipped, so a partial run finishes on the next start.
 */
export async function backfillReviewMaterials(store: relationalStore.RdbStore): Promise<void> {
  const snapshotDao = new ReviewMaterialDao(store);
  const materialDao = new ExperienceMaterialDao(store);
  let rows: ReviewMaterial[] = [];
  try {
    rows = await collectRows(store, snapshotDao, materialDao);
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'review material scan skipped: %{public}s', (error as Error).message);
    return;
  }
  if (rows.length === 0) {
    return;
  }
  store.beginTransaction();
  try {
    for (const row of rows) {
      await snapshotDao.insert(row);
    }
    store.commit();
  } catch (error) {
    store.rollBack();
    hilog.warn(DOMAIN, TAG, 'review material backfill rolled back: %{public}s', (error as Error).message);
  }
}

/** Reads the reviews that still carry material ids and turns them into snapshot rows. */
async function collectRows(store: relationalStore.RdbStore, snapshotDao: ReviewMaterialDao,
  materialDao: ExperienceMaterialDao): Promise<ReviewMaterial[]> {
  const reviews = await readLegacyReviews(store);
  const rows: ReviewMaterial[] = [];
  for (const review of reviews) {
    const payload = readPayload(review.payload);
    if (payload === undefined) {
      continue;
    }
    const ids = parseMaterialIds(payload);
    if (ids.length === 0) {
      continue;
    }
    const existing = await snapshotDao.existingIds(review.id);
    const sources = new Map<string, MaterialSourceRow>();
    for (const id of ids) {
      const material = await materialDao.queryById(id);
      if (material !== null) {
        sources.set(id, {
          id: material.id,
          text: material.text,
          source: material.source,
          level: material.level,
          deleted: material.deleted,
          kind: material.kind
        });
      }
    }
    const built = buildRows(review.id, review.createdAt, ids, (id: string) => sources.get(id) ?? null);
    for (const row of built) {
      // Legacy citations came from the first zone, the scene the old review flow recorded.
      row.zone = REVIEW_ZONE.SCENE;
    }
    for (const row of mergeExisting(built, existing)) {
      rows.push(row);
    }
  }
  return rows;
}

async function readLegacyReviews(store: relationalStore.RdbStore): Promise<LegacyReviewRow[]> {
  const sql = `SELECT ${REVIEW_COLS.ID}, ${REVIEW_COLS.PAYLOAD}, ${REVIEW_COLS.CREATED_AT}
    FROM ${DB_TABLES.REVIEW_RESULT}
    WHERE ${REVIEW_COLS.PAYLOAD} LIKE '%materialIds%'`;
  const resultSet = await store.querySql(sql);
  try {
    const reviews: LegacyReviewRow[] = [];
    const idIndex = resultSet.getColumnIndex(REVIEW_COLS.ID);
    const payloadIndex = resultSet.getColumnIndex(REVIEW_COLS.PAYLOAD);
    const createdIndex = resultSet.getColumnIndex(REVIEW_COLS.CREATED_AT);
    while (resultSet.goToNextRow()) {
      reviews.push({
        id: resultSet.getString(idIndex),
        payload: resultSet.getString(payloadIndex),
        createdAt: resultSet.getLong(createdIndex)
      });
    }
    return reviews;
  } finally {
    resultSet.close();
  }
}

/** Parses one payload; damaged JSON reads as undefined so the review is skipped. */
function readPayload(raw: string): Object | undefined {
  if (raw.trim().length === 0) {
    return undefined;
  }
  try {
    return JSON.parse(raw) as Object;
  } catch (error) {
    return undefined;
  }
}