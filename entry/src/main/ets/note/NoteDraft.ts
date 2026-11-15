import { SecurityLevel } from '../model/SecurityLevel';
import { MaterialForm, MaterialSource } from '../model/ExperienceMaterial';
import { NoteFieldKey } from './NoteFieldKey';
import { NoteTemplateId } from './NoteTemplateId';

/** How much of the editor the author wants during capture. */
export enum NoteDepth {
  /** Body plus one kind chip */
  QUICK = 'quick',
  /** Classification rows, tags and level; no relations */
  NORMAL = 'normal',
  /** Normal plus the interpretation row and relations */
  DEEP = 'deep'
}

/** A single template answer held by a draft. */
export interface NoteEntry {
  key: NoteFieldKey;
  value: string;
}

/** One optional typed material captured alongside the body. */
export interface NoteMaterialDraft {
  kind: string;
  text: string;
  /** Where the material comes from; empty reads as a direct experience */
  source?: MaterialSource;
  /** Optional genre marker; empty reads as unlabelled */
  form?: MaterialForm;
  /** Per-material level; absent means the material follows the note level */
  level?: SecurityLevel;
}

/** Editable state of one quick note before it is persisted. */
export interface NoteDraft {
  /** Null records a free-form note without template fields */
  templateId: NoteTemplateId | null;
  /** Optional title; derived from the body when blank */
  title: string;
  /** Free-form body, kept alongside the template answers */
  content: string;
  /** Template answers in field order; empty for free-form notes */
  entries: NoteEntry[];
  tags: string[];
  /** Relations this note refers to; empty when none */
  relatedRelationIds: string[];
  /** Security level copied onto the saved event */
  level: SecurityLevel;
  /** Optional typed materials; an empty list means the body is the only material */
  materials?: NoteMaterialDraft[];
  /** Capture depth chosen in the editor; absent reads as NORMAL */
  depth?: NoteDepth;
  /** Capture time in milliseconds */
  timestamp: number;
}

/** Reads one answer; returns an empty string when the draft has no such entry. */
export function readNoteEntry(draft: NoteDraft, key: NoteFieldKey): string {
  for (const entry of draft.entries) {
    if (entry.key === key) {
      return entry.value;
    }
  }
  return '';
}
