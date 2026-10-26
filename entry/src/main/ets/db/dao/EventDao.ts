import { relationalStore } from '@kit.ArkData';
import { Event } from '../../model/Event';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, EVENT_COLS } from '../DbConstants';

/** Data access for the event table. */
export class EventDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts an event, returns the row id. */
  async insert(event: Event): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [EVENT_COLS.ID]: event.id,
      [EVENT_COLS.TITLE]: event.title,
      [EVENT_COLS.CONTENT]: event.content,
      [EVENT_COLS.TYPE]: event.type,
      [EVENT_COLS.TIMESTAMP]: event.timestamp,
      [EVENT_COLS.TAGS]: JSON.stringify(event.tags),
      [EVENT_COLS.LEVEL]: event.level,
      [EVENT_COLS.RELATED_DECISION_IDS]: JSON.stringify(event.relatedDecisionIds),
      [EVENT_COLS.RELATED_RELATION_IDS]: JSON.stringify(event.relatedRelationIds)
    };
    return this.store.insert(DB_TABLES.EVENT, values);
  }

  /** Returns all events. */
  async queryAll(): Promise<Event[]> {
    return this.queryWith(new relationalStore.RdbPredicates(DB_TABLES.EVENT));
  }

  /** Returns the newest events first, capped at limit. */
  async queryRecent(limit: number): Promise<Event[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EVENT);
    predicates.orderByDesc(EVENT_COLS.TIMESTAMP).limitAs(limit);
    return this.queryWith(predicates);
  }

  private async queryWith(predicates: relationalStore.RdbPredicates): Promise<Event[]> {
    const resultSet = await this.store.query(predicates);
    const events: Event[] = [];
    while (resultSet.goToNextRow()) {
      events.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return events;
  }

  private mapRow(resultSet: relationalStore.ResultSet): Event {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.ID)),
      title: resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.TITLE)),
      content: resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.CONTENT)),
      type: resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.TYPE)),
      timestamp: resultSet.getLong(resultSet.getColumnIndex(EVENT_COLS.TIMESTAMP)),
      tags: JSON.parse(resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.TAGS))) as string[],
      level: resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.LEVEL)) as SecurityLevel,
      relatedDecisionIds: JSON.parse(resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.RELATED_DECISION_IDS))) as string[],
      relatedRelationIds: JSON.parse(resultSet.getString(resultSet.getColumnIndex(EVENT_COLS.RELATED_RELATION_IDS))) as string[]
    };
  }
}
