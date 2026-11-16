import { relationalStore } from '@kit.ArkData';
import { Anchor } from '../../model/Anchor';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, ANCHOR_COLS } from '../DbConstants';
import { queryCount } from '../QuerySupport';

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
      [ANCHOR_COLS.ORDER]: anchor.order,
      [ANCHOR_COLS.LEVEL]: anchor.level ?? SecurityLevel.LOCAL_ONLY,
      [ANCHOR_COLS.ROOT_ID]: anchor.rootId ?? anchor.id,
      [ANCHOR_COLS.VERSION]: anchor.version ?? 1,
      [ANCHOR_COLS.STATUS]: anchor.status ?? 'active',
      [ANCHOR_COLS.CONTEXT]: anchor.context ?? '',
      [ANCHOR_COLS.REVISION_REASON]: anchor.revisionReason ?? '',
      [ANCHOR_COLS.SYNTHETIC]: anchor.synthetic === true ? 1 : 0,
      [ANCHOR_COLS.CREATED_AT]: anchor.createdAt ?? 0
    };
    return this.store.insert(DB_TABLES.ANCHOR, values);
  }

  /** Retires one anchor version; the row stays for the reviews that reference it. */
  async retire(id: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [ANCHOR_COLS.STATUS]: 'retired'
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.ANCHOR);
    predicates.equalTo(ANCHOR_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  /** Returns every version of one anchor, oldest first. */
  async queryVersions(rootId: string): Promise<Anchor[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.ANCHOR);
    predicates.equalTo(ANCHOR_COLS.ROOT_ID, rootId).orderByAsc(ANCHOR_COLS.VERSION);
    const resultSet = await this.store.query(predicates);
    try {
      const anchors: Anchor[] = [];
      while (resultSet.goToNextRow()) {
        anchors.push(this.mapRow(resultSet));
      }
      return anchors;
    } finally {
      resultSet.close();
    }
  }

  /** Returns all anchors ordered by their order field. */
  async queryAll(): Promise<Anchor[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.ANCHOR);
    predicates.orderByAsc(ANCHOR_COLS.ORDER);
    const resultSet = await this.store.query(predicates);
    try {
      const anchors: Anchor[] = [];
      while (resultSet.goToNextRow()) {
        anchors.push(this.mapRow(resultSet));
      }
      return anchors;
    } finally {
      resultSet.close();
    }
  }

  /** Returns only the versions still offered to new reviews. */
  async queryActive(): Promise<Anchor[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.ANCHOR);
    predicates.equalTo(ANCHOR_COLS.STATUS, 'active').orderByAsc(ANCHOR_COLS.ORDER);
    const resultSet = await this.store.query(predicates);
    try {
      const anchors: Anchor[] = [];
      while (resultSet.goToNextRow()) {
        anchors.push(this.mapRow(resultSet));
      }
      return anchors;
    } finally {
      resultSet.close();
    }
  }

  async countVisible(): Promise<number> {
    return queryCount(this.store, `SELECT COUNT(*) AS total FROM ${DB_TABLES.ANCHOR} WHERE level <> 'sealed'`);
  }

  private mapRow(resultSet: relationalStore.ResultSet): Anchor {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.ID)),
      text: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.TEXT)),
      source: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.SOURCE)),
      order: resultSet.getLong(resultSet.getColumnIndex(ANCHOR_COLS.ORDER)),
      level: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.LEVEL)) as SecurityLevel,
      rootId: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.ROOT_ID)),
      version: resultSet.getLong(resultSet.getColumnIndex(ANCHOR_COLS.VERSION)),
      status: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.STATUS)) as Anchor['status'],
      context: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.CONTEXT)),
      revisionReason: resultSet.getString(resultSet.getColumnIndex(ANCHOR_COLS.REVISION_REASON)),
      synthetic: resultSet.getLong(resultSet.getColumnIndex(ANCHOR_COLS.SYNTHETIC)) === 1,
      createdAt: resultSet.getLong(resultSet.getColumnIndex(ANCHOR_COLS.CREATED_AT))
    };
  }
}
