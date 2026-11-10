import { NoteDraft, NoteEntry, readNoteEntry } from './NoteDraft';
import { NoteTemplate } from './NoteTemplate';

/** Builds one entry per template field; a source draft carries matching answers over. */
export function buildTemplateEntries(template: NoteTemplate, source: NoteDraft | null): NoteEntry[] {
  const entries: NoteEntry[] = [];
  for (const field of template.fields) {
    const value = source === null ? '' : readNoteEntry(source, field.key);
    entries.push({ key: field.key, value: value });
  }
  return entries;
}