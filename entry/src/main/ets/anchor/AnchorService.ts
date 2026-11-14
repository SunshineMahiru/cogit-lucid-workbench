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

  /** Returns the anchors still offered to new reviews, ordered by display order. */
  async list(): Promise<Anchor[]> {
    return this.anchorDao.queryActive();
  }

  /** Returns every version of one anchor, oldest first. */
  async versions(id: string): Promise<Anchor[]> {
    const all = await this.anchorDao.queryAll();
    const current = all.find((anchor: Anchor) => anchor.id === id);
    if (current === undefined) {
      return [];
    }
    const rootId = (current.rootId ?? '').length > 0 ? current.rootId as string : current.id;
    return this.anchorDao.queryVersions(rootId);
  }

  /**
   * Writes a new version and retires the old one. The old row stays so reviews that quoted it
   * keep pointing at the wording they actually used.
   */
  async revise(id: string, text: string, context: string, reason: string): Promise<Anchor> {
    const value = text.trim();
    if (value.length === 0) {
      throw new Error('empty anchor');
    }
    if (reason.trim().length === 0) {
      throw new Error('revision reason required');
    }
    const all = await this.anchorDao.queryAll();
    const current = all.find((anchor: Anchor) => anchor.id === id);
    if (current === undefined) {
      throw new Error('anchor not found');
    }
    const rootId = (current.rootId ?? '').length > 0 ? current.rootId as string : current.id;
    const versions = await this.anchorDao.queryVersions(rootId);
    const next = createAnchor();
    next.text = value;
    next.source = current.source;
    next.order = current.order;
    next.level = current.level;
    next.rootId = rootId;
    next.version = versions.length + 1;
    next.status = 'active';
    next.context = context.trim();
    next.revisionReason = reason.trim();
    next.synthetic = current.synthetic === true;
    await this.anchorDao.insert(next);
    await this.anchorDao.retire(current.id);
    return next;
  }

  /** Stops offering one anchor to new reviews; history keeps it. */
  async retire(id: string): Promise<void> {
    await this.anchorDao.retire(id);
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
      anchor.synthetic = true;
      await this.anchorDao.insert(anchor);
    }
    return MOCK_ANCHORS.length;
  }
}
