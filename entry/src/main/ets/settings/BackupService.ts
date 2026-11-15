import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences, relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { DbHelper } from '../db/DbHelper';
import { DB_TABLES, DB_TABLES_CHILD_FIRST, LEVELED_TABLES } from '../db/DbConstants';
import { copyBetween } from '../app/DocumentTransfer';
import { DebugFaults } from '../app/DebugFaults';
import { SETTINGS_STORE_NAME } from './SettingsKeys';
import { SecretStore } from './SecretStore';


import { SettingsStore } from './SettingsStore';
import { BackupOptionsStore } from './BackupOptionsStore';
import { AppSettings } from './AppSettings';
import { ProfileStore, Profile } from '../profile/ProfileStore';
import { PageBackgroundStore, GLOBAL_BACKGROUND_KEY } from './PageBackgroundStore';
import { PAGE_BACKGROUND_GROUPS } from './PageBackgroundService';
import { notifyPageBackgroundChanged } from './PageBackgroundBus';
import { notifyProfileRefresh } from '../app/ProfileRefreshBus';
import { profileCache } from '../profile/ProfileCache';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';
import { isExportableRow, deleteSqlFor } from './BackupRows';

const BUNDLE_VERSION = 2;
const LEGACY_BUNDLE_VERSION = 1;
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

/** One table's rows, as the column map the store returns; sealed rows never appear here. */
export interface BundleTable {
  name: string;
  rows: Record<string, string | null>[];
}

interface BackupBundle {
  version: number;
  createdAt: number;
  /** Present in version 1 bundles only; version 2 carries rows instead of a snapshot. */
  database?: string;
  tables?: BundleTable[];
  profile: BundleProfile;
  settings: AppSettings;
  backgrounds: BundleBackground[];
  alphas: BundleAlpha[];
  globalAlpha: number;
  opacity: number;
}

interface StagedBackground {
  key: string;
  path: string;
}

/** Side data decoded into a staging folder before anything live is touched. */
interface StagedSideData {
  avatarPath: string;
  backgrounds: StagedBackground[];
}

/** Result of one restore attempt; PARTIAL means the database landed but side data did not. */
export enum RestoreOutcome {
  CANCELLED = 'cancelled',
  RESTORED = 'restored',
  PARTIAL = 'partial'
}

