import { NoteDraft, readNoteEntry } from './NoteDraft';
import { findNoteTemplate } from './templates';

/** Maximum length of a title derived from the body. */
export const NOTE_TITLE_MAX_LENGTH = 24;

/**
 * Joins the free-form body and the labelled answers into the stored content.
 * Blank answers are dropped so the record stays readable.
 */
export function composeNoteContent(draft: NoteDraft): string {
  const blocks: string[] = [];
  const content = draft.content.trim();
  if (content.length > 0) {
    blocks.push(content);
  }
  if (draft.templateId !== null) {
    for (const field of findNoteTemplate(draft.templateId).fields) {
      const value = readNoteEntry(draft, field.key).trim();
      if (value.length > 0) {
        blocks.push(`${field.label}：${value}`);
      }
    }
  }
  return blocks.join('\n');
}

/** Returns the explicit title, or derives one from the body when it is blank. */
export function deriveNoteTitle(draft: NoteDraft): string {
  const explicit = draft.title.trim();
  if (explicit.length > 0) {
    return explicit;
  }
  const content = draft.content.trim();
  if (content.length > 0) {
    return truncateTitle(firstLine(content));
  }
  if (draft.templateId !== null) {
    for (const field of findNoteTemplate(draft.templateId).fields) {
      const value = readNoteEntry(draft, field.key).trim();
      if (value.length > 0) {
        return truncateTitle(firstLine(value));
      }
    }
  }
  return '未命名速记';
}

function firstLine(text: string): string {
  const index = text.indexOf('\n');
  return index >= 0 ? text.slice(0, index).trim() : text;
}

function truncateTitle(text: string): string {
  return text.length > NOTE_TITLE_MAX_LENGTH ? `${text.slice(0, NOTE_TITLE_MAX_LENGTH)}…` : text;
}
