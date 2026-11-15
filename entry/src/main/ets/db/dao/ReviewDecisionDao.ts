import { relationalStore } from '@kit.ArkData';
import { DB_TABLES, REVIEW_DECISION_COLS } from '../DbConstants';

/**
 * Citations written in the same millisecond must still read back in session order; SQLite leaves
 * timestamp ties unordered, so each write gets a stamp strictly newer than the previous one.
 */
let lastCreatedAt: number = 0;

function nextCreatedAt(): number {
  const now = Date.now();
  lastCreatedAt = now > lastCreatedAt ? now : lastCreatedAt + 1;
  return lastCreatedAt;
}

/** Data access for the decisions a review cited. */
export class ReviewDecisionDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Writes one citation; the composite key keeps a decision out of the same review twice. */
  async insert(reviewId: string, decisionId: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [REVIEW_DECISION_COLS.REVIEW_ID]: reviewId,
      [REVIEW_DECISION_COLS.DECISION_ID]: decisionId,
      [REVIEW_DECISION_COLS.CREATED_AT]: nextCreatedAt()
    };
    return this.store.insert(DB_TABLES.REVIEW_DECISION, values);
  }

  /** Returns the decision ids one review cited, oldest citation first. */
  async queryByReview(reviewId: string): Promise<string[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_DECISION);
    predicates.equalTo(REVIEW_DECISION_COLS.REVIEW_ID, reviewId)
      .orderByAsc(REVIEW_DECISION_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const ids: string[] = [];
      const index = resultSet.getColumnIndex(REVIEW_DECISION_COLS.DECISION_ID);
      while (resultSet.goToNextRow()) {
        ids.push(resultSet.getString(index));
      }
      return ids;
    } finally {
      resultSet.close();
    }
  }

  /** Returns the ids of the reviews that cited one decision, oldest citation first. */
  async queryByDecision(decisionId: string): Promise<string[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_DECISION);
    predicates.equalTo(REVIEW_DECISION_COLS.DECISION_ID, decisionId)
      .orderByAsc(REVIEW_DECISION_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const ids: string[] = [];
      const index = resultSet.getColumnIndex(REVIEW_DECISION_COLS.REVIEW_ID);
      while (resultSet.goToNextRow()) {
        ids.push(resultSet.getString(index));
      }
      return ids;
    } finally {
      resultSet.close();
    }
  }

  /** Removes every citation of one review, returns the deleted row count. */
  async deleteByReview(reviewId: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REVIEW_DECISION);
    predicates.equalTo(REVIEW_DECISION_COLS.REVIEW_ID, reviewId);
    return this.store.delete(predicates);
  }
}