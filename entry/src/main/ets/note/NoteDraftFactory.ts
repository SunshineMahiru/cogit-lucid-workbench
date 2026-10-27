import { SecurityLevel } from '../model/SecurityLevel';
import { NoteDraft, NoteEntry } from './NoteDraft';
import { NoteTemplateId } from './NoteTemplateId';
import { findNoteTemplate } from './templates';

/** Creates an empty draft for the template, or a free-form draft when the id is null. */
export function createNoteDraft(templateId: NoteTemplateId | null): NoteDraft {
  if (templateId === null) {
    return createFreeformNoteDraft();
  }
  const template = findNoteTemplate(templateId);
  const entries: NoteEntry[] = [];
  for (const field of template.fields) {
    entries.push({ key: field.key, value: '' });
  }
  return {
    templateId: templateId,
    title: '',
    content: '',
    entries: entries,
    tags: template.defaultTags.slice(),
    relatedRelationIds: [],
    level: SecurityLevel.LOCAL_ONLY,
    timestamp: Date.now()
  };
}

/** Creates a draft without template fields, for plain quick capture. */
export function createFreeformNoteDraft(): NoteDraft {
  return {
    templateId: null,
    title: '',
    content: '',
    entries: [],
    tags: [],
    relatedRelationIds: [],
    level: SecurityLevel.LOCAL_ONLY,
    timestamp: Date.now()
  };
}
