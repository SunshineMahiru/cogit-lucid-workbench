import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DB_CONFIG, DB_VERSION } from './DbConfig';
import { TABLE_CREATE_SQLS } from './schemas';

/** Opens and caches the relational store instance. */
export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;

  static async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (DbHelper.store !== null) {
      return DbHelper.store;
    }
    const store = await relationalStore.getRdbStore(context, DB_CONFIG);
    DbHelper.store = store;
    return store;
  }

  /** Opens the store, applies the schema version and executes all create-table statements. */
  static async init(context: common.Context): Promise<relationalStore.RdbStore> {
    const store = await DbHelper.getStore(context);
    store.version = DB_VERSION;
    for (const sql of TABLE_CREATE_SQLS) {
      await store.executeSql(sql);
    }
    // Older installs used the reserved word "order"; rename once if it is still present.
    try {
      await store.executeSql(`ALTER TABLE anchor RENAME COLUMN "order" TO sort_order`);
    } catch (error) {
    }
    return store;
  }
}
