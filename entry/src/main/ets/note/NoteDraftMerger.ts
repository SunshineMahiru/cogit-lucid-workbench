import { NoteDraft, NoteEntry, readNoteEntry } from './NoteDraft';
import { NoteTemplateId } from './NoteTemplateId';
import { findNoteTemplate } from './templates';

/**
 * Switches a draft to another template while keeping answers whose field keys
 * exist in both templates. Free-form mode clears template entries and tags.
 */
export function mergeDraftEntries(draft: NoteDraft, templateId: NoteTemplateId | null): NoteDraft {
  if (templateId === null) {
    return {
      templateId: null,
      title: draft.title,
      content: draft.content,
      entries: [],
      tags: [],
      relatedRelationIds: draft.relatedRelationIds.slice(),
      level: draft.level,
      timestamp: draft.timestamp
    };
  }
  const template = findNoteTemplate(templateId);
  const entries: NoteEntry[] = [];
  for (const field of template.fields) {
    entries.push({ key: field.key, value: readNoteEntry(draft, field.key) });
  }
  return {
    templateId: templateId,
    title: draft.title,
    content: draft.content,
    entries: entries,
    tags: template.defaultTags.slice(),
    relatedRelationIds: draft.relatedRelationIds.slice(),
    level: draft.level,
    timestamp: draft.timestamp
  };
}