/** Per-category result of one restore; a single success line must never hide a failed category. */
export interface RestoreReport {
  outcome: RestoreOutcome;
  /** Whether records were written from the backup */
  records: boolean;
  /** Whether settings were applied */
  settings: boolean;
  /** Whether the identity block was applied */
  profile: boolean;
  /** Whether background images were applied */
  backgrounds: boolean;
  /** One line describing the background category, including the case with no pictures */
  backgroundNote: string;
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
    const bundle = await BackupService.buildBundle(context, store, stamp);
    const fileName = `cogit-backup-${stamp}${BUNDLE_SUFFIX}`;
    const bundlePath = `${directory}/${fileName}`;
    await BackupService.writeText(bundlePath, JSON.stringify(bundle));
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    if (uris.length === 0) {
      BackupService.removeQuietly(bundlePath);
      return '';
    }
    await copyBetween(bundlePath, uris[0]);
    BackupService.removeQuietly(bundlePath);
    return fileName;
  }

  /** Reads every table into plain rows; sealed records stay on this device. */
  private static async readTables(store: relationalStore.RdbStore): Promise<BundleTable[]> {
    const result: BundleTable[] = [];
    for (const name of DB_TABLES_CHILD_FIRST) {
      const rows: Record<string, string | null>[] = [];
      const set = await store.querySql(`SELECT * FROM ${name}`);
      try {
        const columns: string[] = set.columnNames;
        while (set.goToNextRow()) {
          const row: Record<string, string | null> = {};
          for (let index = 0; index < columns.length; index += 1) {
            const column: string = columns[index];
            row[column] = set.isColumnNull(index) ? null : set.getString(index);
          }
          if (isExportableRow(row)) {
            rows.push(row);
          }
        }
      } finally {
        set.close();
      }
      result.push({ name: name, rows: rows });
    }
    return result;
  }

  /**
   * Replaces live rows with the bundle's rows. Tables that carry a level keep their sealed rows
   * untouched, so a restore neither carries sealed content in nor wipes what is already local.
   */
  private static async writeTables(store: relationalStore.RdbStore, tables: BundleTable[]): Promise<void> {
    const rowsByName = new Map<string, Record<string, string | null>[]>();
    for (const table of tables) {
      rowsByName.set(table.name, table.rows);
    }
    const leveled = new Set<string>(LEVELED_TABLES);
    store.beginTransaction();
    try {
      for (const name of DB_TABLES_CHILD_FIRST) {
        await store.executeSql(deleteSqlFor(name, leveled.has(name)));
      }
      const parentsFirst = DB_TABLES_CHILD_FIRST.slice().reverse();
      for (const name of parentsFirst) {
        const rows = rowsByName.get(name) ?? [];
        for (const row of rows) {
          await store.insert(name, row as relationalStore.ValuesBucket);
        }
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw error;
    }
  }

  private static removeQuietly(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (error) {
    }
  }

  private static async buildBundle(context: common.Context, store: relationalStore.RdbStore,
    stamp: number): Promise<BackupBundle> {
    const profile = await (await ProfileStore.open(context)).load();
    const settings = await (await SettingsStore.open(context)).load();
    settings.llmApiKey = '';
    const backgroundStore = await PageBackgroundStore.open(context);
    const backupOptions = await BackupOptionsStore.open(context);
    const includeBackgrounds = await backupOptions.includeBackgrounds();
    const backgrounds: BundleBackground[] = [];
    const keys: string[] = [GLOBAL_BACKGROUND_KEY];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      keys.push(group.key);
    }
    if (includeBackgrounds) {
      for (const key of keys) {
        const path = await backgroundStore.get(key);
        if (path.length === 0 || !fileIo.accessSync(path)) {
          continue;
        }
        backgrounds.push({ key: key, data: BackupService.encode(BackupService.readBytes(path)) });
      }
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
      tables: await BackupService.readTables(store),
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

  static async restoreFromUser(context: common.Context): Promise<RestoreReport> {
    const uris = await new picker.DocumentViewPicker(context).select();
    if (uris.length === 0) {
      return {
        outcome: RestoreOutcome.CANCELLED,
        records: false,
        settings: false,
        profile: false,
        backgrounds: false,
        backgroundNote: '未选择文件'
      };
    }
    const directory = `${context.filesDir}/backups`;
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }
    const stamp = Date.now();
    const bundlePath = `${directory}/restore-${stamp}${BUNDLE_SUFFIX}`;
    const databasePath = `${directory}/restore-${stamp}.db`;
    await copyBetween(uris[0], bundlePath);
    try {
      const bundle = JSON.parse(await BackupService.readText(bundlePath)) as BackupBundle;
      const rowBundle = bundle.version === BUNDLE_VERSION && Array.isArray(bundle.tables);
      const legacyBundle = bundle.version === LEGACY_BUNDLE_VERSION &&
        typeof bundle.database === 'string' && bundle.database.length > 0;
      if (!rowBundle && !legacyBundle) {
        throw new Error('备份格式不支持');
      }
      if (legacyBundle) {
        await BackupService.writeBytes(databasePath, BackupService.decode(bundle.database as string));
        if (!(await BackupService.isDatabaseFile(context, databasePath))) {
          throw new Error('备份内的数据库无效');
        }
      }
      // Decode every picture first: a bad payload fails here, before the live database moves.
      const staged = await BackupService.stageSideData(context, bundle, stamp);
      const store = await DbHelper.init(context);
      await store.backup(`${directory}/pre-restore-${stamp}.db`);
      let records = true;
      try {
        if (rowBundle) {
          await BackupService.writeTables(store, bundle.tables as BundleTable[]);
        } else {
          await store.restore(databasePath);
        }
      } catch (recordError) {
        records = false;
      }
      let profile = true;
      try {
        await BackupService.commitProfile(context, bundle.profile, staged.avatarPath, stamp);
      } catch (profileError) {
        profile = false;
      }
      let settings = true;
      try {
        await SettingsStore.savePreferencesOnly(context, bundle.settings);
      } catch (settingsError) {
        settings = false;
      }
      let backgrounds = true;
      let backgroundNote = bundle.backgrounds.length === 0 ?
        '备份未包含背景图片，本机保持现状' : '背景图片已恢复';
      if (bundle.backgrounds.length > 0) {
        try {
          await BackupService.commitBackgrounds(context, bundle, staged, stamp);
        } catch (backgroundError) {
          backgrounds = false;
          backgroundNote = '背景图片恢复失败，本机保持原样';
        }
      }
      notifyProfileRefresh();
      notifyPageBackgroundChanged();
      notifyHomeRefresh();
      const outcome = records && profile && settings && backgrounds ?
        RestoreOutcome.RESTORED : RestoreOutcome.PARTIAL;
      return {
        outcome: outcome,
        records: records,
        settings: settings,
        profile: profile,
        backgrounds: backgrounds,
        backgroundNote: backgroundNote
      };
    } finally {
      try {
        fileIo.unlinkSync(bundlePath);
        fileIo.unlinkSync(databasePath);
      } catch (error) {
      }
      const staging = `${context.filesDir}/restore-staging-${stamp}`;
      BackupService.removeDirectory(staging);
      try {
        fileIo.rmdirSync(staging);
      } catch (error) {
      }
    }
  }

  /** Decodes avatar and backgrounds into a staging folder; throws before any live data changes. */
  private static async stageSideData(context: common.Context, bundle: BackupBundle,
    stamp: number): Promise<StagedSideData> {
    const staging = `${context.filesDir}/restore-staging-${stamp}`;
    if (!fileIo.accessSync(staging)) {
      fileIo.mkdirSync(staging, true);
    }
    const staged: StagedSideData = { avatarPath: '', backgrounds: [] };
    if (typeof bundle.profile.avatarData === 'string' && bundle.profile.avatarData.length > 0) {
      const avatarPath = `${staging}/avatar.png`;
      await BackupService.writeBytes(avatarPath, BackupService.decode(bundle.profile.avatarData));
      staged.avatarPath = avatarPath;
    }
    let index = 0;
    for (const item of bundle.backgrounds) {
      const path = `${staging}/background-${index}-${item.key}.png`;
      await BackupService.writeBytes(path, BackupService.decode(item.data));
      staged.backgrounds.push({ key: item.key, path: path });
      index += 1;
    }
    return staged;
  }

  /** Moves the staged avatar into the profile folder and saves the identity fields. */
  private static async commitProfile(context: common.Context, profile: BundleProfile,
    stagedAvatar: string, stamp: number): Promise<void> {
    if (DebugFaults.restoreFailure(context)) {
      throw new Error('debug restore failure');
    }
    let avatarPath = '';
    if (stagedAvatar.length > 0) {
      const directory = `${context.filesDir}/profile`;
      if (!fileIo.accessSync(directory)) {
        fileIo.mkdirSync(directory, true);
      }
      avatarPath = `${directory}/avatar-restored-${stamp}.png`;
      fileIo.renameSync(stagedAvatar, avatarPath);
    }
    const store = await ProfileStore.open(context);
    const restored: Profile = {
      nickname: profile.nickname,
      signature: profile.signature,
      title: profile.title,
      avatarPath: avatarPath
    };
    await store.save(restored);
    profileCache.set(restored);
  }

  /** Moves staged background files into place and writes their keys and opacities. */
  private static async commitBackgrounds(context: common.Context, bundle: BackupBundle,
    staged: StagedSideData, stamp: number): Promise<void> {
    const directory = `${context.filesDir}/page-backgrounds`;
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }
    const store = await PageBackgroundStore.open(context);
    for (const item of staged.backgrounds) {
      const path = `${directory}/restored-${item.key}-${stamp}.png`;
      fileIo.renameSync(item.path, path);
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
    const tables: string[] = DB_TABLES_CHILD_FIRST;
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
      'review_draft_store', 'cogit_llm_spend', 'cogit_onboarding', 'cogit_note_editor'
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
