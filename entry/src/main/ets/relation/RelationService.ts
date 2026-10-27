import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { MOCK_RELATIONS } from '../model/mockData';
import { TrustLevel } from '../model/TrustLevel';
import { DbHelper } from '../db/DbHelper';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { RelationDao } from '../db/dao/RelationDao';
import { RelationDetail, RelationListItem } from './RelationListItem';
import { filterRelationItems, toRelationDetail, toRelationListItems } from './RelationListMapper';

/** Read access to relations plus an explicit demo seed; editing lands in 6.4. */
export class RelationService {
  private relationDao: RelationDao;
  private eventDao: EventDao;
  private decisionDao: DecisionDao;

  private constructor(store: relationalStore.RdbStore) {
    this.relationDao = new RelationDao(store);
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<RelationService> {
    const store = await DbHelper.init(context);
    return new RelationService(store);
  }

  /** Returns rows ordered by trust tier then latest interaction, optionally filtered. */
  async list(level: TrustLevel | null): Promise<RelationListItem[]> {
    const relations = await this.relationDao.queryAll();
    return filterRelationItems(toRelationListItems(relations), level);
  }

  /** Returns one relation with its full log, or null when it is gone. */
  async find(id: string): Promise<RelationDetail | null> {
    const relation = await this.relationDao.queryById(id);
    if (relation === null) {
      return null;
    }
    const detail = toRelationDetail(relation);
    const events = await this.eventDao.queryAll();
    const decisions = await this.decisionDao.queryAll();
    detail.linkedEvents = events
      .filter((event) => event.relatedRelationIds.includes(id))
      .map((event) => event.title);
    detail.linkedDecisions = decisions
      .filter((decision) => decision.relatedRelationIds.includes(id))
      .map((decision) => decision.title);
    return detail;
  }

  /**
   * Inserts the synthetic demo relations when the table is empty.
   * Returns how many rows were added; existing data is never touched.
   */
  async seedDemoRelations(): Promise<number> {
    const existing = await this.relationDao.queryAll();
    if (existing.length > 0) {
      return 0;
    }
    for (const relation of MOCK_RELATIONS) {
      await this.relationDao.insert(relation);
    }
    return MOCK_RELATIONS.length;
  }
}
