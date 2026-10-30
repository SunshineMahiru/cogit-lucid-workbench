import { relationalStore } from '@kit.ArkData';
import { InteractionLog, Relation } from '../../model/Relation';
import { SecurityLevel } from '../../model/SecurityLevel';
import { TrustLevel } from '../../model/TrustLevel';
import { DB_TABLES, RELATION_COLS } from '../DbConstants';

/** Data access for the relation table. */
export class RelationDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts a relation, returns the row id. */
  async insert(relation: Relation): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [RELATION_COLS.ID]: relation.id,
      [RELATION_COLS.NAME]: relation.name,
      [RELATION_COLS.TRUST_LEVEL]: relation.trustLevel,
      [RELATION_COLS.INTERACTION_LOG]: JSON.stringify(relation.interactionLog),
      [RELATION_COLS.RAW_MATERIAL_TEST]: relation.rawMaterialTest ? 1 : 0,
      [RELATION_COLS.FORBID_ANALYSIS]: relation.forbidAnalysis ? 1 : 0,
      [RELATION_COLS.LEVEL]: relation.level,
      [RELATION_COLS.DELETED]: relation.deleted === true ? 1 : 0,
      [RELATION_COLS.NOTES]: relation.notes
    };
    return this.store.insert(DB_TABLES.RELATION, values);
  }

  /** Updates the editable profile fields of a relation. */
  async updateProfile(id: string, name: string, trustLevel: TrustLevel, rawMaterialTest: boolean,
    forbidAnalysis: boolean, level: SecurityLevel, notes: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [RELATION_COLS.NAME]: name,
      [RELATION_COLS.TRUST_LEVEL]: trustLevel,
      [RELATION_COLS.RAW_MATERIAL_TEST]: rawMaterialTest ? 1 : 0,
      [RELATION_COLS.FORBID_ANALYSIS]: forbidAnalysis ? 1 : 0,
      [RELATION_COLS.LEVEL]: level,
      [RELATION_COLS.NOTES]: notes
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.RELATION);
    predicates.equalTo(RELATION_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  /** Updates a relation's interaction log and notes. */
  async update(id: string, interactionLog: InteractionLog[], notes: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [RELATION_COLS.INTERACTION_LOG]: JSON.stringify(interactionLog),
      [RELATION_COLS.NOTES]: notes
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.RELATION);
    predicates.equalTo(RELATION_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  /** Returns all active relations. */
  async queryAll(): Promise<Relation[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.RELATION);
    predicates.equalTo(RELATION_COLS.DELETED, 0);
    const resultSet = await this.store.query(predicates);
    const relations: Relation[] = [];
    while (resultSet.goToNextRow()) {
      relations.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return relations;
  }

  /** Returns one active relation by id, or null when it is gone. */
  async queryById(id: string): Promise<Relation | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.RELATION);
    predicates.equalTo(RELATION_COLS.ID, id).equalTo(RELATION_COLS.DELETED, 0).limitAs(1);
    const resultSet = await this.store.query(predicates);
    let relation: Relation | null = null;
    if (resultSet.goToNextRow()) {
      relation = this.mapRow(resultSet);
    }
    resultSet.close();
    return relation;
  }

  /** Marks a relation as deleted without removing its history. */
  async softDelete(id: string): Promise<number> {
    return this.updateDeleted(id, 1);
  }

  /** Restores a soft-deleted relation. */
  async restore(id: string): Promise<number> {
    return this.updateDeleted(id, 0);
  }

  private async updateDeleted(id: string, deleted: number): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [RELATION_COLS.DELETED]: deleted
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.RELATION);
    predicates.equalTo(RELATION_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  private async queryCount(sql: string): Promise<number> {
    const resultSet = await this.store.querySql(sql);
    let total = 0;
    if (resultSet.goToFirstRow()) {
      total = resultSet.getLong(0);
    }
    resultSet.close();
    return total;
  }

  async countVisible(): Promise<number> {
    return this.queryCount(
      `SELECT COUNT(*) AS total FROM ${DB_TABLES.RELATION} WHERE level <> 'sealed' AND deleted = 0`);
  }

  private mapRow(resultSet: relationalStore.ResultSet): Relation {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(RELATION_COLS.ID)),
      name: resultSet.getString(resultSet.getColumnIndex(RELATION_COLS.NAME)),
      trustLevel: resultSet.getString(resultSet.getColumnIndex(RELATION_COLS.TRUST_LEVEL)) as TrustLevel,
      interactionLog: JSON.parse(resultSet.getString(resultSet.getColumnIndex(RELATION_COLS.INTERACTION_LOG))) as InteractionLog[],
      rawMaterialTest: resultSet.getLong(resultSet.getColumnIndex(RELATION_COLS.RAW_MATERIAL_TEST)) === 1,
      forbidAnalysis: resultSet.getLong(resultSet.getColumnIndex(RELATION_COLS.FORBID_ANALYSIS)) === 1,
      level: resultSet.getString(resultSet.getColumnIndex(RELATION_COLS.LEVEL)) as SecurityLevel,
      deleted: resultSet.getLong(resultSet.getColumnIndex(RELATION_COLS.DELETED)) === 1,
      notes: resultSet.getString(resultSet.getColumnIndex(RELATION_COLS.NOTES))
    };
  }
}
