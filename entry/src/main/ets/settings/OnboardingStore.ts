import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'cogit_onboarding';
const SEEN_KEY = 'guide_seen';

/** Persists whether the first-run guide has been dismissed. */
export class OnboardingStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<OnboardingStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new OnboardingStore(prefs);
  }

  async isSeen(): Promise<boolean> {
    const value = await this.prefs.get(SEEN_KEY, false);
    return value === true;
  }

  async markSeen(): Promise<void> {
    await this.prefs.put(SEEN_KEY, true);
    await this.prefs.flush();
  }
}
