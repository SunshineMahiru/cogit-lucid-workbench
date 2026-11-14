import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SETTINGS_KEYS, SETTINGS_STORE_NAME } from './SettingsKeys';

/** Decides whether personal background images travel inside a user-visible backup. */
export class BackupOptionsStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  /** Opens the settings store; the choice persists across launches. */
  static async open(context: common.Context): Promise<BackupOptionsStore> {
    const prefs = await preferences.getPreferences(context, { name: SETTINGS_STORE_NAME });
    return new BackupOptionsStore(prefs);
  }

  /** Returns whether backgrounds are included; absent values mean no. */
  async includeBackgrounds(): Promise<boolean> {
    const value = await this.prefs.get(SETTINGS_KEYS.BACKUP_INCLUDE_BACKGROUND, false);
    return value === true;
  }

  /** Persists the choice. */
  async saveIncludeBackgrounds(include: boolean): Promise<void> {
    await this.prefs.put(SETTINGS_KEYS.BACKUP_INCLUDE_BACKGROUND, include);
    await this.prefs.flush();
  }
}
