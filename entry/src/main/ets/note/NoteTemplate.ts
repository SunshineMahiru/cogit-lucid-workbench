import { NoteFieldKey } from './NoteFieldKey';
import { NoteTemplateId } from './NoteTemplateId';

/** One labelled input rendered for a template. */
export interface NoteTemplateField {
  key: NoteFieldKey;
  /** Label shown in the form and reused when composing stored content */
  label: string;
  placeholder: string;
  /** When true the draft cannot be saved without a value */
  required: boolean;
  multiline: boolean;
}

/** A quick capture template: its fields plus the defaults applied on save. */
export interface NoteTemplate {
  id: NoteTemplateId;
  /** Label used in the picker and stored as the event type */
  label: string;
  /** One-line hint about when the template fits */
  hint: string;
  /** When true, saving a note also creates a linked decision record */
  createsDecision: boolean;
  fields: NoteTemplateField[];
  defaultTags: string[];
}
