import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HomeBlockKind, normalizeBlockOrder } from '../model/HomeBlock';

const STORE_NAME = 'cogit_home_layout';
const ORDER_KEY = 'block_order_v1';

/** Default order as a fresh array; never hand out the shared constant itself. */
function defaultOrder(): HomeBlockKind[] {
  return normalizeBlockOrder([]);
}

/**
 * Stores the workbench block order as one comma-separated string in Preferences. The order is a
 * local preference, not a business fact, so a broken or missing value always falls back to the
 * default order and never surfaces an error to the view.
 */
export class HomeLayoutStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<HomeLayoutStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new HomeLayoutStore(prefs);
  }

  /** Reads the stored order; unknown ids are dropped and missing ids are appended. */
  async load(): Promise<HomeBlockKind[]> {
    try {
      const stored = await this.prefs.get(ORDER_KEY, '');
      if (typeof stored !== 'string' || stored.length === 0) {
        return defaultOrder();
      }
      return normalizeBlockOrder(stored.split(','));
    } catch (error) {
      return defaultOrder();
    }
  }

  /** Writes a normalized order; a storage failure leaves the previous value untouched. */
  async save(order: HomeBlockKind[]): Promise<void> {
    try {
      const normalized = normalizeBlockOrder(order);
      await this.prefs.put(ORDER_KEY, normalized.join(','));
      await this.prefs.flush();
    } catch (error) {
    }
  }

  /** Writes and returns the default order. */
  async reset(): Promise<HomeBlockKind[]> {
    const order = defaultOrder();
    await this.save(order);
    return order;
  }
}