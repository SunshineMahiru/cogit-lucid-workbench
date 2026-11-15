import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { MaterialForm, MaterialSource } from '../model/ExperienceMaterial';
import { SecurityLevel } from '../model/SecurityLevel';
import { NoteDepth, NoteEntry } from './NoteDraft';
import { NoteFieldKey } from './NoteFieldKey';
import { NoteTemplateId } from './NoteTemplateId';

const STORE_NAME = 'cogit_note_editor';
const KEY_DEPTH = 'note_depth_v1';
const KEY_DRAFT = 'note_draft_v1';
const KEY_RECENT_TAGS = 'note_recent_tags_v1';
const RECENT_TAG_LIMIT = 8;

/** Text of the five typed material rows kept alongside the body. */
export interface NoteEditorMaterialTexts {
  scene: string;
  feeling: string;
  body: string;
  existingAction: string;
  interpretation: string;
}

/** Source, form and level chosen for one material kind. */
export interface NoteEditorMeta {
  kind: string;
  source: MaterialSource;
  form: MaterialForm;
  level: SecurityLevel | null;
}

/** Everything the editor can put back after it was left without saving. */
export interface NoteEditorDraft {
  content: string;
  materials: NoteEditorMaterialTexts;
  metas: NoteEditorMeta[];
  tags: string[];
  relatedRelationIds: string[];
  level: SecurityLevel;
  depth: NoteDepth;
  /** Kind picked by the quick chip; empty means unclassified */
  quickKind: string;
  /** Template the draft was written under; null records a free-form draft */
  templateId: NoteTemplateId | null;
  /** Template answers kept by the draft */
  entries: NoteEntry[];
  timestamp: number;
}

/** Persists the editor depth, the unsaved draft and the recently used tags. */
export class NoteEditorStore {
  private prefs: preferences.Preferences;

  private constructor(prefs: preferences.Preferences) {
    this.prefs = prefs;
  }

  static async open(context: common.Context): Promise<NoteEditorStore> {
    const prefs = await preferences.getPreferences(context, { name: STORE_NAME });
    return new NoteEditorStore(prefs);
  }

  /** Returns the depth used last time; the default is NORMAL. */
  async loadDepth(): Promise<NoteDepth> {
    const raw = await this.prefs.get(KEY_DEPTH, NoteDepth.NORMAL);
    return typeof raw === 'string' ? parseDepth(raw as string) : NoteDepth.NORMAL;
  }

  /** Remembers the depth for the next new note. */
  async saveDepth(depth: NoteDepth): Promise<void> {
    await this.prefs.put(KEY_DEPTH, depth);
    await this.prefs.flush();
  }

  /** Writes the unsaved editor state; callers clear it once the note is saved. */
  async saveDraft(draft: NoteEditorDraft): Promise<void> {
    await this.prefs.put(KEY_DRAFT, JSON.stringify(draft));
    await this.prefs.flush();
  }

  /** Returns the stored draft, or null when nothing meaningful was left behind. */
  async loadDraft(): Promise<NoteEditorDraft | null> {
    const raw = await this.prefs.get(KEY_DRAFT, '');
    if (typeof raw !== 'string' || raw.trim().length === 0) {
      return null;
    }
    const draft = parseDraft(raw as string);
    if (draft === null || isEmptyDraft(draft)) {
      return null;
    }
    return draft;
  }

  /** Clears the stored draft; an empty value reads back as no draft. */
  async clearDraft(): Promise<void> {
    await this.prefs.put(KEY_DRAFT, '');
    await this.prefs.flush();
  }

  /** Returns the recently used tags, newest first. */
  async loadRecentTags(): Promise<string[]> {
    const raw = await this.prefs.get(KEY_RECENT_TAGS, '');
    if (typeof raw !== 'string' || raw.trim().length === 0) {
      return [];
    }
    return parseTags(raw as string);
  }

  /** Adds this note's tags to the recent list and returns the merged result. */
  async mergeRecentTags(tags: string[]): Promise<string[]> {
    const stored = await this.loadRecentTags();
    const merged: string[] = [];
    for (const tag of tags) {
      pushUniqueTag(merged, tag);
    }
    for (const tag of stored) {
      pushUniqueTag(merged, tag);
    }
    await this.prefs.put(KEY_RECENT_TAGS, JSON.stringify(merged));
    await this.prefs.flush();
    return merged;
  }
}

function pushUniqueTag(list: string[], tag: string): void {
  const value = tag.trim();
  if (value.length === 0 || list.includes(value) || list.length >= RECENT_TAG_LIMIT) {
    return;
  }
  list.push(value);
}

function parseDepth(raw: string): NoteDepth {
  if (raw === NoteDepth.QUICK) {
    return NoteDepth.QUICK;
  }
  if (raw === NoteDepth.DEEP) {
    return NoteDepth.DEEP;
  }
  return NoteDepth.NORMAL;
}

function readText(value: Object | undefined): string {
  return typeof value === 'string' ? value as string : '';
}

function readStringList(value: Object | undefined): string[] {
  const list: string[] = [];
  if (!Array.isArray(value)) {
    return list;
  }
  const items = value as Object[];
  for (const item of items) {
    if (typeof item === 'string') {
      const text = (item as string).trim();
      if (text.length > 0 && !list.includes(text)) {
        list.push(text);
      }
    }
  }
  return list;
}

function readLevel(value: Object | undefined): SecurityLevel | null {
  if (typeof value !== 'string') {
    return null;
  }
  const raw = value as string;
  if (raw === SecurityLevel.ANALYZABLE) {
    return SecurityLevel.ANALYZABLE;
  }
  if (raw === SecurityLevel.LOCAL_ONLY) {
    return SecurityLevel.LOCAL_ONLY;
  }
  if (raw === SecurityLevel.SEALED) {
    return SecurityLevel.SEALED;
  }
  return null;
}

