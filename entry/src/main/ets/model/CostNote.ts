/** The dimension a cost entry is charged to. */
export type CostDimension = 'time' | 'attention' | 'body' | 'relationship' | 'money' | 'other';

/** The cost fields a review session fills in before it is saved. */
export interface CostDraft {
  dimension: CostDimension;
  text: string;
  bearable: boolean;
}

/** One cost kept against a review. */
export interface CostNote {
  id: string;
  /** Id of the review this cost belongs to. */
  reviewId: string;
  dimension: CostDimension;
  text: string;
  /** True when the cost was judged tolerable. */
  bearable: boolean;
  createdAt: number;
}