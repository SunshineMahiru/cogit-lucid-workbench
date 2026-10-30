import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
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

/** Opens the system photo picker, copies the chosen image into the sandbox, and saves its group. */
export class PageBackgroundService {
  static async pickAndSave(group: string, context: common.Context): Promise<string> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result = await new photoAccessHelper.PhotoViewPicker().select(options);
    if (result.photoUris.length === 0) {
      return '';
    }
    const directory = `${context.filesDir}/page-backgrounds`;
    try {
      fileIo.mkdirSync(directory);
    } catch (error) {
    }
    const destination = `${directory}/${group}.jpg`;
    const source = fileIo.openSync(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
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

  static async clear(group: string, context: common.Context): Promise<void> {
    const store = await PageBackgroundStore.open(context);
    await store.clear(group);
    try {
      fileIo.unlinkSync(`${context.filesDir}/page-backgrounds/${group}.jpg`);
    } catch (error) {
    }
    notifyPageBackgroundChanged();
  }
}
