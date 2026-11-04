import { NoteTemplateId } from '../note/NoteTemplateId';
import { PredictionStatus } from '../model/PredictionStatus';
import { PlanLinkModule } from '../model/PlanLinkModule';

/** Parameters accepted by the note editor route. */
export interface NoteEditParams {
  /** Pre-selected template; null opens the free-form editor */
  templateId: NoteTemplateId | null;
  /** Existing note id; when present the editor updates instead of creating */
  noteId?: string | null;
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

/** Parameters accepted by the prediction editor; a source id creates a revision. */
export interface PredictionCreateParams {
  sourcePredictionId: string | null;
}

/** Parameters accepted by the prediction settle route. */
export interface PredictionSettleParams {
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

/** Parameters accepted by the relation editor; null creates a new relation. */
export interface RelationEditParams {
  relationId: string | null;
}

/** Parameters accepted by the plan editor; null creates a new goal. */
export interface PlanEditParams {
  planId: string | null;
}

/** Parameters accepted by the plan detail route. */
export interface PlanDetailParams {
  planId: string;
}

/** Optional plan context when opening a review from a node. */
export interface PlanReviewParams {
  planId: string;
  nodeId: string;
}

/** Parameters accepted by the seven-day node route. */
export interface PlanNodeParams {
  nodeId: string;
}

/** Parameters accepted by the record link picker. */
export interface PlanLinkPickerParams {
  planId: string;
  nodeId: string;
  weekStart: string;
  weekEnd: string;
}

/** Parameters accepted by the reverse attach page. */
export interface PlanAttachParams {
  module: PlanLinkModule;
  targetId: string;
  label: string;
}

/** Parameters accepted by the status editor; null uses today. */
export interface StatusEditParams {
  date: string | null;
}
