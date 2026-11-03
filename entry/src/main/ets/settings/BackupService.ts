import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { DbHelper } from '../db/DbHelper';
import { DB_TABLES } from '../db/DbConstants';
import { SETTINGS_STORE_NAME } from './SettingsKeys';
import { SecretStore } from './SecretStore';
import { SettingsStore } from './SettingsStore';
import { AppSettings } from './AppSettings';
import { ProfileStore, Profile } from '../profile/ProfileStore';
import { PageBackgroundStore, GLOBAL_BACKGROUND_KEY } from './PageBackgroundStore';
import { PAGE_BACKGROUND_GROUPS } from './PageBackgroundService';
import { notifyPageBackgroundChanged } from './PageBackgroundBus';
import { notifyProfileRefresh } from '../app/ProfileRefreshBus';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

const BUNDLE_VERSION = 1;
const BUNDLE_SUFFIX = '.cogitbackup';

interface BundleBackground {
  key: string;
  data: string;
}

interface BundleAlpha {
  key: string;
  value: number;
}

interface BundleProfile extends Profile {
  avatarData: string;
}

interface BackupBundle {
  version: number;
  createdAt: number;
  database: string;
  profile: BundleProfile;
  settings: AppSettings;
  backgrounds: BundleBackground[];
  alphas: BundleAlpha[];
  globalAlpha: number;
  opacity: number;
}

