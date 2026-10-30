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
    notifyPageBackgroundChanged();
  }

  static async setOpacity(context: common.Context, value: number): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.setOpacity(value);
    notifyPageBackgroundChanged();
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
    const source = image.createImageSource(sourceUri);
    const packer = image.createImagePacker();
    try {
      const file = fileIo.openSync(destination,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        await packer.packToFile(source, file.fd, { format: 'image/png', quality: 100 });
      } finally {
        fileIo.closeSync(file);
      }
    } finally {
      packer.release();
      source.release();
    }
  }
}
