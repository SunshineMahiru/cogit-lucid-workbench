import { Decision } from '../model/Decision';
import { createDecision } from '../model/factories';
import { NoteDraft, readNoteEntry } from './NoteDraft';
import { NoteFieldKey } from './NoteFieldKey';
import { NoteTemplateId } from './NoteTemplateId';
import { deriveNoteTitle } from './NoteContentComposer';

/** Builds the linked decision for a decision note; null for every other template. */
export function buildDecisionFromNote(draft: NoteDraft, eventId: string): Decision | null {
  if (draft.templateId !== NoteTemplateId.DECISION) {
    return null;
  }
  const decision = createDecision();
  decision.title = deriveNoteTitle(draft);
  decision.background = readNoteEntry(draft, NoteFieldKey.BACKGROUND).trim();
  decision.options = splitDecisionOptions(readNoteEntry(draft, NoteFieldKey.OPTIONS));
  decision.choice = readNoteEntry(draft, NoteFieldKey.CHOICE).trim();
  decision.expectedOutcome = readNoteEntry(draft, NoteFieldKey.EXPECTED_OUTCOME).trim();
  decision.timestamp = draft.timestamp;
  decision.relatedEventIds = [eventId];
  decision.relatedRelationIds = (draft.relatedRelationIds ?? []).slice();
  decision.level = draft.level;
  return decision;
}

/** Splits the options answer: one per line or separated by 、 or ，; duplicates are dropped. */
export function splitDecisionOptions(text: string): string[] {
  const options: string[] = [];
  for (const part of text.split(/[、，,\n]/)) {
    const value = part.trim();
    if (value.length > 0 && !options.includes(value)) {
      options.push(value);
    }
  }
  return options;
}
