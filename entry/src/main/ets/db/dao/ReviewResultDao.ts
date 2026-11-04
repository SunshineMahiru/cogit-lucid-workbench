import { relationalStore } from '@kit.ArkData';
import { ReviewPeriod } from '../../model/ReviewPeriod';
import { ReviewResult } from '../../model/ReviewResult';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, REVIEW_COLS } from '../DbConstants';
import { parseStringArray } from '../SafeJson';

/** Data access for saved review sessions. */
export class ReviewResultDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts a review session, returns the row id. */
  async insert(result: ReviewResult): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [REVIEW_COLS.ID]: result.id,
      [REVIEW_COLS.PERIOD]: result.period,
      [REVIEW_COLS.RANGE_LABEL]: result.rangeLabel,
      [REVIEW_COLS.FACTS]: result.facts,
      [REVIEW_COLS.INTERPRETATION]: result.interpretation,
      [REVIEW_COLS.CONTRADICTION]: result.contradiction,
      [REVIEW_COLS.ACTION]: result.action,
      [REVIEW_COLS.ANCHOR_IDS]: JSON.stringify(result.anchorIds),
      [REVIEW_COLS.PLAN_ID]: result.planId ?? '',
      [REVIEW_COLS.PLAN_NODE_ID]: result.planNodeId ?? '',
      [REVIEW_COLS.LEVEL]: result.level ?? SecurityLevel.LOCAL_ONLY,
      [REVIEW_COLS.CREATED_AT]: result.createdAt
    };
    return this.store.insert(DB_TABLES.REVIEW_RESULT, values);
  }

  /** Returns the newest review sessions first, capped at limit. */
  async queryRecent(limit: number): Promise<ReviewResult[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_RESULT);
    predicates.orderByDesc(REVIEW_COLS.CREATED_AT).limitAs(limit);
    const resultSet = await this.store.query(predicates);
    try {
      const results: ReviewResult[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /** Returns one saved review by id, or null when it does not exist. */
  async queryById(id: string): Promise<ReviewResult | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_RESULT);
    predicates.equalTo(REVIEW_COLS.ID, id).limitAs(1);
    const resultSet = await this.store.query(predicates);
    try {
      let result: ReviewResult | null = null;
      if (resultSet.goToNextRow()) {
        result = this.mapRow(resultSet);
      }
      return result;
    } finally {
      resultSet.close();
    }
  }

  private mapRow(resultSet: relationalStore.ResultSet): ReviewResult {
    const planId = resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.PLAN_ID));
    const planNodeId = resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.PLAN_NODE_ID));
    const result: ReviewResult = {
      id: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.ID)),
      period: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.PERIOD)) as ReviewPeriod,
      rangeLabel: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.RANGE_LABEL)),
      facts: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.FACTS)),
      interpretation: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.INTERPRETATION)),
      contradiction: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.CONTRADICTION)),
      action: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.ACTION)),
      anchorIds: parseStringArray(resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.ANCHOR_IDS))),
      level: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.LEVEL)) as SecurityLevel,
      createdAt: resultSet.getLong(resultSet.getColumnIndex(REVIEW_COLS.CREATED_AT))
    };
    if (planId.length > 0) {
      result.planId = planId;
    }
    if (planNodeId.length > 0) {
      result.planNodeId = planNodeId;
    }
    return result;
  }
}
