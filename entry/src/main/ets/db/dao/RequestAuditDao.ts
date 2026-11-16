import { relationalStore } from '@kit.ArkData';
import { RequestAudit } from '../../model/RequestAudit';
import { DB_TABLES, REQUEST_AUDIT_COLS } from '../DbConstants';
import { parseStringArray } from '../SafeJson';

/** Data access for the outbound request audit trail; stores ids only, never material text. */
export class RequestAuditDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts one audit row, returns the row id. */
  async insert(audit: RequestAudit): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [REQUEST_AUDIT_COLS.ID]: audit.id,
      [REQUEST_AUDIT_COLS.PROVIDER]: audit.provider,
      [REQUEST_AUDIT_COLS.HOST]: audit.host,
      [REQUEST_AUDIT_COLS.MATERIAL_IDS]: JSON.stringify(audit.materialIds),
      [REQUEST_AUDIT_COLS.LEVELS]: JSON.stringify(audit.levels),
      [REQUEST_AUDIT_COLS.CHARS]: audit.chars,
      [REQUEST_AUDIT_COLS.CONFIRMED]: audit.confirmed ? 1 : 0,
      [REQUEST_AUDIT_COLS.FELL_BACK]: audit.fellBack ? 1 : 0,
      [REQUEST_AUDIT_COLS.REMOVED_COUNT]: audit.removedCount,
      [REQUEST_AUDIT_COLS.CREATED_AT]: audit.createdAt
    };
    return this.store.insert(DB_TABLES.REQUEST_AUDIT, values);
  }

  /** Returns the newest audit rows first, capped at limit. */
  async queryRecent(limit: number): Promise<RequestAudit[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.REQUEST_AUDIT);
    predicates.orderByDesc(REQUEST_AUDIT_COLS.CREATED_AT).limitAs(limit);
    const resultSet = await this.store.query(predicates);
    try {
      const results: RequestAudit[] = [];
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet));
      }
      return results;
    } finally {
      resultSet.close();
    }
  }

  private mapRow(resultSet: relationalStore.ResultSet): RequestAudit {
    const removedIndex = resultSet.getColumnIndex(REQUEST_AUDIT_COLS.REMOVED_COUNT);
    const audit: RequestAudit = {
      id: resultSet.getString(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.ID)),
      provider: resultSet.getString(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.PROVIDER)),
      host: resultSet.getString(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.HOST)),
      materialIds: parseStringArray(resultSet.getString(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.MATERIAL_IDS))),
      levels: parseStringArray(resultSet.getString(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.LEVELS))),
      chars: resultSet.getLong(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.CHARS)),
      confirmed: resultSet.getLong(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.CONFIRMED)) !== 0,
      fellBack: resultSet.getLong(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.FELL_BACK)) !== 0,
      removedCount: removedIndex < 0 || resultSet.isColumnNull(removedIndex) ? 0 : resultSet.getLong(removedIndex),
      createdAt: resultSet.getLong(resultSet.getColumnIndex(REQUEST_AUDIT_COLS.CREATED_AT))
    };
    return audit;
  }
}