import { common } from '@kit.AbilityKit';
import { DEFAULT_PROFILE, Profile, ProfileStore } from '../profile/ProfileStore';

/** Plain cache shared by the band, the editor and the backup service. */
class ProfileCache {
  profile: Profile = DEFAULT_PROFILE;
  loaded: boolean = false;
  private loading: Promise<void> | null = null;

  async ensure(context: common.Context): Promise<void> {
    if (this.loaded) {
      return;
    }
    if (this.loading === null) {
      this.loading = this.reload(context);
    }
    await this.loading;
  }

  async reload(context: common.Context): Promise<void> {
    try {
      this.profile = await (await ProfileStore.open(context)).load();
      this.loaded = true;
    } catch (error) {
    } finally {
      this.loading = null;
    }
  }

  set(profile: Profile): void {
    this.profile = profile;
    this.loaded = true;
  }

  reset(): void {
    this.profile = DEFAULT_PROFILE;
    this.loaded = true;
  }
}

export const profileCache = new ProfileCache();
