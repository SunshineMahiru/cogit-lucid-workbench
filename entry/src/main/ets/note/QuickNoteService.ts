import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { createEvent } from '../model/factories';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { DbHelper } from '../db/DbHelper';
import { NoteDraft } from './NoteDraft';
import { composeNoteContent, deriveNoteTitle } from './NoteContentComposer';
import { buildDecisionFromNote } from './NoteDecisionComposer';
import { NoteListItem } from './NoteListItem';
import { toNoteListItems } from './NoteListMapper';
import { NoteDetail, toNoteDetail } from './NoteDetail';
import { findNoteTemplate } from './templates';
import { validateNoteDraft } from './NoteValidation';

/** Type stored on notes captured without a template. */
export const FREE_NOTE_TYPE = '速记';

/** Default page size for the note list. */
export const DEFAULT_NOTE_LIST_LIMIT = 50;

/** Result of persisting one quick note. */
export interface SavedNote {
  eventId: string;
  /** Set when the template also created a decision record */
  decisionId: string | null;
}

/** Saves and lists quick notes on top of the event and decision tables. */
export class QuickNoteService {
  private store: relationalStore.RdbStore;
  private eventDao: EventDao;
  private decisionDao: DecisionDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<QuickNoteService> {
    const store = await DbHelper.init(context);
    return new QuickNoteService(store);
  }

  /** Validates and persists a draft; throws with the first validation message when invalid. */
  async save(draft: NoteDraft): Promise<SavedNote> {
    const validation = validateNoteDraft(draft);
    if (!validation.valid) {
      throw new Error(validation.errors[0].message);
    }
    const event = buildEvent(draft);
    const decision = buildDecisionFromNote(draft, event.id);
    if (decision !== null) {
      event.relatedDecisionIds = [decision.id];
    }

    this.store.beginTransaction();
    try {
      await this.eventDao.insert(event);
      if (decision !== null) {
        await this.decisionDao.insert(decision);
      }
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }

    return { eventId: event.id, decisionId: decision === null ? null : decision.id };
  }

  /** Returns the newest notes as list rows. */
  async listRecent(limit: number = DEFAULT_NOTE_LIST_LIMIT): Promise<NoteListItem[]> {
    return this.listRecentPage(limit, 0);
  }

  /** Returns one page of the newest notes. */
  async listRecentPage(limit: number, offset: number): Promise<NoteListItem[]> {
    const events = await this.eventDao.queryRecentPage(normalizeLimit(limit), Math.max(0, offset));
    return toNoteListItems(events);
  }

  /** Returns the newest notes of one type; an empty type falls back to all notes. */
  async listByType(type: string, limit: number = DEFAULT_NOTE_LIST_LIMIT): Promise<NoteListItem[]> {
    return this.listByTypePage(type, limit, 0);
  }

  /** Returns one page of notes of one type. */
  async listByTypePage(type: string, limit: number, offset: number): Promise<NoteListItem[]> {
    const value = type.trim();
    if (value.length === 0) {
      return this.listRecentPage(limit, offset);
    }
    const events = await this.eventDao.queryByTypePage(value, normalizeLimit(limit), Math.max(0, offset));
    return toNoteListItems(events);
  }

  /** Returns one note for the detail page, or null when it no longer exists. */
  async findNote(noteId: string): Promise<NoteDetail | null> {
    const event = await this.eventDao.queryById(noteId);
    if (event === null) {
      return null;
    }
    return toNoteDetail(event);
  }

  /** Deletes one note and its event row. */
  async delete(noteId: string): Promise<void> {
    await this.eventDao.delete(noteId);
  }
}

/** Limits must stay positive for the SQL LIMIT clause to return rows. */
function normalizeLimit(limit: number): number {
  return limit > 0 ? Math.floor(limit) : DEFAULT_NOTE_LIST_LIMIT;
}

function buildEvent(draft: NoteDraft): Event {
  const event = createEvent();
  event.title = deriveNoteTitle(draft);
  event.content = composeNoteContent(draft);
  event.type = draft.templateId === null ? FREE_NOTE_TYPE : findNoteTemplate(draft.templateId).label;
  event.timestamp = draft.timestamp > 0 ? draft.timestamp : Date.now();
  event.tags = normalizeTags(draft.tags);
  event.relatedRelationIds = (draft.relatedRelationIds ?? []).slice();
  event.level = draft.level;
  return event;
}

function normalizeTags(tags: string[]): string[] {
  const values: string[] = [];
  for (const tag of tags) {
    const value = tag.trim();
    if (value.length > 0 && !values.includes(value)) {
      values.push(value);
    }
  }
  return values;
}
