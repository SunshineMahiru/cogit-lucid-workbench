import { PredictionStatus } from '../model/PredictionStatus';

/** Row model rendered by the prediction list. */
export interface PredictionListItem {
  id: string;
  target: string;
  judgment: string;
  confidence: number;
  /** Due date in YYYY-MM-DD */
  settlementDate: string;
  status: PredictionStatus;
  hit: boolean | null;
  actualResult: string;
  createdAt: number;
}

/** Counts shown above the prediction list. */
export interface PredictionSummary {
  total: number;
  pending: number;
  settled: number;
  hits: number;
  hitRate: number;
}
