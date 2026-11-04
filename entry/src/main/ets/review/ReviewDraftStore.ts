import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewDraft } from './ReviewDraft';

const STORE_NAME = 'review_draft_store';
const KEY_PREFIX = 'draft_';

/** Persists one unfinished review draft per period. */
export class ReviewDraftStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<ReviewDraftStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new ReviewDraftStore(prefs);
  }

  async load(period: ReviewPeriod): Promise<ReviewDraft | null> {
    const raw = await this.prefs.get(KEY_PREFIX + period, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const facts = parsed['facts'];
      const interpretation = parsed['interpretation'];
      const contradiction = parsed['contradiction'];
      const action = parsed['action'];
      const anchorIds = parsed['anchorIds'];
      return {
        facts: typeof facts === 'string' ? facts : '',
        interpretation: typeof interpretation === 'string' ? interpretation : '',
        contradiction: typeof contradiction === 'string' ? contradiction : '',
        action: typeof action === 'string' ? action : '',
        anchorIds: Array.isArray(anchorIds) ? anchorIds as string[] : []
      };
    } catch (error) {
      return null;
    }
  }

  async save(period: ReviewPeriod, draft: ReviewDraft): Promise<void> {
    await this.prefs.put(KEY_PREFIX + period, JSON.stringify(draft));
    await this.prefs.flush();
  }

  async clear(period: ReviewPeriod): Promise<void> {
    await this.prefs.put(KEY_PREFIX + period, '');
    await this.prefs.flush();
  }

  /**
   * Appends a plan-node summary to the weekly draft.
   * Existing text is preserved; an empty draft is filled in place.
   */
  async prefillWeekly(facts: string): Promise<void> {
    const existing = await this.load(ReviewPeriod.WEEK);
    if (existing === null) {
      const draft: ReviewDraft = {
        facts: facts,
        interpretation: '',
        contradiction: '',
        action: '',
        anchorIds: []
      };
      await this.save(ReviewPeriod.WEEK, draft);
      return;
    }
    if (existing.facts.trim().length === 0) {
      existing.facts = facts;
    } else if (!existing.facts.includes(facts)) {
      existing.facts = `${existing.facts.trimEnd()}\n\n${facts}`;
    }
    await this.save(ReviewPeriod.WEEK, existing);
  }
}
