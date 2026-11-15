import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { SecurityLevel } from '../model/SecurityLevel';
import { createEvent } from '../model/factories';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { ExperienceMaterialDao } from '../db/dao/ExperienceMaterialDao';
import { PlanDao } from '../db/dao/PlanDao';
import { ReviewMaterialDao } from '../db/dao/ReviewMaterialDao';
import { DbHelper } from '../db/DbHelper';
import { DB_TABLES, MATERIAL_COLS } from '../db/DbConstants';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { NoteDepth, NoteDraft, NoteMaterialDraft } from './NoteDraft';
import { composeNoteContent, deriveNoteTitle } from './NoteContentComposer';
import { buildDecisionFromNote } from './NoteDecisionComposer';
import { NoteListItem } from './NoteListItem';
import { DELETED_NOTE_TITLE, toNoteListItems } from './NoteListMapper';
import { NoteDetail, toNoteDetail } from './NoteDetail';
import { findNoteTemplate } from './templates';
import { validateNoteDraft } from './NoteValidation';

/** Type stored on notes captured without a template. */
export const FREE_NOTE_TYPE = '速记';

/** Default page size for the note list. */
export const DEFAULT_NOTE_LIST_LIMIT = 50;

/** Window during which a deleted note keeps its text and can still be restored. */
export const DELETE_UNDO_WINDOW_MS = 5000;

/** Purge timers shared by every service instance, keyed by the root id of the deleted note. */
const purgeTimers: Map<string, number> = new Map();

/** Result of persisting one quick note. */
export interface SavedNote {
  eventId: string;
  /** Set when the template also created a decision record */
  decisionId: string | null;
}

/** Result of appending one revision to an existing note. */
export interface SavedRevision {
  eventId: string;
  version: number;
}

