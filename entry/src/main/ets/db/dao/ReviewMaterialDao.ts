import { relationalStore } from '@kit.ArkData';
import { ReviewMaterial } from '../../model/ReviewMaterial';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, REVIEW_MATERIAL_COLS } from '../DbConstants';

/** Data access for the material snapshots a review cited. */
export class ReviewMaterialDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Writes one snapshot; an existing row for the same review and material stays untouched. */
  async insert(row: ReviewMaterial): Promise<void> {
    const sql = `INSERT OR IGNORE INTO ${DB_TABLES.REVIEW_MATERIAL}
      (${REVIEW_MATERIAL_COLS.REVIEW_ID}, ${REVIEW_MATERIAL_COLS.MATERIAL_ID},
        ${REVIEW_MATERIAL_COLS.KIND_SNAPSHOT},
        ${REVIEW_MATERIAL_COLS.TEXT_SNAPSHOT}, ${REVIEW_MATERIAL_COLS.SOURCE_SNAPSHOT},
        ${REVIEW_MATERIAL_COLS.LEVEL_SNAPSHOT}, ${REVIEW_MATERIAL_COLS.ZONE},
        ${REVIEW_MATERIAL_COLS.CITED_AT}, ${REVIEW_MATERIAL_COLS.SNAPSHOT_MISSING})
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`;
    await this.store.executeSql(sql, [
      row.reviewId,
      row.materialId,
      row.kindSnapshot,
      row.textSnapshot,
      row.sourceSnapshot,
      row.levelSnapshot,
      row.zone,
      row.citedAt,
      row.snapshotMissing ? 1 : 0
    ]);
  }

  /** Returns every snapshot of one review, ordered by zone, citation time and material id. */
  async queryByReview(reviewId: string): Promise<ReviewMaterial[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_MATERIAL);
    predicates.equalTo(REVIEW_MATERIAL_COLS.REVIEW_ID, reviewId)
      .orderByAsc(REVIEW_MATERIAL_COLS.ZONE)
      .orderByAsc(REVIEW_MATERIAL_COLS.CITED_AT)
      .orderByAsc(REVIEW_MATERIAL_COLS.MATERIAL_ID);
    const resultSet = await this.store.query(predicates);
    try {
      const results: ReviewMaterial[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /** Returns the snapshots that cite one material, oldest citation first. */
  async queryByMaterial(materialId: string): Promise<ReviewMaterial[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_MATERIAL);
    predicates.equalTo(REVIEW_MATERIAL_COLS.MATERIAL_ID, materialId)
      .orderByAsc(REVIEW_MATERIAL_COLS.CITED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const results: ReviewMaterial[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /** Returns the material ids one review already has snapshots for. */
  async existingIds(reviewId: string): Promise<string[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_MATERIAL);
    predicates.equalTo(REVIEW_MATERIAL_COLS.REVIEW_ID, reviewId)
      .orderByAsc(REVIEW_MATERIAL_COLS.MATERIAL_ID);
    const resultSet = await this.store.query(predicates);
    try {
      const ids: string[] = [];
      const index = resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.MATERIAL_ID);
      while (resultSet.goToNextRow()) {
        ids.push(resultSet.getString(index));
      }
      return ids;
    } finally {
      resultSet.close();
    }
  }

  /** Empties the copied text and origin of every snapshot citing these materials. */
  async clearSnapshots(materialIds: string[]): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [REVIEW_MATERIAL_COLS.TEXT_SNAPSHOT]: '',
      [REVIEW_MATERIAL_COLS.SOURCE_SNAPSHOT]: '',
      [REVIEW_MATERIAL_COLS.SNAPSHOT_MISSING]: 1
    };
    let changed = 0;
    for (const materialId of materialIds) {
      const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_MATERIAL);
      predicates.equalTo(REVIEW_MATERIAL_COLS.MATERIAL_ID, materialId);
      changed += await this.store.update(values, predicates);
    }
    return changed;
  }

  /**
   * Pulls snapshots down to the given level. A local_only target narrows analyzable snapshots;
   * a sealed target narrows both and drops the copied text. Never widens a snapshot.
   */
  async clampLevels(materialIds: string[], level: SecurityLevel): Promise<number> {
    if (level === SecurityLevel.ANALYZABLE) {
      return 0;
    }
    const wider: SecurityLevel[] = level === SecurityLevel.SEALED ?
      [SecurityLevel.ANALYZABLE, SecurityLevel.LOCAL_ONLY] : [SecurityLevel.ANALYZABLE];
    let changed = 0;
    for (const materialId of materialIds) {
      for (const from of wider) {
        changed += await this.narrow(materialId, from, level);
      }
    }
    return changed;
  }

  private async narrow(materialId: string, from: SecurityLevel, to: SecurityLevel): Promise<number> {
    const values: relationalStore.ValuesBucket = to === SecurityLevel.SEALED ?
      {
        [REVIEW_MATERIAL_COLS.LEVEL_SNAPSHOT]: to,
        [REVIEW_MATERIAL_COLS.TEXT_SNAPSHOT]: ''
      } :
      { [REVIEW_MATERIAL_COLS.LEVEL_SNAPSHOT]: to };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_MATERIAL);
    predicates.equalTo(REVIEW_MATERIAL_COLS.MATERIAL_ID, materialId)
      .and()
      .equalTo(REVIEW_MATERIAL_COLS.LEVEL_SNAPSHOT, from);
    return this.store.update(values, predicates);
  }

  private mapRow(resultSet: relationalStore.ResultSet): ReviewMaterial {
    // Rows written before the kind snapshot column existed read back as empty text.
    const kindIndex = resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.KIND_SNAPSHOT);
    return {
      reviewId: resultSet.getString(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.REVIEW_ID)),
      materialId: resultSet.getString(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.MATERIAL_ID)),
      kindSnapshot: kindIndex < 0 ? '' : resultSet.getString(kindIndex),
      textSnapshot: resultSet.getString(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.TEXT_SNAPSHOT)),
      sourceSnapshot: resultSet.getString(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.SOURCE_SNAPSHOT)),
      levelSnapshot: resultSet.getString(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.LEVEL_SNAPSHOT)) as SecurityLevel,
      zone: resultSet.getLong(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.ZONE)),
      citedAt: resultSet.getLong(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.CITED_AT)),
      snapshotMissing: resultSet.getLong(resultSet.getColumnIndex(REVIEW_MATERIAL_COLS.SNAPSHOT_MISSING)) === 1
    };
  }
}