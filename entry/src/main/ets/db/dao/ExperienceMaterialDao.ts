import { relationalStore } from '@kit.ArkData';
import { ExperienceMaterial } from '../../model/ExperienceMaterial';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, MATERIAL_COLS } from '../DbConstants';

/** Data access for experience materials; one event can carry several of them. */
export class ExperienceMaterialDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts one material, returns the row id. */
  async insert(material: ExperienceMaterial): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [MATERIAL_COLS.ID]: material.id,
      [MATERIAL_COLS.EVENT_ID]: material.eventId,
      [MATERIAL_COLS.KIND]: material.kind,
      [MATERIAL_COLS.FORM]: material.form,
      [MATERIAL_COLS.TEXT]: material.text,
      [MATERIAL_COLS.OBSERVED_AT]: material.observedAt,
      [MATERIAL_COLS.SOURCE]: material.source,
      [MATERIAL_COLS.SOURCE_STANCE]: material.sourceStance,
      [MATERIAL_COLS.LEVEL]: material.level ?? SecurityLevel.LOCAL_ONLY,
      [MATERIAL_COLS.REVISION_OF]: material.revisionOf,
      [MATERIAL_COLS.DELETED]: material.deleted ? 1 : 0,
      [MATERIAL_COLS.CREATED_AT]: material.createdAt
    };
    return this.store.insert(DB_TABLES.EXPERIENCE_MATERIAL, values);
  }

  /** Returns the live materials of one event, oldest first. */
  async queryByEvent(eventId: string): Promise<ExperienceMaterial[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EXPERIENCE_MATERIAL);
    predicates.equalTo(MATERIAL_COLS.EVENT_ID, eventId)
      .and()
      .equalTo(MATERIAL_COLS.DELETED, 0)
      .orderByAsc(MATERIAL_COLS.OBSERVED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const results: ExperienceMaterial[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Pulls every material of one event down to the given record level. Materials already at or
   * below that level stay as they are; this method never widens a material.
   */
  async clampLevelsByEvent(eventId: string, level: SecurityLevel): Promise<number> {
    if (level === SecurityLevel.ANALYZABLE) {
      return 0;
    }
    const allowed: SecurityLevel[] = level === SecurityLevel.SEALED ?
      [SecurityLevel.SEALED] : [SecurityLevel.LOCAL_ONLY, SecurityLevel.SEALED];
    const materials = await this.queryByEvent(eventId);
    let changed = 0;
    for (const material of materials) {
      if (allowed.includes(material.level)) {
        continue;
      }
      const values: relationalStore.ValuesBucket = {
        [MATERIAL_COLS.LEVEL]: level
      };
      const predicates = new relationalStore.RdbPredicates(DB_TABLES.EXPERIENCE_MATERIAL);
      predicates.equalTo(MATERIAL_COLS.ID, material.id);
      changed += await this.store.update(values, predicates);
    }
    return changed;
  }

  /** Removes every material of one event, used when an edit rewrites them from the draft. */
  async deleteByEvent(eventId: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EXPERIENCE_MATERIAL);
    predicates.equalTo(MATERIAL_COLS.EVENT_ID, eventId);
    return this.store.delete(predicates);
  }

  /** Marks a material deleted; the row stays so history can say "source deleted". */
  async markDeleted(id: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [MATERIAL_COLS.DELETED]: 1
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EXPERIENCE_MATERIAL);
    predicates.equalTo(MATERIAL_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  /** Marks every material of one event deleted, used when the note itself is deleted. */
  async markDeletedByEvent(eventId: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [MATERIAL_COLS.DELETED]: 1
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EXPERIENCE_MATERIAL);
    predicates.equalTo(MATERIAL_COLS.EVENT_ID, eventId);
    return this.store.update(values, predicates);
  }

  private mapRow(resultSet: relationalStore.ResultSet): ExperienceMaterial {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.ID)),
      eventId: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.EVENT_ID)),
      kind: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.KIND)) as ExperienceMaterial['kind'],
      form: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.FORM)) as ExperienceMaterial['form'],
      text: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.TEXT)),
      observedAt: resultSet.getLong(resultSet.getColumnIndex(MATERIAL_COLS.OBSERVED_AT)),
      source: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.SOURCE)) as ExperienceMaterial['source'],
      sourceStance: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.SOURCE_STANCE)) as ExperienceMaterial['sourceStance'],
      level: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.LEVEL)) as SecurityLevel,
      revisionOf: resultSet.getString(resultSet.getColumnIndex(MATERIAL_COLS.REVISION_OF)),
      deleted: resultSet.getLong(resultSet.getColumnIndex(MATERIAL_COLS.DELETED)) === 1,
      createdAt: resultSet.getLong(resultSet.getColumnIndex(MATERIAL_COLS.CREATED_AT))
    };
  }
}
