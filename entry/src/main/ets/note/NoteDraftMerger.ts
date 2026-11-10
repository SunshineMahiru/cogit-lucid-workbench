import { NoteDraft } from './NoteDraft';
import { buildTemplateEntries } from './NoteDraftEntries';
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
  return {
    templateId: templateId,
    title: draft.title,
    content: draft.content,
    entries: buildTemplateEntries(template, draft),
    tags: template.defaultTags.slice(),
    relatedRelationIds: draft.relatedRelationIds.slice(),
    level: draft.level,
    timestamp: draft.timestamp
  };
}
