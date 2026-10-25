import { relationalStore } from '@kit.ArkData';
import { Anchor } from '../model/Anchor';
import { DB_TABLES, ANCHOR_COLS } from '../DbConstants';

/** Data access for the anchor table. */
export class AnchorDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts an anchor, returns the row id. */
  async insert(anchor: Anchor): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [ANCHOR_COLS.ID]: anchor.id,
      [ANCHOR_COLS.TEXT]: anchor.text,
      [ANCHOR_COLS.SOURCE]: anchor.source,
      [ANCHOR_COLS.ORDER]: anchor.order
    };
    return this.store.insert(DB_TABLES.ANCHOR, values);
  }

  /** Returns all anchors ordered by their order field. */
  async queryAll(): Promise<Anchor[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.ANCHOR);
    predicates.orderByAsc(ANCHOR_COLS.ORDER);
    const resultSet = await this.store.query(predicates);
    const anchors: Anchor[] = [];
    while (resultSet.goToNextRow()) {
      anchors.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return anchors;
  }

  private mapRow(resultSet: relationalStore.ResultSet): Anchor {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.ID)),
      text: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.TEXT)),
      source: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.SOURCE)),
      order: resultSet.getLong(resultSet.getColumnIndex(ANCHOR_COLS.ORDER))
    };
  }
}
