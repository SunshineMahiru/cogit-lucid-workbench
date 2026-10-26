import { NoteDraft, NoteEntry, readNoteEntry } from './NoteDraft';
import { NoteFieldKey } from './NoteFieldKey';
import { findNoteTemplate } from './templates';

/** One reason why a draft cannot be saved. */
export interface NoteValidationError {
  /** Field that failed; null when the problem belongs to the whole draft */
  key: NoteFieldKey | null;
  message: string;
}

/** Outcome of validating a draft. */
export interface NoteValidationResult {
  valid: boolean;
  errors: NoteValidationError[];
}

/**
 * Checks a draft before saving: required template fields must be filled and
 * a template note must carry at least one answer somewhere.
 */
export function validateNoteDraft(draft: NoteDraft): NoteValidationResult {
  const errors: NoteValidationError[] = [];

  if (draft.templateId === null) {
    if (draft.content.trim().length === 0) {
      errors.push({ key: null, message: '内容不能为空' });
    }
    return { valid: errors.length === 0, errors: errors };
  }

  const template = findNoteTemplate(draft.templateId);
  for (const field of template.fields) {
    if (field.required && readNoteEntry(draft, field.key).trim().length === 0) {
      errors.push({ key: field.key, message: `${field.label}不能为空` });
    }
  }
  if (errors.length === 0 && draft.content.trim().length === 0 && isBlank(draft.entries)) {
    errors.push({ key: null, message: '至少填写一项内容' });
  }
  return { valid: errors.length === 0, errors: errors };
}

function isBlank(entries: NoteEntry[]): boolean {
  for (const entry of entries) {
    if (entry.value.trim().length > 0) {
      return false;
    }
  }
  return true;
}