/** Saves and lists quick notes on top of the event and decision tables. */
export class QuickNoteService {
  private store: relationalStore.RdbStore;
  private eventDao: EventDao;
  private decisionDao: DecisionDao;
  private materialDao: ExperienceMaterialDao;
  private reviewMaterialDao: ReviewMaterialDao;
  private planDao: PlanDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.materialDao = new ExperienceMaterialDao(store);
    this.reviewMaterialDao = new ReviewMaterialDao(store);
    this.planDao = new PlanDao(store);
  }

  /** Opens the database, wipes leftovers from interrupted deletes, and returns the service. */
  static async open(context: common.Context): Promise<QuickNoteService> {
    const store = await DbHelper.init(context);
    const service = new QuickNoteService(store);
    await service.purgeLeftovers();
    return service;
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
   * Appends a revision of an existing note as a new event row. The original row keeps its text and
   * version; the new row points at the root note and carries the next version number.
   */
  async saveRevision(originalId: string, draft: NoteDraft): Promise<SavedRevision> {
    const validation = validateNoteDraft(draft);
    if (!validation.valid) {
      throw new Error(validation.errors[0].message);
    }
    const original = await this.eventDao.queryById(originalId);
    if (original === null) {
      throw new Error('note not found');
    }
    const rootId = noteRootId(original);
    const event = buildEvent(draft);
    event.revisionOf = rootId;

    this.store.beginTransaction();
    try {
      // Deleted revisions stay in the chain, so a removed v2 still reserves version 2.
      const chain = await this.chainRows(rootId);
      const version = highestVersion(chain) + 1;
      if (chain.some((row: Event) => (row.version ?? 1) === version)) {
        throw new Error('revision version already exists');
      }
      event.version = version;
      await this.eventDao.insert(event);
      await this.saveMaterials(draft, event.id, event.timestamp, event.level);
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }

    return { eventId: event.id, version: event.version ?? 1 };
  }

  /** Returns every row of one revision chain, deleted rows included. */
  private async chainRows(rootId: string): Promise<Event[]> {
    const rows = await this.eventDao.queryAllIncludingDeleted();
    return rows.filter((row: Event) => noteRootId(row) === rootId);
  }

  /** Returns the live rows of one revision chain, oldest version first. */
  async listRevisions(noteId: string): Promise<NoteListItem[]> {
    const rows = await this.eventDao.queryAllIncludingDeleted();
    const anchor = rows.find((row: Event) => row.id === noteId);
    const rootId = anchor === undefined ? noteId : noteRootId(anchor);
    const live = rows.filter((row: Event) => noteRootId(row) === rootId && row.deleted !== true);
    live.sort((left: Event, right: Event) => (left.version ?? 1) - (right.version ?? 1));
    return toNoteListItems(live);
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
        sourceStance: item.stance ?? '',
        interactionSource: item.interactionSource ?? '',
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

  /** Returns one page of the newest notes; only the latest revision of each note shows up. */
  async listRecentPage(limit: number, offset: number): Promise<NoteListItem[]> {
    const roots = latestPerRoot(await this.eventDao.queryAllLive());
    return toNoteListItems(pageOf(roots, limit, offset));
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

  /** Returns one page of notes of one type; only the latest revision of each note shows up. */
  async listByTypePage(type: string, limit: number, offset: number): Promise<NoteListItem[]> {
    const value = type.trim();
    if (value.length === 0) {
      return this.listRecentPage(limit, offset);
    }
    const roots = latestPerRoot(await this.eventDao.queryLiveByType(value));
    return toNoteListItems(pageOf(roots, limit, offset));
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
    // Snapshot rows cite the old ids, which a rewrite may reuse, so capture them before the wipe.
    const oldMaterialIds = (await this.materialDao.queryByEvent(event.id)).map(
      (material: ExperienceMaterial) => material.id);
    this.store.beginTransaction();
    try {
      await this.eventDao.update(event);
      await this.materialDao.deleteByEvent(event.id);
      await this.saveMaterials(draft, event.id, event.timestamp, event.level);
      // Defensive only: saveMaterials already narrows every level it writes. This keeps rows
      // that were stored under an earlier record level in line with the new one.
      await this.materialDao.clampLevelsByEvent(event.id, event.level);
      // Citing reviews must not keep text or a wider level than the record now allows.
      await this.reviewMaterialDao.clampLevels(oldMaterialIds, event.level);
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
    const detail = toNoteDetail(event);
    detail.materials = await this.materialDao.queryByEvent(event.id);
    return detail;
  }

  /** True when the note is marked deleted; such a note only shows its deletion state. */
  async isDeleted(noteId: string): Promise<boolean> {
    const event = await this.eventDao.queryById(noteId);
    return event !== null && event.deleted === true;
  }

  /**
   * Hides the whole chain and returns at once. The text stays until the undo window closes, so a
   * restore inside that window only has to clear the flag.
   */
  async delete(noteId: string): Promise<void> {
    const target = await this.eventDao.queryById(noteId);
    if (target === null) {
      return;
    }
    const rootId = noteRootId(target);
    const chain = await this.chainRows(rootId);
    this.store.beginTransaction();
    try {
      for (const row of chain) {
        await this.eventDao.markDeleted(row.id);
      }
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
    this.schedulePurge(rootId);
  }

  /** Restores a note deleted inside the undo window; false when the note is already gone. */
  async undoDelete(noteId: string): Promise<boolean> {
    const target = await this.eventDao.queryById(noteId);
    if (target === null || target.deleted !== true) {
      return false;
    }
    const rootId = noteRootId(target);
    this.cancelPurge(rootId);
    const chain = await this.chainRows(rootId);
    this.store.beginTransaction();
    try {
      for (const row of chain) {
        await this.eventDao.restore(row.id);
      }
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
    return true;
  }

  /** Wipes a deleted note without waiting for the timer; used by the tests and the sweep. */
  async purgeNow(noteId: string): Promise<void> {
    const target = await this.eventDao.queryById(noteId);
    if (target === null) {
      return;
    }
    const rootId = noteRootId(target);
    this.cancelPurge(rootId);
    await this.purge(rootId);
  }

  /** Wipes every deleted row whose text is still present; returns how many chains it purged. */
  async purgeLeftovers(): Promise<number> {
    const rows = await this.eventDao.queryAllIncludingDeleted();
    const done: Set<string> = new Set();
    let purged = 0;
    for (const row of rows) {
      if (row.deleted !== true || row.content.trim().length === 0) {
        continue;
      }
      const rootId = noteRootId(row);
      // A live timer means the user may still undo, so the sweep leaves that chain alone.
      if (done.has(rootId) || purgeTimers.has(rootId)) {
        continue;
      }
      done.add(rootId);
      await this.purge(rootId);
      purged += 1;
    }
    return purged;
  }

  /** Wipes the text of one note chain; the rows themselves stay as tombstones. */
  private async purge(rootId: string): Promise<void> {
    const chain = await this.chainRows(rootId);
    if (chain.length === 0) {
      return;
    }
    this.store.beginTransaction();
    try {
      const materialIds: string[] = [];
      for (const row of chain) {
        const live = await this.materialDao.queryByEvent(row.id);
        for (const material of live) {
          materialIds.push(material.id);
        }
      }
      // Citing reviews lose the copied text before the rows it came from are blanked.
      await this.reviewMaterialDao.clearSnapshots(materialIds);
      for (const row of chain) {
        // The title becomes a tombstone so the row reads correctly wherever it is looked up by id.
        row.title = DELETED_NOTE_TITLE;
        row.content = '';
        await this.eventDao.update(row);
        await this.clearMaterialText(row.id);
        await this.materialDao.markDeletedByEvent(row.id);
        await this.clearDecisionText(row.id);
        await this.planDao.updateLinkLabelsByTarget(PlanLinkModule.NOTE, row.id, DELETED_NOTE_TITLE);
      }
      for (const row of chain) {
        await this.eventDao.markDeleted(row.id);
      }
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
  }

  private schedulePurge(rootId: string): void {
    this.cancelPurge(rootId);
    const timer = setTimeout(() => {
      purgeTimers.delete(rootId);
      this.purge(rootId).catch(() => {
        // The text survives; the next open() sweeps it again.
      });
    }, DELETE_UNDO_WINDOW_MS);
    purgeTimers.set(rootId, timer);
  }

  private cancelPurge(rootId: string): void {
    const timer = purgeTimers.get(rootId);
    if (timer !== undefined) {
      clearTimeout(timer);
      purgeTimers.delete(rootId);
    }
  }

  /** Blanks the text fields of every decision that cites this note. */
  private async clearDecisionText(eventId: string): Promise<void> {
    const decisions = await this.decisionDao.queryByEvent(eventId);
    for (const decision of decisions) {
      await this.decisionDao.clearText(decision.id);
    }
  }

  /** Blank text in every material of one event before the rows are marked deleted. */
  private async clearMaterialText(eventId: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [MATERIAL_COLS.TEXT]: ''
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.EXPERIENCE_MATERIAL);
    predicates.equalTo(MATERIAL_COLS.EVENT_ID, eventId);
    return this.store.update(values, predicates);
  }
}

/** Limits must stay positive for the SQL LIMIT clause to return rows. */
function normalizeLimit(limit: number): number {
  return limit > 0 ? Math.floor(limit) : DEFAULT_NOTE_LIST_LIMIT;
}

/** Applies a page window to rows that are already deduplicated. */
function pageOf(events: Event[], limit: number, offset: number): Event[] {
  const start = Math.max(0, offset);
  return events.slice(start, start + normalizeLimit(limit));
}

function buildEvent(draft: NoteDraft): Event {
  const event = createEvent();
  event.type = draft.templateId === null || draft.depth === NoteDepth.QUICK ?
    FREE_NOTE_TYPE : findNoteTemplate(draft.templateId).label;
  event.timestamp = draft.timestamp > 0 ? draft.timestamp : Date.now();
  event.revisionOf = '';
  event.version = 1;
  applyDraft(event, draft);
  return event;
}

/** Root id of a note revision; an original note is its own root. */
function noteRootId(event: Event): string {
  const root = event.revisionOf ?? '';
  return root.length > 0 ? root : event.id;
}

/** Highest version present in a chain; 0 when the chain is empty. */
function highestVersion(events: Event[]): number {
  let max = 0;
  for (const event of events) {
    const version = event.version ?? 1;
    if (version > max) {
      max = version;
    }
  }
  return max;
}

/** Keeps the highest revision of every note, in the order the query returned them. */
export function latestPerRoot(events: Event[]): Event[] {
  const best: Map<string, number> = new Map();
  for (const event of events) {
    const root = noteRootId(event);
    const version = event.version ?? 1;
    const current: number = best.get(root) ?? 0;
    if (version > current) {
      best.set(root, version);
    }
  }
  const kept: Event[] = [];
  const seen: Set<string> = new Set();
  for (const event of events) {
    const root = noteRootId(event);
    if (seen.has(root)) {
      continue;
    }
    if ((event.version ?? 1) === (best.get(root) ?? 1)) {
      seen.add(root);
      kept.push(event);
    }
  }
  return kept;
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
