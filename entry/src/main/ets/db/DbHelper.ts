import { relationalStore } from '@kit.ArkData';
import { DB_CONFIG } from './DbConfig';

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
}
