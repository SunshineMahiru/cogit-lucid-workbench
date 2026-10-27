import { NoteTemplateId } from '../note/NoteTemplateId';

/** Parameters accepted by the note editor route. */
export interface NoteEditParams {
  /** Pre-selected template; null opens the free-form editor */
  templateId: NoteTemplateId | null;
}

/** Parameters accepted by the prediction detail route. */
export interface PredictionDetailParams {
  predictionId: string;
}

/** Parameters accepted by the note detail route. */
export interface NoteDetailParams {
  noteId: string;
}
