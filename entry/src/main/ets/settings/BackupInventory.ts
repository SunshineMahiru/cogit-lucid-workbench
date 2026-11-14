import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

/** One safety copy the app kept before a restore. */
export interface BackupCopy {
  name: string;
  path: string;
  bytes: number;
  /** Epoch milliseconds parsed from the file name; zero when unreadable */
  createdAt: number;
}

const PREFIX = 'pre-restore-';

/** Lists and removes the local safety copies written before each restore. */
export class BackupInventory {
  private static directory(context: common.Context): string {
    return `${context.filesDir}/backups`;
  }

  /** Returns the safety copies, newest first; an absent folder reads as empty. */
  static async list(context: common.Context): Promise<BackupCopy[]> {
    const directory = BackupInventory.directory(context);
    if (!fileIo.accessSync(directory)) {
      return [];
    }
    const names = fileIo.listFileSync(directory);
    const copies: BackupCopy[] = [];
    for (const name of names) {
      if (!name.startsWith(PREFIX) || !name.endsWith('.db')) {
        continue;
      }
      const path = `${directory}/${name}`;
      let bytes = 0;
      try {
        bytes = fileIo.statSync(path).size;
      } catch (error) {
        bytes = 0;
      }
      copies.push({
        name: name,
        path: path,
        bytes: bytes,
        createdAt: BackupInventory.stampOf(name)
      });
    }
    copies.sort((left: BackupCopy, right: BackupCopy) => right.createdAt - left.createdAt);
    return copies;
  }

  /** Removes every safety copy and returns how many files were deleted. */
  static async deleteAll(context: common.Context): Promise<number> {
    const copies = await BackupInventory.list(context);
    let removed = 0;
    for (const copy of copies) {
      try {
        fileIo.unlinkSync(copy.path);
        removed += 1;
      } catch (error) {
      }
    }
    return removed;
  }

  /** Parses the timestamp embedded in `pre-restore-<stamp>.db`. */
  private static stampOf(name: string): number {
    const body = name.substring(PREFIX.length, name.length - 3);
    const value = Number(body);
    return Number.isFinite(value) ? value : 0;
  }
}
