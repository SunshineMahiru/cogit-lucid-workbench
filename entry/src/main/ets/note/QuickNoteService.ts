import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { SecurityLevel } from '../model/SecurityLevel';
import { createEvent } from '../model/factories';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { ExperienceMaterialDao } from '../db/dao/ExperienceMaterialDao';
import { DbHelper } from '../db/DbHelper';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { NoteDraft, NoteMaterialDraft } from './NoteDraft';
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
  private materialDao: ExperienceMaterialDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.materialDao = new ExperienceMaterialDao(store);
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
      await this.saveMaterials(draft, event.id, event.timestamp, event.level);
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


  /**
   * Stores the typed materials captured with this note. When the user did not classify anything,
   * the body itself becomes one unclassified material so the review flow still has something to cite.
   */
  private async saveMaterials(draft: NoteDraft, eventId: string, observedAt: number,
    level: SecurityLevel): Promise<void> {
    const typed = (draft.materials ?? []).filter((item: NoteMaterialDraft) => item.text.trim().length > 0);
    if (typed.length === 0) {
      if (draft.content.trim().length === 0) {
        return;
      }
      await this.materialDao.insert({
        id: `mt-${eventId}-0`,
        eventId: eventId,
        kind: 'unclassified',
        form: '',
        text: draft.content,
        observedAt: observedAt,
        source: 'direct',
        sourceStance: '',
        level: level,
        revisionOf: '',
        deleted: false,
        createdAt: Date.now()
      });
      return;
    }
    let index = 0;
    for (const item of typed) {
      index += 1;
      await this.materialDao.insert({
        id: `mt-${eventId}-${index}`,
        eventId: eventId,
        kind: item.kind as ExperienceMaterial['kind'],
        form: item.form ?? '',
        text: item.text,
        observedAt: observedAt,
        source: item.source ?? 'direct',
        sourceStance: '',
        level: clampMaterialLevel(item.level, level),
        revisionOf: '',
        deleted: false,
        createdAt: Date.now()
      });
    }
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

  /** Returns the timestamps of notes in one range; sealed notes are left out. */
  async timestampsBetween(startMs: number, endMs: number): Promise<number[]> {
    const events = await this.eventDao.queryBetween(startMs, endMs);
    const stamps: number[] = [];
    for (const event of events) {
      if (event.level !== SecurityLevel.SEALED) {
        stamps.push(event.timestamp);
      }
    }
    return stamps;
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
    const detail = toNoteDetail(event);
    detail.materials = await this.materialDao.queryByEvent(noteId);
    return detail;
  }

  /** Updates the editable fields of an existing note while keeping its id. */
  async updateNote(noteId: string, draft: NoteDraft): Promise<NoteDetail> {
    const validation = validateNoteDraft(draft);
    if (!validation.valid) {
      throw new Error(validation.errors[0].message);
    }
    const event = await this.eventDao.queryById(noteId);
    if (event === null) {
      throw new Error('note not found');
    }
    applyDraft(event, draft);
    this.store.beginTransaction();
    try {
      await this.eventDao.update(event);
      await this.materialDao.deleteByEvent(event.id);
      await this.saveMaterials(draft, event.id, event.timestamp, event.level);
      // Defensive only: saveMaterials already narrows every level it writes. This keeps rows
      // that were stored under an earlier record level in line with the new one.
      await this.materialDao.clampLevelsByEvent(event.id, event.level);
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
    const detail = toNoteDetail(event);
    detail.materials = await this.materialDao.queryByEvent(event.id);
    return detail;
  }

  /** Marks one note and its materials deleted; the rows stay for history references. */
  async delete(noteId: string): Promise<void> {
    this.store.beginTransaction();
    try {
      await this.eventDao.markDeleted(noteId);
      await this.materialDao.markDeletedByEvent(noteId);
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
  }
}

/** Limits must stay positive for the SQL LIMIT clause to return rows. */
function normalizeLimit(limit: number): number {
  return limit > 0 ? Math.floor(limit) : DEFAULT_NOTE_LIST_LIMIT;
}

function buildEvent(draft: NoteDraft): Event {
  const event = createEvent();
  event.type = draft.templateId === null ? FREE_NOTE_TYPE : findNoteTemplate(draft.templateId).label;
  event.timestamp = draft.timestamp > 0 ? draft.timestamp : Date.now();
  applyDraft(event, draft);
  return event;
}

function applyDraft(event: Event, draft: NoteDraft): void {
  event.title = deriveNoteTitle(draft);
  event.content = composeNoteContent(draft);
  event.tags = normalizeTags(draft.tags);
  event.relatedRelationIds = (draft.relatedRelationIds ?? []).slice();
  event.level = draft.level;
}

/** Keeps a material at or below the record level; stricter choices win. */
function clampMaterialLevel(materialLevel: SecurityLevel | undefined, recordLevel: SecurityLevel): SecurityLevel {
  const wanted = materialLevel === undefined ? recordLevel : materialLevel;
  if (recordLevel === SecurityLevel.SEALED) {
    return SecurityLevel.SEALED;
  }
  if (recordLevel === SecurityLevel.LOCAL_ONLY && wanted === SecurityLevel.ANALYZABLE) {
    return SecurityLevel.LOCAL_ONLY;
  }
  return wanted;
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
