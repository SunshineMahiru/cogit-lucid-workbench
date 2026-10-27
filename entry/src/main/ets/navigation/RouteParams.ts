import { NoteTemplateId } from '../note/NoteTemplateId';
import { PredictionStatus } from '../model/PredictionStatus';

/** Parameters accepted by the note editor route. */
export interface NoteEditParams {
  /** Pre-selected template; null opens the free-form editor */
  templateId: NoteTemplateId | null;
}

/** Parameters accepted by the note list route. */
export interface NoteListParams {
  /** Type filter; an empty string shows every note */
  filterType: string;
}

/** Parameters accepted by the prediction list route. */
export interface PredictionListParams {
  /** Status filter; null shows every prediction */
  status: PredictionStatus | null;
}

/** Parameters accepted by the prediction detail route. */
export interface PredictionDetailParams {
  predictionId: string;
}

/** Parameters accepted by the note detail route. */
export interface NoteDetailParams {
  noteId: string;
}

/** Parameters accepted by the review detail route. */
export interface ReviewDetailParams {
  reviewId: string;
}

/** Parameters accepted by the relation detail route. */
export interface RelationDetailParams {
  relationId: string;
}
