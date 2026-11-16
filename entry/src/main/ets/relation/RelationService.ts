import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { MOCK_RELATIONS } from '../model/mockData';
import { InteractionLog, CitationScope, InteractionSource, Relation } from '../model/Relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';
import { createRelation } from '../model/factories';
import { DbHelper } from '../db/DbHelper';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { RelationDao } from '../db/dao/RelationDao';
import { ReviewMaterialDao } from '../db/dao/ReviewMaterialDao';
import { RelationDetail, RelationListItem } from './RelationListItem';
import { filterRelationItems, toRelationDetail, toRelationListItems } from './RelationListMapper';

/** Read access to relations plus an explicit demo seed; editing lands in 6.4. */export class RelationService {
  private relationDao: RelationDao;
  private eventDao: EventDao;
  private decisionDao: DecisionDao;
  private reviewMaterialDao: ReviewMaterialDao;

  private constructor(store: relationalStore.RdbStore) {
    this.relationDao = new RelationDao(store);
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.reviewMaterialDao = new ReviewMaterialDao(store);
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

  /** Creates or updates one relation profile and returns its detail. */
  async save(id: string | null, name: string, trustLevel: TrustLevel, rawMaterialTest: boolean,
    forbidAnalysis: boolean, level: SecurityLevel, notes: string, correction: string = ''): Promise<RelationDetail> {
    const relation: Relation = id === null ? createRelation() : await this.requireRelation(id);
    const previousLevel: SecurityLevel = relation.level;
    relation.name = name.trim();
    relation.trustLevel = trustLevel;
    relation.rawMaterialTest = rawMaterialTest;
    relation.forbidAnalysis = forbidAnalysis;
    relation.level = level;
    relation.notes = notes.trim();
    const correctionText = correction.trim();
    if (correctionText !== (relation.correction ?? '')) {
      relation.correction = correctionText;
      relation.correctionAt = correctionText.length === 0 ? 0 : Date.now();
    }
    if (id === null) {
      await this.relationDao.insert(relation);
    } else {
      await this.relationDao.updateProfile(relation.id, relation.name, relation.trustLevel,
        relation.rawMaterialTest, relation.forbidAnalysis, relation.level, relation.notes,
        relation.correction ?? '', relation.correctionAt ?? 0);
      if (levelRank(relation.level) > levelRank(previousLevel)) {
        await this.reviewMaterialDao.clampLevels([`relation:${relation.id}`], relation.level);
      }
    }
    return toRelationDetail(relation);
  }

  /** Soft-deletes a relation while keeping its history available for undo. */
  async softDelete(id: string): Promise<void> {
    await this.relationDao.softDelete(id);
  }

  /** Restores a relation removed by mistake. */
  async restore(id: string): Promise<void> {
    await this.relationDao.restore(id);
  }

  /** Appends one interaction to the relation log and returns the refreshed detail. */
  async addInteraction(id: string, content: string, source: InteractionSource = 'observation',
    citation: CitationScope = 'hidden', allowContext: boolean = false): Promise<RelationDetail> {
    const relation = await this.requireRelation(id);
    const text = content.trim();
    if (text.length === 0) {
      throw new Error('empty interaction');
    }
    const log = relation.interactionLog.slice();
    log.push({ timestamp: Date.now(), content: text, source: source, citation: citation, allowContext: allowContext });
    await this.relationDao.update(id, log, relation.notes);
    relation.interactionLog = log;
    return toRelationDetail(relation);
  }

  /** Changes how far one existing entry may travel. */
  async updateInteractionScope(id: string, timestamp: number, citation: CitationScope,
    allowContext: boolean): Promise<RelationDetail> {
    const relation = await this.requireRelation(id);
    const log: InteractionLog[] = [];
    for (const entry of relation.interactionLog) {
      if (entry.timestamp === timestamp) {
        log.push({
          timestamp: entry.timestamp,
          content: entry.content,
          source: entry.source ?? 'observation',
          citation: citation,
          allowContext: allowContext
        });
      } else {
        log.push(entry);
      }
    }
    await this.relationDao.update(id, log, relation.notes);
    relation.interactionLog = log;
    return toRelationDetail(relation);
  }

  private async requireRelation(id: string): Promise<Relation> {
    const relation = await this.relationDao.queryById(id);
    if (relation === null) {
      throw new Error('relation not found');
    }
    return relation;
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

/** Strictness order: analyzable is loosest, sealed is strictest. */
function levelRank(level: SecurityLevel): number {
  if (level === SecurityLevel.ANALYZABLE) {
    return 0;
  }
  if (level === SecurityLevel.LOCAL_ONLY) {
    return 1;
  }
  return 2;
}
