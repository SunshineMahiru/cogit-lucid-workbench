import { SecurityLevel } from '../model/SecurityLevel';
import { NoteFieldKey } from './NoteFieldKey';
import { NoteTemplateId } from './NoteTemplateId';

/** A single template answer held by a draft. */
export interface NoteEntry {
  key: NoteFieldKey;
  value: string;
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
  /** Security level copied onto the saved event */
  level: SecurityLevel;
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
