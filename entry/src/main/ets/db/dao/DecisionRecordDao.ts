import { relationalStore } from '@kit.ArkData';
import { DecisionRecord, DecisionRecordType } from '../../model/DecisionRecord';
import { SecurityLevel } from '../../model/SecurityLevel';
import { WorkDepth } from '../../model/WorkDepth';
import { DB_TABLES, DECISION_RECORD_COLS, REVIEW_COLS } from '../DbConstants';
import { queryCount } from '../QuerySupport';

/** Data access for the decisions written by review sessions. */
export class DecisionRecordDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts one decision, returns the row id. */
  async insert(record: DecisionRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [DECISION_RECORD_COLS.ID]: record.id,
      [DECISION_RECORD_COLS.REVIEW_ID]: record.reviewId,
      [DECISION_RECORD_COLS.TYPE]: record.type,
      [DECISION_RECORD_COLS.REASON]: record.reason,
      [DECISION_RECORD_COLS.ACTION]: record.action ?? '',
      [DECISION_RECORD_COLS.COMMITMENT]: record.commitment ?? '',
      [DECISION_RECORD_COLS.RELATION_ID]: record.relationId ?? '',
      [DECISION_RECORD_COLS.PLAN_ITEM_ID]: record.planItemId ?? '',
      [DECISION_RECORD_COLS.OUTCOME]: record.outcome ?? '',
      [DECISION_RECORD_COLS.REVIEW_AT]: record.reviewAt ?? '',
      [DECISION_RECORD_COLS.DEPTH]: record.depth ?? '',
      [DECISION_RECORD_COLS.TIME_BUDGET]: record.timeBudget ?? 0,
      [DECISION_RECORD_COLS.PARTICIPATION_MODE]: record.participationMode ?? '',
      [DECISION_RECORD_COLS.LEVEL]: record.level,
      [DECISION_RECORD_COLS.CREATED_AT]: record.createdAt
    };
    return this.store.insert(DB_TABLES.DECISION_RECORD, values);
  }

  /** Returns every decision, oldest first. */
  async queryAll(): Promise<DecisionRecord[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.DECISION_RECORD);
    predicates.orderByAsc(DECISION_RECORD_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const results: DecisionRecord[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /** Returns the decisions of one review, oldest first. */
  async queryByReview(reviewId: string): Promise<DecisionRecord[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.DECISION_RECORD);
    predicates.equalTo(DECISION_RECORD_COLS.REVIEW_ID, reviewId)
      .orderByAsc(DECISION_RECORD_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const results: DecisionRecord[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /**
   * Counts decisions due on or before the given local date. Sealed decisions and decisions whose
   * review is sealed stay out, so the home counter never reveals a sealed record.
   */
  async countPending(today: string): Promise<number> {
    return queryCount(this.store,
      `SELECT COUNT(*) AS total FROM ${DB_TABLES.DECISION_RECORD} d ` +
      `JOIN ${DB_TABLES.REVIEW_RESULT} r ON r.id = d.${DECISION_RECORD_COLS.REVIEW_ID} ` +
      `WHERE d.${DECISION_RECORD_COLS.REVIEW_AT} IS NOT NULL ` +
      `AND d.${DECISION_RECORD_COLS.REVIEW_AT} <> '' ` +
      `AND d.${DECISION_RECORD_COLS.REVIEW_AT} <= ? ` +
      `AND d.${DECISION_RECORD_COLS.LEVEL} <> 'sealed' ` +
      `AND r.${REVIEW_COLS.LEVEL} <> 'sealed'`,
      [today]);
  }

  /** Removes every decision of one review, returns the deleted row count. */
  async deleteByReview(reviewId: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.DECISION_RECORD);
    predicates.equalTo(DECISION_RECORD_COLS.REVIEW_ID, reviewId);
    return this.store.delete(predicates);
  }

  private mapRow(resultSet: relationalStore.ResultSet): DecisionRecord {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(DECISION_RECORD_COLS.ID)),
      reviewId: resultSet.getString(resultSet.getColumnIndex(DECISION_RECORD_COLS.REVIEW_ID)),
      type: resultSet.getString(resultSet.getColumnIndex(DECISION_RECORD_COLS.TYPE)) as DecisionRecordType,
      reason: readText(resultSet, DECISION_RECORD_COLS.REASON),
      action: readText(resultSet, DECISION_RECORD_COLS.ACTION),
      commitment: readText(resultSet, DECISION_RECORD_COLS.COMMITMENT),
      relationId: readText(resultSet, DECISION_RECORD_COLS.RELATION_ID),
      planItemId: readText(resultSet, DECISION_RECORD_COLS.PLAN_ITEM_ID),
      outcome: readText(resultSet, DECISION_RECORD_COLS.OUTCOME),
      reviewAt: readText(resultSet, DECISION_RECORD_COLS.REVIEW_AT),
      depth: readDepth(resultSet, DECISION_RECORD_COLS.DEPTH),
      timeBudget: readBudget(resultSet, DECISION_RECORD_COLS.TIME_BUDGET),
      participationMode: readText(resultSet, DECISION_RECORD_COLS.PARTICIPATION_MODE),
      level: resultSet.getString(resultSet.getColumnIndex(DECISION_RECORD_COLS.LEVEL)) as SecurityLevel,
      createdAt: resultSet.getLong(resultSet.getColumnIndex(DECISION_RECORD_COLS.CREATED_AT))
    };
  }
}

/** Reads a nullable text column as empty text, matching the optional model fields. */
function readText(resultSet: relationalStore.ResultSet, column: string): string {
  const index = resultSet.getColumnIndex(column);
  return index < 0 || resultSet.isColumnNull(index) ? '' : resultSet.getString(index);
}

/** Reads a nullable depth; unknown or absent values read as undefined for payload fallback. */
function readDepth(resultSet: relationalStore.ResultSet, column: string): WorkDepth | undefined {
  const text = readText(resultSet, column);
  return text === 'quick' || text === 'normal' || text === 'deep' ? text : undefined;
}

/** Reads a nullable time budget; absent or 0 reads as undefined. */
function readBudget(resultSet: relationalStore.ResultSet, column: string): number | undefined {
  const index = resultSet.getColumnIndex(column);
  if (index < 0 || resultSet.isColumnNull(index)) {
    return undefined;
  }
  const value = resultSet.getLong(index);
  return value > 0 ? value : undefined;
}