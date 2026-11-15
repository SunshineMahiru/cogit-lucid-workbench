import { relationalStore } from '@kit.ArkData';
import { CostDimension, CostNote } from '../../model/CostNote';
import { COST_COLS, DB_TABLES } from '../DbConstants';

/** Data access for the costs charged to a review. */
export class CostNoteDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts one cost, returns the row id. */
  async insert(note: CostNote): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [COST_COLS.ID]: note.id,
      [COST_COLS.REVIEW_ID]: note.reviewId,
      [COST_COLS.DIMENSION]: note.dimension,
      [COST_COLS.TEXT]: note.text,
      [COST_COLS.BEARABLE]: note.bearable ? 1 : 0,
      [COST_COLS.CREATED_AT]: note.createdAt
    };
    return this.store.insert(DB_TABLES.COST_NOTE, values);
  }

  /** Returns every cost of one review, oldest first. */
  async queryByReview(reviewId: string): Promise<CostNote[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.COST_NOTE);
    predicates.equalTo(COST_COLS.REVIEW_ID, reviewId)
      .orderByAsc(COST_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const results: CostNote[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  /** Removes every cost of one review, returns the deleted row count. */
  async deleteByReview(reviewId: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.COST_NOTE);
    predicates.equalTo(COST_COLS.REVIEW_ID, reviewId);
    return this.store.delete(predicates);
  }

  private mapRow(resultSet: relationalStore.ResultSet): CostNote {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(COST_COLS.ID)),
      reviewId: resultSet.getString(resultSet.getColumnIndex(COST_COLS.REVIEW_ID)),
      dimension: resultSet.getString(resultSet.getColumnIndex(COST_COLS.DIMENSION)) as CostDimension,
      text: resultSet.getString(resultSet.getColumnIndex(COST_COLS.TEXT)),
      bearable: resultSet.getLong(resultSet.getColumnIndex(COST_COLS.BEARABLE)) === 1,
      createdAt: resultSet.getLong(resultSet.getColumnIndex(COST_COLS.CREATED_AT))
    };
  }
}