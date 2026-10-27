import { relationalStore } from '@kit.ArkData';
import { ReviewPeriod } from '../../model/ReviewPeriod';
import { ReviewResult } from '../../model/ReviewResult';
import { DB_TABLES, REVIEW_COLS } from '../DbConstants';

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
      [REVIEW_COLS.CREATED_AT]: result.createdAt
    };
    return this.store.insert(DB_TABLES.REVIEW_RESULT, values);
  }

  /** Returns the newest review sessions first, capped at limit. */
  async queryRecent(limit: number): Promise<ReviewResult[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_RESULT);
    predicates.orderByDesc(REVIEW_COLS.CREATED_AT).limitAs(limit);
    const resultSet = await this.store.query(predicates);
    const results: ReviewResult[] = [];
    while (resultSet.goToNextRow()) {
      results.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return results;
  }

  /** Returns one saved review by id, or null when it does not exist. */
  async queryById(id: string): Promise<ReviewResult | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_RESULT);
    predicates.equalTo(REVIEW_COLS.ID, id).limitAs(1);
    const resultSet = await this.store.query(predicates);
    let result: ReviewResult | null = null;
    if (resultSet.goToNextRow()) {
      result = this.mapRow(resultSet);
    }
    resultSet.close();
    return result;
  }

  private mapRow(resultSet: relationalStore.ResultSet): ReviewResult {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.ID)),
      period: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.PERIOD)) as ReviewPeriod,
      rangeLabel: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.RANGE_LABEL)),
      facts: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.FACTS)),
      interpretation: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.INTERPRETATION)),
      contradiction: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.CONTRADICTION)),
      action: resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.ACTION)),
      anchorIds: JSON.parse(resultSet.getString(resultSet.getColumnIndex(REVIEW_COLS.ANCHOR_IDS))) as string[],
      createdAt: resultSet.getLong(resultSet.getColumnIndex(REVIEW_COLS.CREATED_AT))
    };
  }
}
