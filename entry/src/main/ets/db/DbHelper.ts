import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { DB_CONFIG, DB_VERSION, PLAIN_DB_CONFIG } from './DbConfig';
import { TABLE_CREATE_SQLS } from './schemas';

const META_ENCRYPTED = '/.db-encrypted';
const META_ATTEMPTED = '/.db-encryption-attempted';

/** Opens and caches the relational store instance. */
export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;
  private static storePromise: Promise<relationalStore.RdbStore> | null = null;
  private static schemaPromise: Promise<relationalStore.RdbStore> | null = null;
  private static forcePlain: boolean = false;

  static async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (DbHelper.store !== null) {
      return DbHelper.store;
    }
    if (DbHelper.storePromise === null) {
      DbHelper.storePromise = DbHelper.openStore(context).then(
        async (store: relationalStore.RdbStore) => {
          await DbHelper.ensureEncrypted(store, context);
          DbHelper.store = store;
          return store;
        }).catch((error: Error) => {
        DbHelper.storePromise = null;
        throw error;
      });
    }
    return DbHelper.storePromise;
  }

  /** Encrypts a database created before this version, once per device. */
  private static async ensureEncrypted(store: relationalStore.RdbStore, context: common.Context): Promise<void> {
    if (DbHelper.forcePlain) {
      return;
    }
    const encryptedMarker = `${context.filesDir}${META_ENCRYPTED}`;
    const attemptedMarker = `${context.filesDir}${META_ATTEMPTED}`;
    if (fileIo.accessSync(encryptedMarker) || fileIo.accessSync(attemptedMarker)) {
      return;
    }
    try {
      await store.rekey();
      DbHelper.writeMarker(encryptedMarker);
    } catch (error) {
      DbHelper.writeMarker(attemptedMarker);
    }
  }

  private static writeMarker(path: string): void {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.closeSync(file);
    } catch (error) {
    }
  }

  /** Opens the encrypted store, migrating a pre-encryption database on the way. */
  private static async openStore(context: common.Context): Promise<relationalStore.RdbStore> {
    const config = DbHelper.forcePlain ? PLAIN_DB_CONFIG : DB_CONFIG;
    try {
      return await relationalStore.getRdbStore(context, config);
    } catch (error) {
      if (DbHelper.forcePlain) {
        throw error;
      }
      try {
        await DbHelper.rekeyPlainStore(context);
        return await relationalStore.getRdbStore(context, DB_CONFIG);
      } catch (migrationError) {
        DbHelper.forcePlain = true;
        return relationalStore.getRdbStore(context, PLAIN_DB_CONFIG);
      }
    }
  }

  /** Opens the legacy plaintext database, asks the system to encrypt it, then closes it. */
  private static async rekeyPlainStore(context: common.Context): Promise<void> {
    const plain = await relationalStore.getRdbStore(context, PLAIN_DB_CONFIG);
    try {
      await plain.rekey();
    } finally {
      await plain.close();
    }
  }

  /** Opens the store once, applies the schema version and executes all migrations. */
  static async init(context: common.Context): Promise<relationalStore.RdbStore> {
    if (DbHelper.schemaPromise === null) {
      DbHelper.schemaPromise = DbHelper.setup(context).catch((error: Error) => {
        DbHelper.schemaPromise = null;
        throw error;
      });
    }
    return DbHelper.schemaPromise;
  }

  private static async setup(context: common.Context): Promise<relationalStore.RdbStore> {
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
    // "action" is also reserved; older review tables still use it.
    try {
      await store.executeSql(`ALTER TABLE review_result RENAME COLUMN action TO next_action`);
    } catch (error) {
    }
    // Older installs predate security levels on four record types.
    const levelMigrations: string[] = [
      `ALTER TABLE prediction ADD COLUMN level TEXT NOT NULL DEFAULT 'local_only'`,
      `ALTER TABLE anchor ADD COLUMN level TEXT NOT NULL DEFAULT 'local_only'`,
      `ALTER TABLE status_record ADD COLUMN level TEXT NOT NULL DEFAULT 'local_only'`,
      `ALTER TABLE review_result ADD COLUMN level TEXT NOT NULL DEFAULT 'local_only'`
    ];
    for (const sql of levelMigrations) {
      try {
        await store.executeSql(sql);
      } catch (error) {
      }
    }
    // Prediction revisions need a stable root so the latest version can be resolved.
    try {
      await store.executeSql(`ALTER TABLE prediction ADD COLUMN root_id TEXT NOT NULL DEFAULT ''`);
    } catch (error) {
    }
    try {
      await store.executeSql(`UPDATE prediction SET root_id = id WHERE root_id = ''`);
    } catch (error) {
    }
    const deleteMigrations: string[] = [
      `ALTER TABLE relation ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0`,
      `ALTER TABLE status_record ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0`
    ];
    for (const sql of deleteMigrations) {
      try {
        await store.executeSql(sql);
      } catch (error) {
      }
    }
    const indexSqls: string[] = [
      `CREATE INDEX IF NOT EXISTS idx_event_timestamp ON event(timestamp)`,
      `CREATE INDEX IF NOT EXISTS idx_prediction_status_date ON prediction(status, settlement_date)`,
      `CREATE INDEX IF NOT EXISTS idx_status_record_date ON status_record(date)`,
      `CREATE INDEX IF NOT EXISTS idx_review_result_created ON review_result(created_at)`
    ];
    for (const sql of indexSqls) {
      try {
        await store.executeSql(sql);
      } catch (error) {
      }
    }
    return store;
  }
}
