import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewDraft } from './ReviewDraft';
import { mergeWeeklyDraft } from './ReviewDraftMerge';

const STORE_NAME = 'review_draft_store';
const KEY_PREFIX = 'draft_';
const NODE_PREFIX = 'node_';

/** Persists one unfinished review draft per period, or one per plan node. */
export class ReviewDraftStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<ReviewDraftStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new ReviewDraftStore(prefs);
  }

  private keyFor(period: ReviewPeriod, planNodeId: string): string {
    return planNodeId.length > 0 ? `${NODE_PREFIX}${planNodeId}` : `${KEY_PREFIX}${period}`;
  }

  async load(period: ReviewPeriod): Promise<ReviewDraft | null> {
    return this.loadFor(period, '');
  }

  async loadFor(period: ReviewPeriod, planNodeId: string): Promise<ReviewDraft | null> {
    const raw = await this.prefs.get(this.keyFor(period, planNodeId), '');
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
      const planId = parsed['planId'];
      const nodeId = parsed['planNodeId'];
      const draft: ReviewDraft = {
        facts: typeof facts === 'string' ? facts : '',
        interpretation: typeof interpretation === 'string' ? interpretation : '',
        contradiction: typeof contradiction === 'string' ? contradiction : '',
        action: typeof action === 'string' ? action : '',
        anchorIds: Array.isArray(anchorIds) ? anchorIds as string[] : []
      };
      if (typeof planId === 'string' && planId.length > 0) {
        draft.planId = planId;
      }
      if (typeof nodeId === 'string' && nodeId.length > 0) {
        draft.planNodeId = nodeId;
      }
      return draft;
    } catch (error) {
      return null;
    }
  }

  async save(period: ReviewPeriod, draft: ReviewDraft): Promise<void> {
    await this.saveFor(period, '', draft);
  }

  async saveFor(period: ReviewPeriod, planNodeId: string, draft: ReviewDraft): Promise<void> {
    await this.prefs.put(this.keyFor(period, planNodeId), JSON.stringify(draft));
    await this.prefs.flush();
  }

  async clear(period: ReviewPeriod): Promise<void> {
    await this.clearFor(period, '');
  }

  async clearFor(period: ReviewPeriod, planNodeId: string): Promise<void> {
    await this.prefs.put(this.keyFor(period, planNodeId), '');
    await this.prefs.flush();
  }

  /**
   * Creates or appends the weekly draft for one plan node.
   * A node with no draft gets a new one; an existing node draft keeps its text.
   */
  async prefillWeekly(facts: string, planId: string = '', planNodeId: string = ''): Promise<void> {
    const existing = await this.loadFor(ReviewPeriod.WEEK, planNodeId);
    await this.saveFor(ReviewPeriod.WEEK, planNodeId, mergeWeeklyDraft(existing, facts, planId, planNodeId));
  }
}
