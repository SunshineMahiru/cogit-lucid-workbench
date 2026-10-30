import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { DbHelper } from '../db/DbHelper';
import { DB_TABLES } from '../db/DbConstants';

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
    const store = await DbHelper.init(context);
    await store.restore(localPath);
    return true;
  }

  static async clearAll(context: common.Context): Promise<void> {
    const store = await DbHelper.init(context);
    const tables: string[] = [
      DB_TABLES.EVENT, DB_TABLES.DECISION, DB_TABLES.RELATION, DB_TABLES.PREDICTION,
      DB_TABLES.ANCHOR, DB_TABLES.STATUS_RECORD, DB_TABLES.REVIEW_RESULT
    ];
    for (const table of tables) {
      await store.executeSql(`DELETE FROM ${table}`);
    }
  }
}
