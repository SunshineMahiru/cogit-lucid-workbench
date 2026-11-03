import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { DbHelper } from '../db/DbHelper';
import { DB_TABLES } from '../db/DbConstants';
import { SETTINGS_STORE_NAME } from './SettingsKeys';
import { SecretStore } from './SecretStore';

/** Local database backup, restore and full-data clearing. */
export class BackupService {
  static async backupToUser(context: common.Context): Promise<string> {
    const store = await DbHelper.init(context);
    const directory = `${context.filesDir}/backups`;
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }
    const fileName = `cogit-backup-${Date.now()}.db`;
    const filePath = `${directory}/${fileName}`;
    await store.backup(filePath);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    if (uris.length === 0) {
      return '';
    }
    await fileIo.copyFile(filePath, uris[0]);
    return fileName;
  }

  static async restoreFromUser(context: common.Context): Promise<boolean> {
    const uris = await new picker.DocumentViewPicker(context).select();
    if (uris.length === 0) {
      return false;
    }
    const directory = `${context.filesDir}/backups`;
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }
    const localPath = `${directory}/restore-${Date.now()}.db`;
    await fileIo.copyFile(uris[0], localPath);
    try {
      if (!BackupService.isSqliteFile(localPath)) {
        throw new Error('选择的文件不是本应用的数据库备份');
      }
      const store = await DbHelper.init(context);
      await store.backup(`${directory}/pre-restore-${Date.now()}.db`);
      await store.restore(localPath);
      return true;
    } finally {
      try {
        fileIo.unlinkSync(localPath);
      } catch (error) {
      }
    }
  }

  /** Checks the 16-byte SQLite header before handing a file to the store. */
  private static isSqliteFile(path: string): boolean {
    const expected: number[] = [83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0];
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const header = new ArrayBuffer(16);
        const read = fileIo.readSync(file.fd, header);
        if (read < 16) {
          return false;
        }
        const bytes = new Uint8Array(header);
        for (let index = 0; index < expected.length; index++) {
          if (bytes[index] !== expected[index]) {
            return false;
          }
        }
        return true;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (error) {
      return false;
    }
  }

  static async clearAll(context: common.Context): Promise<void> {
    const store = await DbHelper.init(context);
    const tables: string[] = [
      DB_TABLES.EVENT, DB_TABLES.DECISION, DB_TABLES.RELATION, DB_TABLES.PREDICTION,
      DB_TABLES.ANCHOR, DB_TABLES.STATUS_RECORD, DB_TABLES.REVIEW_RESULT
    ];
    store.beginTransaction();
    try {
      for (const table of tables) {
        await store.executeSql(`DELETE FROM ${table}`);
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw error;
    }
    const stores: string[] = [
      SETTINGS_STORE_NAME, 'cogit_profile', 'cogit_page_backgrounds',
      'review_draft_store', 'cogit_llm_spend', 'cogit_onboarding'
    ];
    for (const name of stores) {
      try {
        const prefs = await preferences.getPreferences(context, { name: name });
        await prefs.clear();
        await prefs.flush();
      } catch (error) {
      }
    }
    await SecretStore.clear();
    const directories: string[] = ['page-backgrounds', 'profile', 'exports', 'backups'];
    for (const name of directories) {
      BackupService.removeDirectory(`${context.filesDir}/${name}`);
    }
  }

  private static removeDirectory(path: string): void {
    try {
      if (!fileIo.accessSync(path)) {
        return;
      }
      for (const name of fileIo.listFileSync(path)) {
        fileIo.unlinkSync(`${path}/${name}`);
      }
    } catch (error) {
    }
  }
}
