import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'cogit_page_backgrounds';
const OPACITY_KEY = '__opacity';
const DEFAULT_OPACITY = 0.14;

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

  async getOpacity(): Promise<number> {
    const value = await this.prefs.get(OPACITY_KEY, DEFAULT_OPACITY);
    if (typeof value !== 'number' || Number.isNaN(value)) {
      return DEFAULT_OPACITY;
    }
    return Math.min(0.4, Math.max(0.05, value));
  }

  async setOpacity(value: number): Promise<void> {
    await this.prefs.put(OPACITY_KEY, Math.min(0.4, Math.max(0.05, value)));
    await this.prefs.flush();
  }
}
