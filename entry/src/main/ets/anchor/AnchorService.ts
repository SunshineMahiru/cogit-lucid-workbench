import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Anchor } from '../model/Anchor';
import { MOCK_ANCHORS } from '../model/mockData';
import { createAnchor } from '../model/factories';
import { DbHelper } from '../db/DbHelper';
import { AnchorDao } from '../db/dao/AnchorDao';

/** Read-only access to the value anchors, plus an explicit demo seed. */
export class AnchorService {
  private anchorDao: AnchorDao;

  private constructor(store: relationalStore.RdbStore) {
    this.anchorDao = new AnchorDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<AnchorService> {
    const store = await DbHelper.init(context);
    return new AnchorService(store);
  }

  /** Returns anchors ordered by their display order. */
  async list(): Promise<Anchor[]> {
    return this.anchorDao.queryAll();
  }

  /** Adds one user-written anchor; saved anchors stay read-only. */
  async create(text: string): Promise<Anchor> {
    const value = text.trim();
    if (value.length === 0) {
      throw new Error('empty anchor');
    }
    const existing = await this.anchorDao.queryAll();
    const anchor = createAnchor();
    anchor.text = value;
    anchor.source = '自写';
    anchor.order = existing.length;
    await this.anchorDao.insert(anchor);
    return anchor;
  }

  /**
   * Inserts the synthetic demo anchors when the library is empty.
   * Returns how many rows were added; existing data is never touched.
   */
  async seedDemoAnchors(): Promise<number> {
    const existing = await this.anchorDao.queryAll();
    if (existing.length > 0) {
      return 0;
    }
    for (const anchor of MOCK_ANCHORS) {
      await this.anchorDao.insert(anchor);
    }
    return MOCK_ANCHORS.length;
  }
}
