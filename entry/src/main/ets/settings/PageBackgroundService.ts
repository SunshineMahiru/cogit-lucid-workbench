import { fileIo, hash, picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { PageBackgroundStore, GLOBAL_BACKGROUND_KEY } from './PageBackgroundStore';
import { notifyPageBackgroundChanged } from './PageBackgroundBus';

export interface PageBackgroundGroup {
  key: string;
  label: string;
}

export interface BackgroundGroupState {
  key: string;
  label: string;
  applied: boolean;
  own: boolean;
  following: boolean;
}

export interface BackgroundRecoveryResult {
  converted: number;
  cleared: number;
  failed: number;
}

const MAX_WIDTH = 1080;
const MAX_HEIGHT = 1920;

/** Where the picture comes from; the three sources share one normalization path. */
export enum BackgroundImageSource {
  GALLERY = 'gallery',
  CAMERA = 'camera',
  FILES = 'files'
}

/** Page groups that can each carry a different local background image. */
export const PAGE_BACKGROUND_GROUPS: PageBackgroundGroup[] = [
  { key: 'home', label: '首页' },
  { key: 'note', label: '速记' },
  { key: 'prediction', label: '预测' },
  { key: 'review', label: '复盘' },
  { key: 'anchor', label: '锚点' },
  { key: 'relation', label: '关系' },
  { key: 'status', label: '状态' },
  { key: 'settings', label: '设置' }
];

/** Maps a route name to the page group that owns its background. */
export function backgroundKeyForRoute(route: string): string {
  if (route === 'home') {
    return 'home';
  }
  if (route === 'note_edit' || route === 'note_list' || route === 'note_detail') {
    return 'note';
  }
  if (route === 'prediction_list' || route === 'prediction_detail' || route === 'prediction_stats' ||
    route === 'prediction_create' || route === 'prediction_settle') {
    return 'prediction';
  }
  if (route === 'review' || route === 'review_agent' || route === 'review_weekly' ||
    route === 'review_history' || route === 'review_detail') {
    return 'review';
  }
  if (route === 'anchor') {
    return 'anchor';
  }
  if (route === 'relation' || route === 'relation_detail' || route === 'relation_edit' ||
    route === 'relation_graph') {
    return 'relation';
  }
  if (route === 'status' || route === 'status_history' || route === 'status_edit') {
    return 'status';
  }
  if (route === 'settings' || route === 'background_apply') {
    return 'settings';
  }
  return 'home';
}

/** Picks an image, normalizes it to PNG, then applies it to one group or all groups. */
export class PageBackgroundService {
  /** Opens the gallery and keeps the normalized image as the staged ("pending") one. */
  static async pickFromGallery(context: common.Context): Promise<string> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result = await new photoAccessHelper.PhotoViewPicker().select(options);
    if (result.photoUris.length === 0) {
      return '';
    }
    return PageBackgroundService.stageImage(result.photoUris[0], context);
  }

  /** Opens the system camera in photo mode; a cancelled shot leaves the staged image alone. */
  static async pickFromCamera(context: common.Context): Promise<string> {
    const result = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      saveUri: ''
    });
    if (result.resultCode !== 0 || result.resultUri.length === 0) {
      return '';
    }
    return PageBackgroundService.stageImage(result.resultUri, context);
  }

  /** Opens the document picker limited to picture suffixes. */
  static async pickFromFiles(context: common.Context): Promise<string> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['图片|.png,.jpg,.jpeg,.webp,.bmp,.heic,.heif'];
    const uris = await new picker.DocumentViewPicker(context).select(options);
    if (uris.length === 0) {
      return '';
    }
    return PageBackgroundService.stageImage(uris[0], context);
  }

  static async getPending(context: common.Context): Promise<string> {
    const store = await PageBackgroundStore.open(context);
    return store.getPending();
  }

  /** Routes a picked source through the matching system picker. */
  static async pick(source: BackgroundImageSource, context: common.Context): Promise<string> {
    if (source === BackgroundImageSource.CAMERA) {
      return PageBackgroundService.pickFromCamera(context);
    }
    if (source === BackgroundImageSource.FILES) {
      return PageBackgroundService.pickFromFiles(context);
    }
    return PageBackgroundService.pickFromGallery(context);
  }

  /** Picks a replacement for the staged image and keeps the previous selection intact on cancel. */
  static async replacePending(source: BackgroundImageSource, context: common.Context): Promise<string> {
    const store = await PageBackgroundStore.open(context);
    const previous = await store.getPending();
    const picked = await PageBackgroundService.pick(source, context);
    if (picked.length === 0) {
      return previous;
    }
    if (previous.length > 0 && previous !== picked) {
      PageBackgroundService.removeFile(previous);
    }
    return picked;
  }

  /** Normalizes a picked image and keeps it as the staged one. */
  private static async stageImage(uri: string, context: common.Context): Promise<string> {
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    PageBackgroundService.purgeStaged(directory);
    const destination = `${directory}/pending-${Date.now()}.png`;
    await PageBackgroundService.convertToPng(uri, destination);
    const store = await PageBackgroundStore.open(context);
    await store.setPending(destination);
    return destination;
  }

  /** Drops the staged image once the user leaves the apply page. */
  static async discardPending(context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const staged = await store.getPending();
    if (staged.length > 0) {
      PageBackgroundService.removeFile(staged);
    }
    await store.clearPending();
  }

  /** Stores the image under a content hash so the same picture is kept only once. */
  static async applyToGroup(group: string, sourcePath: string, context: common.Context): Promise<string> {
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    const destination = await PageBackgroundService.hashedPath(directory, sourcePath);
    const store = await PageBackgroundStore.open(context);
    const previous = await store.get(group);
    if (previous.length > 0 && previous !== destination) {
      await PageBackgroundService.dropIfUnused(previous, group, context);
    }
    PageBackgroundService.removeFile(`${directory}/display-${group}.png`);
    await store.set(group, destination);
    notifyPageBackgroundChanged();
    return destination;
  }

  /** Sets the default picture and drops per-group overrides so every page follows it. */
  static async applyToGlobal(sourcePath: string, context: common.Context): Promise<void> {
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    const destination = await PageBackgroundService.hashedPath(directory, sourcePath);
    const store = await PageBackgroundStore.open(context);
    for (const group of PAGE_BACKGROUND_GROUPS) {
      const previous = await store.get(group.key);
      await store.clear(group.key);
      PageBackgroundService.removeFile(`${directory}/display-${group.key}.png`);
      if (previous.length > 0) {
        await PageBackgroundService.dropIfUnused(previous, group.key, context);
      }
    }
    const previousGlobal = await store.get(GLOBAL_BACKGROUND_KEY);
    await store.set(GLOBAL_BACKGROUND_KEY, destination);
    if (previousGlobal.length > 0 && previousGlobal !== destination) {
      await PageBackgroundService.dropIfUnused(previousGlobal, GLOBAL_BACKGROUND_KEY, context);
    }
    notifyPageBackgroundChanged();
  }

  static async clearGlobal(context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const previous = await store.get(GLOBAL_BACKGROUND_KEY);
    await store.clear(GLOBAL_BACKGROUND_KEY);
    if (previous.length > 0) {
      await PageBackgroundService.dropIfUnused(previous, GLOBAL_BACKGROUND_KEY, context);
    }
    notifyPageBackgroundChanged();
  }

  static async getGlobal(context: common.Context): Promise<string> {
    const store = await PageBackgroundStore.open(context);
    return store.get(GLOBAL_BACKGROUND_KEY);
  }

  /** Points every group at one hashed file; the picture itself is copied once. */
  static async applyToAll(sourcePath: string, context: common.Context): Promise<void> {
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    const destination = await PageBackgroundService.hashedPath(directory, sourcePath);
    const store = await PageBackgroundStore.open(context);
    for (const group of PAGE_BACKGROUND_GROUPS) {
      const previous = await store.get(group.key);
      if (previous.length > 0 && previous !== destination) {
        await PageBackgroundService.dropIfUnused(previous, group.key, context);
      }
      PageBackgroundService.removeFile(`${directory}/display-${group.key}.png`);
      await store.set(group.key, destination);
    }
    notifyPageBackgroundChanged();
  }

  static async groupStates(context: common.Context): Promise<BackgroundGroupState[]> {
    const store = await PageBackgroundStore.open(context);
    const globalPath = await store.get(GLOBAL_BACKGROUND_KEY);
    const globalUsable = globalPath.length > 0 && fileIo.accessSync(globalPath);
    const states: BackgroundGroupState[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      const own = await store.get(group.key);
      const ownUsable = own.length > 0 && fileIo.accessSync(own);
      const state: BackgroundGroupState = {
        key: group.key,
        label: group.label,
        applied: ownUsable || globalUsable,
        own: ownUsable,
        following: !ownUsable && globalUsable
      };
      states.push(state);
    }
    return states;
  }

  /** Returns the picture as stored; anything larger than the display limit is shrunk first. */
  static async prepareDisplayImage(sourcePath: string, context: common.Context): Promise<string> {
    if (sourcePath.length === 0 || !fileIo.accessSync(sourcePath)) {
      return '';
    }
    if (await PageBackgroundService.isReadableAtDisplaySize(sourcePath)) {
      return sourcePath;
    }
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    const name = sourcePath.substring(sourcePath.lastIndexOf('/') + 1);
    const displayPath = `${directory}/display-${name}`;
    if (fileIo.accessSync(displayPath)) {
      return displayPath;
    }
    try {
      await PageBackgroundService.convertToPng(sourcePath, displayPath);
      return displayPath;
    } catch (error) {
      return '';
    }
  }

  /** Drops a group's own picture; the group falls back to the global one if it exists. */
  static async clear(group: string, context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const directory = `${context.filesDir}/page-backgrounds`;
    const previous = await store.get(group);
    await store.clear(group);
    PageBackgroundService.removeFile(`${directory}/display-${group}.png`);
    if (previous.length > 0) {
      await PageBackgroundService.dropIfUnused(previous, group, context);
    }
    notifyPageBackgroundChanged();
  }

  static async clearAll(context: common.Context): Promise<void> {
    for (const group of PAGE_BACKGROUND_GROUPS) {
      await PageBackgroundService.clear(group.key, context);
    }
    await PageBackgroundService.clearGlobal(context);
  }

  static async setOpacity(context: common.Context, value: number): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.setOpacity(value);
    notifyPageBackgroundChanged();
  }

  static async setGlobalAlpha(context: common.Context, value: number): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.setGlobalAlpha(value);
    notifyPageBackgroundChanged();
  }

  static async setGroupAlpha(context: common.Context, group: string, value: number): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.setGroupAlpha(group, value);
    notifyPageBackgroundChanged();
  }

  static async clearGroupAlpha(context: common.Context, group: string): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.clearGroupAlpha(group);
    notifyPageBackgroundChanged();
  }

  /** Surface opacity for one group, global value included. */
  static async resolveAlpha(context: common.Context, group: string): Promise<number> {
    const store = await PageBackgroundStore.open(context);
    return store.resolveAlpha(group);
  }

  /** Restores full opacity everywhere, used by "clear everything". */
  static async resetAlpha(context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const groups: string[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      groups.push(group.key);
    }
    await store.clearAllGroupAlpha(groups);
    notifyPageBackgroundChanged();
  }

  /**
   * Checks every stored background on startup: keeps readable PNGs at display size,
   * re-encodes anything else, and drops files that cannot be decoded at all.
   */
  static async recoverLegacyBackgrounds(context: common.Context): Promise<BackgroundRecoveryResult> {
    const store = await PageBackgroundStore.open(context);
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    let converted = 0;
    let cleared = 0;
    let failed = 0;
    const keys: string[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      keys.push(group.key);
    }
    keys.push(GLOBAL_BACKGROUND_KEY);
    for (const key of keys) {
      const path = await store.get(key);
      if (path.length === 0) {
        continue;
      }
      if (!fileIo.accessSync(path)) {
        await store.clear(key);
        cleared += 1;
        continue;
      }
      const readable = await PageBackgroundService.isReadableAtDisplaySize(path);
      if (readable) {
        continue;
      }
      const destination = `${directory}/${key}.png`;
      try {
        await PageBackgroundService.convertToPng(path, destination);
        await store.set(key, destination);
        if (path !== destination) {
          PageBackgroundService.removeFile(path);
        }
        PageBackgroundService.removeFile(`${directory}/display-${key}.png`);
        converted += 1;
      } catch (error) {
        await store.clear(key);
        PageBackgroundService.removeFile(path);
        PageBackgroundService.removeFile(`${directory}/display-${key}.png`);
        failed += 1;
      }
    }
    PageBackgroundService.purgeStaged(directory);
    await PageBackgroundService.collapseDuplicates(context);
    await PageBackgroundService.purgeUnreferenced(directory, context);
    notifyPageBackgroundChanged();
    return { converted: converted, cleared: cleared, failed: failed };
  }

  private static async isReadableAtDisplaySize(path: string): Promise<boolean> {
    if (!path.endsWith('.png')) {
      return false;
    }
    try {
      const sourceFile = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const source = image.createImageSource(sourceFile.fd);
      try {
        const info = await source.getImageInfo();
        return info.size.width > 0 && info.size.height > 0 &&
          info.size.width <= MAX_WIDTH && info.size.height <= MAX_HEIGHT;
      } finally {
        source.release();
        fileIo.closeSync(sourceFile);
      }
    } catch (error) {
      return false;
    }
  }

  /** Removes staged images left behind by an interrupted selection. */
  private static purgeStaged(directory: string): void {
    try {
      for (const name of fileIo.listFileSync(directory)) {
        if (name.startsWith('pending-')) {
          PageBackgroundService.removeFile(`${directory}/${name}`);
        }
      }
    } catch (error) {
    }
  }

  /** Drops files no key points at any more, including display caches of removed images. */
  private static async purgeUnreferenced(directory: string, context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const keep: string[] = [];
    for (const key of PageBackgroundService.allKeys()) {
      const path = await store.get(key);
      if (path.length > 0) {
        keep.push(path.substring(path.lastIndexOf('/') + 1));
      }
    }
    const pending = await store.getPending();
    if (pending.length > 0) {
      keep.push(pending.substring(pending.lastIndexOf('/') + 1));
    }
    try {
      for (const name of fileIo.listFileSync(directory)) {
        if (keep.includes(name)) {
          continue;
        }
        if (name.startsWith('display-') && keep.includes(name.substring('display-'.length))) {
          continue;
        }
        PageBackgroundService.removeFile(`${directory}/${name}`);
      }
    } catch (error) {
    }
  }

  /** Group keys plus the global fallback key. */
  private static allKeys(): string[] {
    const keys: string[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      keys.push(group.key);
    }
    keys.push(GLOBAL_BACKGROUND_KEY);
    return keys;
  }

  /** Points groups that carry the same picture at one file, so old copies stop adding up. */
  private static async collapseDuplicates(context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const canonical: string[] = [];
    const seen: string[] = [];
    for (const key of PageBackgroundService.allKeys()) {
      const path = await store.get(key);
      if (path.length === 0) {
        continue;
      }
      const digest = await PageBackgroundService.digestOf(path);
      if (digest.length === 0) {
        continue;
      }
      const index = seen.indexOf(digest);
      if (index < 0) {
        seen.push(digest);
        canonical.push(path);
        continue;
      }
      const keep = canonical[index];
      if (path !== keep) {
        await store.set(key, keep);
        await PageBackgroundService.dropIfUnused(path, key, context);
      }
    }
  }

  private static async digestOf(path: string): Promise<string> {
    try {
      return await hash.hash(path, 'sha256');
    } catch (error) {
      return '';
    }
  }

  /** Copies the picture under its content hash, or reuses the copy that already exists. */
  private static async hashedPath(directory: string, sourcePath: string): Promise<string> {
    let digest = await PageBackgroundService.digestOf(sourcePath);
    if (digest.length === 0) {
      digest = `t${Date.now()}`;
    }
    const destination = `${directory}/bg-${digest.substring(0, 16)}.png`;
    if (!fileIo.accessSync(destination)) {
      const source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, destination);
      } finally {
        fileIo.closeSync(source);
      }
    }
    return destination;
  }

  /** Deletes a picture only when no other key still points at it. */
  private static async dropIfUnused(path: string, skipKey: string, context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    for (const key of PageBackgroundService.allKeys()) {
      if (key === skipKey) {
        continue;
      }
      if (await store.get(key) === path) {
        return;
      }
    }
    PageBackgroundService.removeFile(path);
  }

  private static ensureDirectory(directory: string): void {
    try {
      fileIo.mkdirSync(directory);
    } catch (error) {
    }
  }

  private static removeFile(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (error) {
    }
  }

  private static async convertToPng(sourceUri: string, destination: string): Promise<void> {
    const sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
    const source = image.createImageSource(sourceFile.fd);
    const packer = image.createImagePacker();
    try {
      const info = await source.getImageInfo();
      const sourceWidth = info.size.width;
      const sourceHeight = info.size.height;
      const scale = Math.min(1, Math.min(MAX_WIDTH / sourceWidth, MAX_HEIGHT / sourceHeight));
      const width = Math.max(1, Math.round(sourceWidth * scale));
      const height = Math.max(1, Math.round(sourceHeight * scale));
      const pixelMap = await source.createPixelMap({ desiredSize: { width: width, height: height } });
      try {
        const file = fileIo.openSync(destination,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        try {
          await packer.packToFile(pixelMap, file.fd, { format: 'image/png', quality: 100 });
        } finally {
          fileIo.closeSync(file);
        }
      } finally {
        pixelMap.release();
      }
    } finally {
      packer.release();
      source.release();
      fileIo.closeSync(sourceFile);
    }
  }
}
