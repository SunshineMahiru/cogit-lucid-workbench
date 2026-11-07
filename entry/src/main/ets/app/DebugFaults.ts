import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

const ENCRYPTION_FLAG = '/.debug-encryption-fallback';
const RESTORE_FLAG = '/.debug-restore-failure';

/**
 * Debug-only switches used to exercise failure branches on a device.
 * The ability injects the build mode at startup, so release builds never honour a flag.
 */
export class DebugFaults {
  private static debug: boolean = false;

  /** Called once from the ability with BuildProfile.DEBUG. */
  static setDebug(enabled: boolean): void {
    DebugFaults.debug = enabled;
  }

  static encryptionFallback(context: common.Context): boolean {
    return DebugFaults.has(context, ENCRYPTION_FLAG);
  }

  static restoreFailure(context: common.Context): boolean {
    return DebugFaults.has(context, RESTORE_FLAG);
  }

  static enableEncryptionFallback(context: common.Context): void {
    DebugFaults.create(context, ENCRYPTION_FLAG);
  }

  static enableRestoreFailure(context: common.Context): void {
    DebugFaults.create(context, RESTORE_FLAG);
  }

  /** Removes both debug flags; the caller decides what to tell the user. */
  static clear(context: common.Context): boolean {
    if (!DebugFaults.debug) {
      return false;
    }
    let removed = false;
    for (const name of [ENCRYPTION_FLAG, RESTORE_FLAG]) {
      const path = `${context.filesDir}${name}`;
      try {
        if (fileIo.accessSync(path)) {
          fileIo.unlinkSync(path);
          removed = true;
        }
      } catch (error) {
        // A flag that cannot be removed simply stays; the debug UI reports the result.
      }
    }
    return removed;
  }

  private static has(context: common.Context, name: string): boolean {
    if (!DebugFaults.debug) {
      return false;
    }
    try {
      return fileIo.accessSync(`${context.filesDir}${name}`);
    } catch (error) {
      return false;
    }
  }

  private static create(context: common.Context, name: string): void {
    if (!DebugFaults.debug) {
      return;
    }
    try {
      const file = fileIo.openSync(`${context.filesDir}${name}`,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.closeSync(file);
    } catch (error) {
      // Writing the flag is best-effort; the debug UI reports failure through the caller.
    }
  }
}
