import { relationalStore } from '@kit.ArkData';
import { Decision } from '../../model/Decision';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, DECISION_COLS } from '../DbConstants';

/** Data access for the decision table. */
export class DecisionDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts a decision, returns the row id. */
  async insert(decision: Decision): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [DECISION_COLS.ID]: decision.id,
      [DECISION_COLS.TITLE]: decision.title,
      [DECISION_COLS.BACKGROUND]: decision.background,
      [DECISION_COLS.OPTIONS]: JSON.stringify(decision.options),
      [DECISION_COLS.CHOICE]: decision.choice,
      [DECISION_COLS.EXPECTED_OUTCOME]: decision.expectedOutcome,
      [DECISION_COLS.TIMESTAMP]: decision.timestamp,
      [DECISION_COLS.RELATED_EVENT_IDS]: JSON.stringify(decision.relatedEventIds),
      [DECISION_COLS.RELATED_RELATION_IDS]: JSON.stringify(decision.relatedRelationIds),
      [DECISION_COLS.LEVEL]: decision.level,
      [DECISION_COLS.REVIEWED]: decision.reviewed ? 1 : 0
    };
    return this.store.insert(DB_TABLES.DECISION, values);
  }

  /** Marks a decision as reviewed or unreviewed. */
  async setReviewed(id: string, reviewed: boolean): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [DECISION_COLS.REVIEWED]: reviewed ? 1 : 0
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.DECISION);
    predicates.equalTo(DECISION_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  /** Returns all decisions. */
  async queryAll(): Promise<Decision[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.DECISION);
    const resultSet = await this.store.query(predicates);
    const decisions: Decision[] = [];
    while (resultSet.goToNextRow()) {
      decisions.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return decisions;
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
    return this.queryCount(`SELECT COUNT(*) AS total FROM ${DB_TABLES.DECISION} WHERE level <> 'sealed'`);
  }

  async countUnreviewed(): Promise<number> {
    return this.queryCount(`SELECT COUNT(*) AS total FROM ${DB_TABLES.DECISION} WHERE level <> 'sealed' AND ${DECISION_COLS.REVIEWED} = 0`);
  }

  private mapRow(resultSet: relationalStore.ResultSet): Decision {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.ID)),
      title: resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.TITLE)),
      background: resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.BACKGROUND)),
      options: JSON.parse(resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.OPTIONS))) as string[],
      choice: resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.CHOICE)),
      expectedOutcome: resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.EXPECTED_OUTCOME)),
      timestamp: resultSet.getLong(resultSet.getColumnIndex(DECISION_COLS.TIMESTAMP)),
      relatedEventIds: JSON.parse(resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.RELATED_EVENT_IDS))) as string[],
      relatedRelationIds: JSON.parse(resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.RELATED_RELATION_IDS))) as string[],
      level: resultSet.getString(resultSet.getColumnIndex(DECISION_COLS.LEVEL)) as SecurityLevel,
      reviewed: resultSet.getLong(resultSet.getColumnIndex(DECISION_COLS.REVIEWED)) === 1
    };
  }
}
