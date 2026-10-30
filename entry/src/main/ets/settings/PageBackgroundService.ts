import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { PageBackgroundStore } from './PageBackgroundStore';
import { notifyPageBackgroundChanged } from './PageBackgroundBus';

export interface PageBackgroundGroup {
  key: string;
  label: string;
}

export interface BackgroundRecoveryResult {
  converted: number;
  cleared: number;
  failed: number;
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
  if (route === 'settings') {
    return 'settings';
  }
  return 'home';
}

/** Picks an image, normalizes it to PNG, then applies it to one group or all groups. */
export class PageBackgroundService {
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
    const destination = `${directory}/pending-${Date.now()}.png`;
    await PageBackgroundService.convertToPng(result.photoUris[0], destination);
    return destination;
  }

  static async applyToGroup(group: string, sourcePath: string, context: common.Context): Promise<string> {
    const directory = `${context.filesDir}/page-backgrounds`;
    PageBackgroundService.ensureDirectory(directory);
    const destination = `${directory}/${group}.png`;
    const source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.copyFileSync(source.fd, destination);
    } finally {
      fileIo.closeSync(source);
    }
    const store = await PageBackgroundStore.open(context);
    await store.set(group, destination);
    notifyPageBackgroundChanged();
    return destination;
  }

  static async applyToAll(sourcePath: string, context: common.Context): Promise<void> {
    for (const group of PAGE_BACKGROUND_GROUPS) {
      await PageBackgroundService.applyToGroup(group.key, sourcePath, context);
    }
  }

  static async discardPrepared(path: string): Promise<void> {
    try {
      fileIo.unlinkSync(path);
    } catch (error) {
    }
  }

  static async clear(group: string, context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.clear(group);
    PageBackgroundService.removeFile(`${context.filesDir}/page-backgrounds/${group}.png`);
    PageBackgroundService.removeFile(`${context.filesDir}/page-backgrounds/${group}.jpg`);
    PageBackgroundService.removeFile(`${context.filesDir}/page-backgrounds/${group}-repair.png`);
    notifyPageBackgroundChanged();
  }

  static async setOpacity(context: common.Context, value: number): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.setOpacity(value);
    notifyPageBackgroundChanged();
  }

  /** Repairs backgrounds saved before PNG normalization; clears files that cannot be decoded. */
  static async recoverLegacyBackgrounds(context: common.Context, forceAll: boolean = false): Promise<BackgroundRecoveryResult> {
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
      if (path.endsWith('.png') && !forceAll) {
        continue;
      }
      const destination = `${directory}/${group.key}-repair.png`;
      try {
        await PageBackgroundService.convertToPng(path, destination);
        await store.set(group.key, destination);
        PageBackgroundService.removeFile(path);
        converted += 1;
      } catch (error) {
        await store.clear(group.key);
        PageBackgroundService.removeFile(path);
        failed += 1;
      }
    }
    if (converted > 0 || cleared > 0 || failed > 0) {
      notifyPageBackgroundChanged();
    }
    return { converted: converted, cleared: cleared, failed: failed };
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
      const maxWidth = 1080;
      const maxHeight = 1920;
      const scale = Math.min(1, Math.min(maxWidth / sourceWidth, maxHeight / sourceHeight));
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
