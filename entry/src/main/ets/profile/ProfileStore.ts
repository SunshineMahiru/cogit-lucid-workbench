import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'cogit_profile';
const KEY_NICKNAME = 'nickname';
const KEY_SIGNATURE = 'signature';
const KEY_TITLE = 'title';
const KEY_AVATAR = 'avatar_path';

/** Text the home header shows before the user edits anything. */
export const DEFAULT_PROFILE: Profile = {
  nickname: '记录者',
  signature: '把判断留下来，过一段时间再看',
  title: '未命名',
  avatarPath: ''
};

/** Optional identity shown at the top of the home page. */
export interface Profile {
  nickname: string;
  signature: string;
  title: string;
  avatarPath: string;
}

/** Trims each field and keeps the header from overflowing. */
export function sanitizeProfile(input: Profile): Profile {
  const nickname = input.nickname.trim().slice(0, 12);
  const signature = input.signature.trim().slice(0, 24);
  const title = input.title.trim().slice(0, 8);
  return {
    nickname: nickname.length > 0 ? nickname : DEFAULT_PROFILE.nickname,
    signature: signature,
    title: title.length > 0 ? title : DEFAULT_PROFILE.title,
    avatarPath: input.avatarPath
  };
}

/** Stores the home page identity in Preferences; no field here is secret. */
export class ProfileStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<ProfileStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new ProfileStore(prefs);
  }

  async load(): Promise<Profile> {
    const nickname = await this.prefs.get(KEY_NICKNAME, DEFAULT_PROFILE.nickname);
    const signature = await this.prefs.get(KEY_SIGNATURE, DEFAULT_PROFILE.signature);
    const title = await this.prefs.get(KEY_TITLE, DEFAULT_PROFILE.title);
    const avatarPath = await this.prefs.get(KEY_AVATAR, '');
    const profile: Profile = {
      nickname: typeof nickname === 'string' ? nickname : DEFAULT_PROFILE.nickname,
      signature: typeof signature === 'string' ? signature : DEFAULT_PROFILE.signature,
      title: typeof title === 'string' ? title : DEFAULT_PROFILE.title,
      avatarPath: typeof avatarPath === 'string' ? avatarPath : ''
    };
    return profile;
  }

  async save(profile: Profile): Promise<void> {
    const next = sanitizeProfile(profile);
    await this.prefs.put(KEY_NICKNAME, next.nickname);
    await this.prefs.put(KEY_SIGNATURE, next.signature);
    await this.prefs.put(KEY_TITLE, next.title);
    await this.prefs.put(KEY_AVATAR, next.avatarPath);
    await this.prefs.flush();
  }
}
