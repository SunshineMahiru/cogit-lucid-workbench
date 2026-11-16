/** The dimension a cost entry is charged to. */
export type CostDimension = 'meaning' | 'body' | 'relationship' | 'time' | 'public' | 'other';

/** Every dimension in display order. */
export const COST_DIMENSIONS: CostDimension[] = [
  'meaning',
  'body',
  'relationship',
  'time',
  'public',
  'other'
];

/** Narrows a stored value; values from older schemas read as other. */
export function toCostDimension(value: string): CostDimension {
  if (value === 'meaning' || value === 'body' || value === 'relationship' ||
    value === 'time' || value === 'public' || value === 'other') {
    return value;
  }
  return 'other';
}

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
