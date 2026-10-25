import { relationalStore } from '@kit.ArkData';
import { DB_CONFIG } from './DbConfig';
import { TABLE_CREATE_SQLS } from './schemas';

/** Opens and caches the relational store instance. */
export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;

  static async getStore(context: Context): Promise<relationalStore.RdbStore> {
    if (DbHelper.store !== null) {
      return DbHelper.store;
    }
    const store = await relationalStore.getRdbStore(context, DB_CONFIG);
    DbHelper.store = store;
    return store;
  }

  /** Opens the store and executes all create-table statements. */
  static async init(context: Context): Promise<relationalStore.RdbStore> {
    const store = await DbHelper.getStore(context);
    for (const sql of TABLE_CREATE_SQLS) {
      await store.executeSql(sql);
    }
    return store;
  }
}
