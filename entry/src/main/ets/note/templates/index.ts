import { NoteTemplate } from '../NoteTemplate';
import { NoteTemplateId } from '../NoteTemplateId';
import { DECISION_NOTE_TEMPLATE } from './DecisionNoteTemplate';
import { INTERPERSONAL_NOTE_TEMPLATE } from './InterpersonalNoteTemplate';
import { EMOTION_NOTE_TEMPLATE } from './EmotionNoteTemplate';
import { BODY_NOTE_TEMPLATE } from './BodyNoteTemplate';

export { DECISION_NOTE_TEMPLATE, INTERPERSONAL_NOTE_TEMPLATE, EMOTION_NOTE_TEMPLATE, BODY_NOTE_TEMPLATE };

/** All quick capture templates, in picker order. */
export const NOTE_TEMPLATES: NoteTemplate[] = [
  DECISION_NOTE_TEMPLATE,
  INTERPERSONAL_NOTE_TEMPLATE,
  EMOTION_NOTE_TEMPLATE,
  BODY_NOTE_TEMPLATE
];

/** Returns the template for the given id; throws when the id is not registered. */
export function findNoteTemplate(id: NoteTemplateId): NoteTemplate {
  for (const template of NOTE_TEMPLATES) {
    if (template.id === id) {
      return template;
    }
  }
  throw new Error(`Unknown note template: ${id}`);
}
