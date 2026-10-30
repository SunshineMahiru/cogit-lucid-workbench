import { fileIo, hash } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { PageBackgroundStore } from './PageBackgroundStore';
import { notifyPageBackgroundChanged } from './PageBackgroundBus';

export interface PageBackgroundGroup {
  key: string;
  label: string;
}

export interface BackgroundGroupState {
  key: string;
  label: string;
  applied: boolean;
}

export interface BackgroundRecoveryResult {
  converted: number;
  cleared: number;
  failed: number;
}

const MAX_WIDTH = 1080;
const MAX_HEIGHT = 1920;

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
  /** Opens the picker and keeps the normalized image as the staged ("pending") one. */
  static async pickImage(context: common.Context): Promise<string> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result = await new photoAccessHelper.PhotoViewPicker().select(options);
    if (result.photoUris.length === 0) {
      return '';
    }
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    PageBackgroundService.purgeStaged(directory);
    const destination = `${directory}/pending-${Date.now()}.png`;
    await PageBackgroundService.convertToPng(result.photoUris[0], destination);
    const store = await PageBackgroundStore.open(context);
    await store.setPending(destination);
    return destination;
  }

  static async getPending(context: common.Context): Promise<string> {
    const store = await PageBackgroundStore.open(context);
    return store.getPending();
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

  /** Picks a replacement for the staged image and keeps the previous selection intact on cancel. */
  static async replacePending(context: common.Context): Promise<string> {
    const store = await PageBackgroundStore.open(context);
    const previous = await store.getPending();
    const picked = await PageBackgroundService.pickImage(context);
    if (picked.length === 0) {
      return previous;
    }
    if (previous.length > 0 && previous !== picked) {
      PageBackgroundService.removeFile(previous);
    }
    return picked;
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
    const states: BackgroundGroupState[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      const path = await store.get(group.key);
      const state: BackgroundGroupState = {
        key: group.key,
        label: group.label,
        applied: path.length > 0 && fileIo.accessSync(path)
      };
      states.push(state);
    }
    return states;
  }

  /** Returns a display-sized cache, converting large legacy images before Image decodes them. */
  static async prepareDisplayImage(sourcePath: string, group: string, context: common.Context): Promise<string> {
    if (sourcePath.length === 0 || !fileIo.accessSync(sourcePath)) {
      return '';
    }
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    const displayPath = `${directory}/display-${group}.png`;
    if (fileIo.accessSync(displayPath)) {
      return displayPath;
    }
    if (sourcePath.endsWith('.png')) {
      try {
        const sourceFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
        const source = image.createImageSource(sourceFile.fd);
        try {
          const info = await source.getImageInfo();
          if (info.size.width <= MAX_WIDTH && info.size.height <= MAX_HEIGHT) {
            return sourcePath;
          }
        } finally {
          source.release();
          fileIo.closeSync(sourceFile);
        }
      } catch (error) {
        return '';
      }
    }
    try {
      await PageBackgroundService.convertToPng(sourcePath, displayPath);
      return displayPath;
    } catch (error) {
      return '';
    }
  }

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
  }

  static async setOpacity(context: common.Context, value: number): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.setOpacity(value);
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
    for (const group of PAGE_BACKGROUND_GROUPS) {
      const path = await store.get(group.key);
      if (path.length === 0) {
        continue;
      }
      if (!fileIo.accessSync(path)) {
        await store.clear(group.key);
        cleared += 1;
        continue;
      }
      const readable = await PageBackgroundService.isReadableAtDisplaySize(path);
      if (readable) {
        continue;
      }
      const destination = `${directory}/${group.key}.png`;
      try {
        await PageBackgroundService.convertToPng(path, destination);
        await store.set(group.key, destination);
        if (path !== destination) {
          PageBackgroundService.removeFile(path);
        }
        PageBackgroundService.removeFile(`${directory}/display-${group.key}.png`);
        converted += 1;
      } catch (error) {
        await store.clear(group.key);
        PageBackgroundService.removeFile(path);
        PageBackgroundService.removeFile(`${directory}/display-${group.key}.png`);
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

  /** Drops files no group points at any more, including display caches of removed images. */
  private static async purgeUnreferenced(directory: string, context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const keep: string[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      const path = await store.get(group.key);
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
        if (!keep.includes(name)) {
          PageBackgroundService.removeFile(`${directory}/${name}`);
        }
      }
    } catch (error) {
    }
  }

  /** Points groups that carry the same picture at one file, so old copies stop adding up. */
  private static async collapseDuplicates(context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    const canonical: string[] = [];
    const seen: string[] = [];
    for (const group of PAGE_BACKGROUND_GROUPS) {
      const path = await store.get(group.key);
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
        await store.set(group.key, keep);
        await PageBackgroundService.dropIfUnused(path, group.key, context);
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

  /** Deletes a picture only when no other group still points at it. */
  private static async dropIfUnused(path: string, skipGroup: string, context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    for (const group of PAGE_BACKGROUND_GROUPS) {
      if (group.key === skipGroup) {
        continue;
      }
      if (await store.get(group.key) === path) {
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
