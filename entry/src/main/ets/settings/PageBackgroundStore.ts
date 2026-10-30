import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'cogit_page_backgrounds';
const OPACITY_KEY = '__opacity';
const PENDING_KEY = '__pending';
const GLOBAL_KEY = '__global';
const GLOBAL_ALPHA_KEY = '__alpha';
const GROUP_ALPHA_PREFIX = '__alpha_';
const DEFAULT_OPACITY = 0.1;
const MIN_OPACITY = 0.04;
const MAX_OPACITY = 0.3;
const MIN_ALPHA = 0.4;
const MAX_ALPHA = 1;
const FOLLOW_GLOBAL_ALPHA = -1;

/** Preferences key of the picture every page falls back to. */
export const GLOBAL_BACKGROUND_KEY = GLOBAL_KEY;

/** Stores one local image path per page group, the global default, and the shared opacity. */
export class PageBackgroundStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<PageBackgroundStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new PageBackgroundStore(prefs);
  }

  async get(key: string): Promise<string> {
    const value = await this.prefs.get(key, '');
    return typeof value === 'string' ? value : '';
  }

  async set(key: string, path: string): Promise<void> {
    await this.prefs.put(key, path);
    await this.prefs.flush();
  }

  async clear(key: string): Promise<void> {
    await this.prefs.put(key, '');
    await this.prefs.flush();
  }

  /** Resolves the picture that actually applies to a group: its own, otherwise the global one. */
  async resolve(group: string): Promise<string> {
    const own = await this.get(group);
    if (own.length > 0) {
      return own;
    }
    return this.get(GLOBAL_KEY);
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

  /** Surface opacity of every page that has no override; 1 keeps the page fully solid. */
  async getGlobalAlpha(): Promise<number> {
    const value = await this.prefs.get(GLOBAL_ALPHA_KEY, MAX_ALPHA);
    if (typeof value !== 'number' || Number.isNaN(value)) {
      return MAX_ALPHA;
    }
    return Math.min(MAX_ALPHA, Math.max(MIN_ALPHA, value));
  }

  async setGlobalAlpha(value: number): Promise<void> {
    await this.prefs.put(GLOBAL_ALPHA_KEY, Math.min(MAX_ALPHA, Math.max(MIN_ALPHA, value)));
    await this.prefs.flush();
  }

  /** Returns FOLLOW_GLOBAL_ALPHA when the group inherits the global value. */
  async getGroupAlpha(group: string): Promise<number> {
    const value = await this.prefs.get(`${GROUP_ALPHA_PREFIX}${group}`, FOLLOW_GLOBAL_ALPHA);
    if (typeof value !== 'number' || Number.isNaN(value) || value < 0) {
      return FOLLOW_GLOBAL_ALPHA;
    }
    return Math.min(MAX_ALPHA, Math.max(MIN_ALPHA, value));
  }

  async setGroupAlpha(group: string, value: number): Promise<void> {
    await this.prefs.put(`${GROUP_ALPHA_PREFIX}${group}`, Math.min(MAX_ALPHA, Math.max(MIN_ALPHA, value)));
    await this.prefs.flush();
  }

  async clearGroupAlpha(group: string): Promise<void> {
    await this.prefs.put(`${GROUP_ALPHA_PREFIX}${group}`, FOLLOW_GLOBAL_ALPHA);
    await this.prefs.flush();
  }

  /** Surface opacity that actually applies to a group. */
  async resolveAlpha(group: string): Promise<number> {
    const own = await this.getGroupAlpha(group);
    if (own >= 0) {
      return own;
    }
    return this.getGlobalAlpha();
  }

  /** Every group that carries its own surface opacity, used when clearing everything. */
  async clearAllGroupAlpha(groups: string[]): Promise<void> {
    for (const group of groups) {
      await this.prefs.put(`${GROUP_ALPHA_PREFIX}${group}`, FOLLOW_GLOBAL_ALPHA);
    }
    await this.prefs.put(GLOBAL_ALPHA_KEY, MAX_ALPHA);
    await this.prefs.flush();
  }
}
