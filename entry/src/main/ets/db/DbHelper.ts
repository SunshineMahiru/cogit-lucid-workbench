import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DB_CONFIG, DB_VERSION, PLAIN_DB_CONFIG } from './DbConfig';
import { TABLE_CREATE_SQLS } from './schemas';
import {
  LegacyPredictionRow,
  planLegacyPredictionMerges
} from '../prediction/PredictionLegacyMigration';

const META_ENCRYPTED = '/.db-encrypted';
const META_ATTEMPTED = '/.db-encryption-attempted';
const DOMAIN = 0x0000;
const TAG = 'CogitLucidDb';

/** Opens and caches the relational store instance. */
export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;
  private static storePromise: Promise<relationalStore.RdbStore> | null = null;
  private static schemaPromise: Promise<relationalStore.RdbStore> | null = null;
  private static plaintextFallback: boolean = false;

  /** True when the store stayed unencrypted because both rekey attempts failed. */
  static usesPlaintextFallback(): boolean {
    return DbHelper.plaintextFallback;
  }

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
    const encryptedMarker = `${context.filesDir}${META_ENCRYPTED}`;
    const attemptedMarker = `${context.filesDir}${META_ATTEMPTED}`;
    if (fileIo.accessSync(encryptedMarker)) {
      return;
    }
    if (fileIo.accessSync(attemptedMarker)) {
      DbHelper.plaintextFallback = true;
      return;
    }
    try {
      await store.rekey();
      DbHelper.writeMarker(encryptedMarker);
    } catch (error) {
      try {
        await store.rekeyEx({ encryptionKey: new Uint8Array(0) });
        DbHelper.writeMarker(encryptedMarker);
      } catch (exError) {
        // The store stays usable but unencrypted; the home page surfaces this state.
        DbHelper.plaintextFallback = true;
        DbHelper.writeMarker(attemptedMarker);
      }
    }
  }

  /** Clears the failure marker so the next launch retries encryption once. */
  static clearEncryptionFailure(context: common.Context): boolean {
    const attemptedMarker = `${context.filesDir}${META_ATTEMPTED}`;
    if (!fileIo.accessSync(attemptedMarker)) {
      return false;
    }
    try {
      fileIo.unlinkSync(attemptedMarker);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static writeMarker(path: string): void {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.closeSync(file);
    } catch (error) {
    }
  }

  private static async mergeLegacyPredictionRoots(store: relationalStore.RdbStore): Promise<void> {
    const resultSet = await store.querySql(
      `SELECT id, target, version, root_id, created_at FROM prediction`);
    const rows: LegacyPredictionRow[] = [];
    try {
      while (resultSet.goToNextRow()) {
        rows.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          target: resultSet.getString(resultSet.getColumnIndex('target')),
          version: resultSet.getLong(resultSet.getColumnIndex('version')),
          rootId: resultSet.getString(resultSet.getColumnIndex('root_id')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
    } finally {
      resultSet.close();
    }
    for (const plan of planLegacyPredictionMerges(rows)) {
      const placeholders = plan.ids.map(() => '?').join(', ');
      try {
        await store.executeSql(
          `UPDATE prediction SET root_id = ? WHERE id IN (${placeholders})`,
          [plan.rootId, ...plan.ids]);
      } catch (error) {
      }
    }
  }

  /** Opens the encrypted store; a failure is reported instead of writing plaintext. */
  private static async openStore(context: common.Context): Promise<relationalStore.RdbStore> {
    try {
      return await relationalStore.getRdbStore(context, DB_CONFIG);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'encrypted open failed: %{private}s', (error as Error).message);
      try {
        await DbHelper.rekeyPlainStore(context);
        return await relationalStore.getRdbStore(context, DB_CONFIG);
      } catch (migrationError) {
        hilog.error(DOMAIN, TAG, 'rekey migration failed: %{private}s', (migrationError as Error).message);
        throw migrationError;
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
    // Older installs used the reserved word "order"; the rename fails harmlessly once applied.
    try {
      await store.executeSql(`ALTER TABLE anchor RENAME COLUMN "order" TO sort_order`);
    } catch (error) {
    }
    // "action" is also reserved; a failure here means the column was already renamed.
    try {
      await store.executeSql(`ALTER TABLE review_result RENAME COLUMN action TO next_action`);
    } catch (error) {
    }
    // Older installs predate security levels on four record types; adding an existing column fails
    // and is ignored, which keeps this block safe to run on every launch.
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
    // Plan context columns arrived later; duplicate-column errors are expected on new installs.
    const planContextMigrations: string[] = [
      `ALTER TABLE review_result ADD COLUMN plan_id TEXT`,
      `ALTER TABLE review_result ADD COLUMN plan_node_id TEXT`,
      `ALTER TABLE plan ADD COLUMN target_date TEXT`
    ];
    for (const sql of planContextMigrations) {
      try {
        await store.executeSql(sql);
      } catch (error) {
      }
    }
    // Prediction revisions need a stable root so the latest version can be resolved; both the
    // column and the backfill are skipped when they already ran.
    try {
      await store.executeSql(`ALTER TABLE prediction ADD COLUMN root_id TEXT NOT NULL DEFAULT ''`);
    } catch (error) {
    }
    try {
      await store.executeSql(`UPDATE prediction SET root_id = id WHERE root_id = ''`);
    } catch (error) {
    }
    await DbHelper.mergeLegacyPredictionRoots(store);
    // Soft-delete flags follow the same idempotent pattern as the columns above.
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
      `CREATE INDEX IF NOT EXISTS idx_review_result_created ON review_result(created_at)`,
      `CREATE INDEX IF NOT EXISTS idx_plan_status ON plan(status, is_primary)`,
      `CREATE INDEX IF NOT EXISTS idx_plan_node_plan ON plan_node(plan_id, week_index)`,
      `CREATE INDEX IF NOT EXISTS idx_plan_item_node ON plan_item(node_id, sort_order)`,
      `CREATE INDEX IF NOT EXISTS idx_plan_link_node ON plan_link(node_id, module)`
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