function readSource(value: Object | undefined): MaterialSource {
  if (typeof value !== 'string') {
    return 'direct';
  }
  const raw = value as string;
  if (raw === 'reading' || raw === 'exercise' || raw === 'interaction' ||
    raw === 'reflection' || raw === 'external') {
    return raw as MaterialSource;
  }
  return 'direct';
}

function readForm(value: Object | undefined): MaterialForm {
  if (typeof value !== 'string') {
    return '';
  }
  const raw = value as string;
  if (raw === 'first_person' || raw === 'dialogue' || raw === 'third_person' ||
    raw === 'poem' || raw === 'reading_note' || raw === 'public_claim') {
    return raw as MaterialForm;
  }
  return '';
}

function readMaterialTexts(value: Object | undefined): NoteEditorMaterialTexts {
  if (value === undefined || value === null || typeof value !== 'object') {
    return { scene: '', feeling: '', body: '', existingAction: '', interpretation: '' };
  }
  const entry = value as Record<string, Object>;
  return {
    scene: readText(entry.scene),
    feeling: readText(entry.feeling),
    body: readText(entry.body),
    existingAction: readText(entry.existingAction),
    interpretation: readText(entry.interpretation)
  };
}

function readTemplateId(value: Object | undefined): NoteTemplateId | null {
  if (typeof value !== 'string') {
    return null;
  }
  const raw = value as string;
  if (raw === NoteTemplateId.DECISION || raw === NoteTemplateId.INTERPERSONAL ||
    raw === NoteTemplateId.EMOTION || raw === NoteTemplateId.BODY) {
    return raw as NoteTemplateId;
  }
  return null;
}

function readFieldKey(value: Object | undefined): NoteFieldKey | null {
  if (typeof value !== 'string') {
    return null;
  }
  const raw = value as string;
  if (raw === NoteFieldKey.BACKGROUND || raw === NoteFieldKey.OPTIONS ||
    raw === NoteFieldKey.CHOICE || raw === NoteFieldKey.EXPECTED_OUTCOME ||
    raw === NoteFieldKey.PERSON || raw === NoteFieldKey.INTERACTION ||
    raw === NoteFieldKey.FEELING || raw === NoteFieldKey.TRIGGER ||
    raw === NoteFieldKey.EMOTION || raw === NoteFieldKey.INTENSITY ||
    raw === NoteFieldKey.BODY_SIGNAL || raw === NoteFieldKey.CAUSE ||
    raw === NoteFieldKey.ACTION) {
    return raw as NoteFieldKey;
  }
  return null;
}

function readEntries(value: Object | undefined): NoteEntry[] {
  const entries: NoteEntry[] = [];
  if (!Array.isArray(value)) {
    return entries;
  }
  const items = value as Object[];
  for (const item of items) {
    if (item === null || typeof item !== 'object') {
      continue;
    }
    const entry = item as Record<string, Object>;
    const key = readFieldKey(entry.key);
    if (key === null) {
      continue;
    }
    entries.push({ key: key, value: readText(entry.value) });
  }
  return entries;
}

function readMetas(value: Object | undefined): NoteEditorMeta[] {
  const metas: NoteEditorMeta[] = [];
  if (!Array.isArray(value)) {
    return metas;
  }
  const items = value as Object[];
  for (const item of items) {
    if (item === null || typeof item !== 'object') {
      continue;
    }
    const entry = item as Record<string, Object>;
    const kind = readText(entry.kind);
    if (kind.length === 0) {
      continue;
    }
    metas.push({
      kind: kind,
      source: readSource(entry.source),
      form: readForm(entry.form),
      level: readLevel(entry.level)
    });
  }
  return metas;
}

function readJsonObject(raw: string): Object | null {
  try {
    return JSON.parse(raw) as Object;
  } catch (error) {
    return null;
  }
}

function parseDraft(raw: string): NoteEditorDraft | null {
  const parsed = readJsonObject(raw);
  if (parsed === null || typeof parsed !== 'object') {
    return null;
  }
  const entry = parsed as Record<string, Object>;
  const level = readLevel(entry.level);
  const timestamp = entry.timestamp;
  return {
    content: readText(entry.content),
    materials: readMaterialTexts(entry.materials),
    metas: readMetas(entry.metas),
    tags: readStringList(entry.tags),
    relatedRelationIds: readStringList(entry.relatedRelationIds),
    level: level === null ? SecurityLevel.LOCAL_ONLY : level,
    depth: parseDepth(readText(entry.depth)),
    quickKind: readText(entry.quickKind),
    templateId: readTemplateId(entry.templateId),
    entries: readEntries(entry.entries),
    timestamp: typeof timestamp === 'number' ? timestamp as number : Date.now()
  };
}

function parseTags(raw: string): string[] {
  const parsed = readJsonObject(raw);
  if (parsed === null) {
    return [];
  }
  return readStringList(parsed);
}

function isEmptyDraft(draft: NoteEditorDraft): boolean {
  if (draft.content.trim().length > 0) {
    return false;
  }
  if (draft.tags.length > 0 || draft.relatedRelationIds.length > 0) {
    return false;
  }
  for (const entry of draft.entries) {
    if (entry.value.trim().length > 0) {
      return false;
    }
  }
  const materials = draft.materials;
  if (materials.scene.trim().length > 0 || materials.feeling.trim().length > 0) {
    return false;
  }
  if (materials.body.trim().length > 0 || materials.existingAction.trim().length > 0) {
    return false;
  }
  return materials.interpretation.trim().length === 0;
}