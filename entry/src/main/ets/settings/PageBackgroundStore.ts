import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'cogit_page_backgrounds';
const OPACITY_KEY = '__opacity';
const PENDING_KEY = '__pending';
const DEFAULT_OPACITY = 0.1;
const MIN_OPACITY = 0.04;
const MAX_OPACITY = 0.3;

/** Stores one local image path per page group and the shared overlay opacity. */
export class PageBackgroundStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<PageBackgroundStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new PageBackgroundStore(prefs);
  }

  async get(route: string): Promise<string> {
    const value = await this.prefs.get(route, '');
    return typeof value === 'string' ? value : '';
  }

  async set(route: string, path: string): Promise<void> {
    await this.prefs.put(route, path);
    await this.prefs.flush();
  }

  async clear(route: string): Promise<void> {
    await this.prefs.put(route, '');
    await this.prefs.flush();
  }

  async getPending(): Promise<string> {
    const value = await this.prefs.get(PENDING_KEY, '');
    return typeof value === 'string' ? value : '';
  }

  async setPending(path: string): Promise<void> {
    await this.prefs.put(PENDING_KEY, path);
    await this.prefs.flush();
  }

  async clearPending(): Promise<void> {
    await this.prefs.put(PENDING_KEY, '');
    await this.prefs.flush();
  }

  async getOpacity(): Promise<number> {
    const value = await this.prefs.get(OPACITY_KEY, DEFAULT_OPACITY);
    if (typeof value !== 'number' || Number.isNaN(value)) {
      return DEFAULT_OPACITY;
    }
    return Math.min(MAX_OPACITY, Math.max(MIN_OPACITY, value));
  }

  async setOpacity(value: number): Promise<void> {
    await this.prefs.put(OPACITY_KEY, Math.min(MAX_OPACITY, Math.max(MIN_OPACITY, value)));
    await this.prefs.flush();
  }
}
