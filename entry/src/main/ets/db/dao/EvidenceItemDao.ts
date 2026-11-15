import { relationalStore } from '@kit.ArkData';
import { EvidenceEffect, EvidenceItem, EvidenceSource, EvidenceTargetType } from '../../model/EvidenceItem';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, EVIDENCE_COLS } from '../DbConstants';

/** Data access for the evidence items attached to reviews and predictions. */
export class EvidenceItemDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts one evidence item, returns the row id. */
  async insert(item: EvidenceItem): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [EVIDENCE_COLS.ID]: item.id,
      [EVIDENCE_COLS.TARGET_TYPE]: item.targetType,
      [EVIDENCE_COLS.TARGET_ID]: item.targetId,
      [EVIDENCE_COLS.SOURCE_TYPE]: item.sourceType,
      [EVIDENCE_COLS.NOTE]: item.note,
      [EVIDENCE_COLS.EFFECT]: item.effect,
      [EVIDENCE_COLS.LEVEL]: item.level ?? SecurityLevel.LOCAL_ONLY,
      [EVIDENCE_COLS.ZONE]: item.zone,
      [EVIDENCE_COLS.CREATED_AT]: item.createdAt
    };
    return this.store.insert(DB_TABLES.EVIDENCE_ITEM, values);
  }

  /** Returns the evidence of one record, ordered by zone and creation time. */
  async queryByTarget(targetType: EvidenceTargetType, targetId: string): Promise<EvidenceItem[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EVIDENCE_ITEM);
    predicates.equalTo(EVIDENCE_COLS.TARGET_TYPE, targetType)
      .and()
      .equalTo(EVIDENCE_COLS.TARGET_ID, targetId)
      .orderByAsc(EVIDENCE_COLS.ZONE)
      .orderByAsc(EVIDENCE_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const results: EvidenceItem[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /** Removes every evidence item of one record, returns the deleted row count. */
  async deleteByTarget(targetType: EvidenceTargetType, targetId: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EVIDENCE_ITEM);
    predicates.equalTo(EVIDENCE_COLS.TARGET_TYPE, targetType)
      .and()
      .equalTo(EVIDENCE_COLS.TARGET_ID, targetId);
    return this.store.delete(predicates);
  }

  private mapRow(resultSet: relationalStore.ResultSet): EvidenceItem {
    // Rows written before the zone column existed read back as zone 0.
    const zoneIndex = resultSet.getColumnIndex(EVIDENCE_COLS.ZONE);
    return {
      id: resultSet.getString(resultSet.getColumnIndex(EVIDENCE_COLS.ID)),
      targetType: resultSet.getString(resultSet.getColumnIndex(EVIDENCE_COLS.TARGET_TYPE)) as EvidenceTargetType,
      targetId: resultSet.getString(resultSet.getColumnIndex(EVIDENCE_COLS.TARGET_ID)),
      sourceType: resultSet.getString(resultSet.getColumnIndex(EVIDENCE_COLS.SOURCE_TYPE)) as EvidenceSource,
      note: resultSet.getString(resultSet.getColumnIndex(EVIDENCE_COLS.NOTE)),
      effect: resultSet.getString(resultSet.getColumnIndex(EVIDENCE_COLS.EFFECT)) as EvidenceEffect,
      level: resultSet.getString(resultSet.getColumnIndex(EVIDENCE_COLS.LEVEL)) as SecurityLevel,
      zone: zoneIndex < 0 ? 0 : resultSet.getLong(zoneIndex),
      createdAt: resultSet.getLong(resultSet.getColumnIndex(EVIDENCE_COLS.CREATED_AT))
    };
  }
}