/** Portable backup: one JSON file carrying the database, identity, settings and pictures. */
export class BackupService {
  static async backupToUser(context: common.Context): Promise<string> {
    const directory = `${context.filesDir}/backups`;
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }
    const stamp = Date.now();
    const store = await DbHelper.init(context);
    const databasePath = `${directory}/snapshot-${stamp}.db`;
    await store.backup(databasePath);
    try {
      const bundle = await BackupService.buildBundle(context, databasePath, stamp);
      const fileName = `cogit-backup-${stamp}${BUNDLE_SUFFIX}`;
      const bundlePath = `${directory}/${fileName}`;
      await BackupService.writeText(bundlePath, JSON.stringify(bundle));
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) {
        return '';
      }
      await fileIo.copyFile(bundlePath, uris[0]);
      return fileName;
    } finally {
      try {
        fileIo.unlinkSync(databasePath);
      } catch (error) {
      }
    }
  }

  private static async buildBundle(context: common.Context, databasePath: string,
    stamp: number): Promise<BackupBundle> {
    const profile = await (await ProfileStore.open(context)).load();
    const settings = await (await SettingsStore.open(context)).load();
    settings.llmApiKey = '';
    const backgroundStore = await PageBackgroundStore.open(context);
    const backgrounds: BundleBackground[] = [];
    const keys: string[] = [GLOBAL_BACKGROUND_KEY];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      keys.push(group.key);
    }
    for (const key of keys) {
      const path = await backgroundStore.get(key);
      if (path.length === 0 || !fileIo.accessSync(path)) {
        continue;
      }
      backgrounds.push({ key: key, data: BackupService.encode(BackupService.readBytes(path)) });
    }
    const alphas: BundleAlpha[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      alphas.push({ key: group.key, value: await backgroundStore.getGroupAlpha(group.key) });
    }
    const avatarData = profile.avatarPath.length > 0 && fileIo.accessSync(profile.avatarPath) ?
      BackupService.encode(BackupService.readBytes(profile.avatarPath)) : '';
    return {
      version: BUNDLE_VERSION,
      createdAt: stamp,
      database: BackupService.encode(BackupService.readBytes(databasePath)),
      profile: {
        nickname: profile.nickname,
        signature: profile.signature,
        title: profile.title,
        avatarPath: '',
        avatarData: avatarData
      },
      settings: settings,
      backgrounds: backgrounds,
      alphas: alphas,
      globalAlpha: await backgroundStore.getGlobalAlpha(),
      opacity: await backgroundStore.getOpacity()
    };
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
    const stamp = Date.now();
    const bundlePath = `${directory}/restore-${stamp}${BUNDLE_SUFFIX}`;
    const databasePath = `${directory}/restore-${stamp}.db`;
    await fileIo.copyFile(uris[0], bundlePath);
    try {
      const bundle = JSON.parse(await BackupService.readText(bundlePath)) as BackupBundle;
      if (bundle.version !== BUNDLE_VERSION || typeof bundle.database !== 'string' ||
        bundle.database.length === 0) {
        throw new Error('备份格式不支持');
      }
      await BackupService.writeBytes(databasePath, BackupService.decode(bundle.database));
      if (!(await BackupService.isDatabaseFile(context, databasePath))) {
        throw new Error('备份内的数据库无效');
      }
      const store = await DbHelper.init(context);
      await store.backup(`${directory}/pre-restore-${stamp}.db`);
      await store.restore(databasePath);
      await BackupService.restoreProfile(context, bundle.profile, stamp);
      await SettingsStore.savePreferencesOnly(context, bundle.settings);
      await BackupService.restoreBackgrounds(context, bundle, stamp);
      notifyProfileRefresh();
      notifyPageBackgroundChanged();
      notifyHomeRefresh();
      return true;
    } finally {
      try {
        fileIo.unlinkSync(bundlePath);
        fileIo.unlinkSync(databasePath);
      } catch (error) {
      }
    }
  }

  private static async restoreProfile(context: common.Context, profile: BundleProfile,
    stamp: number): Promise<void> {
    let avatarPath = '';
    if (typeof profile.avatarData === 'string' && profile.avatarData.length > 0) {
      const directory = `${context.filesDir}/profile`;
      if (!fileIo.accessSync(directory)) {
        fileIo.mkdirSync(directory, true);
      }
      avatarPath = `${directory}/avatar-restored-${stamp}.png`;
      await BackupService.writeBytes(avatarPath, BackupService.decode(profile.avatarData));
    }
    const store = await ProfileStore.open(context);
    await store.save({
      nickname: profile.nickname,
      signature: profile.signature,
      title: profile.title,
      avatarPath: avatarPath
    });
  }

  private static async restoreBackgrounds(context: common.Context, bundle: BackupBundle,
    stamp: number): Promise<void> {
    const directory = `${context.filesDir}/page-backgrounds`;
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }
    const store = await PageBackgroundStore.open(context);
    for (const item of bundle.backgrounds) {
      const path = `${directory}/restored-${item.key}-${stamp}.png`;
      await BackupService.writeBytes(path, BackupService.decode(item.data));
      await store.set(item.key, path);
    }
    for (const item of bundle.alphas) {
      await store.setGroupAlpha(item.key, item.value);
    }
    await store.setGlobalAlpha(bundle.globalAlpha);
    await store.setOpacity(bundle.opacity);
  }

  private static readBytes(path: string): Uint8Array {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const size = fileIo.statSync(path).size;
      const buffer = new ArrayBuffer(size);
      fileIo.readSync(file.fd, buffer);
      return new Uint8Array(buffer);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static async writeBytes(path: string, bytes: Uint8Array): Promise<void> {
    const file = await fileIo.open(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE |
      fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, bytes.buffer as ArrayBuffer);
    } finally {
      await fileIo.close(file);
    }
  }

  private static async writeText(path: string, text: string): Promise<void> {
    const file = await fileIo.open(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE |
      fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, text);
    } finally {
      await fileIo.close(file);
    }
  }

  private static async readText(path: string): Promise<string> {
    const bytes = BackupService.readBytes(path);
    return util.TextDecoder.create('utf-8').decodeToString(bytes);
  }

  private static encode(bytes: Uint8Array): string {
    return new util.Base64Helper().encodeToStringSync(bytes);
  }

  private static decode(text: string): Uint8Array {
    return new util.Base64Helper().decodeSync(text);
  }

  /** Accepts a plaintext SQLite file or an encrypted store backup on devices that support it. */
  private static async isDatabaseFile(context: common.Context, path: string): Promise<boolean> {
    if (BackupService.isSqliteFile(path)) {
      return true;
    }
    try {
      if (!fileIo.accessSync(`${context.filesDir}/.db-encrypted`)) {
        return false;
      }
      return fileIo.statSync(path).size >= 4096;
    } catch (error) {
      return false;
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
