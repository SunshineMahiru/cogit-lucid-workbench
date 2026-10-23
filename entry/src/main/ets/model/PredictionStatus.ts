/** Prediction log status: pending → settled. */
export enum PredictionStatus {
  /** Pending: judgment committed, not yet settled */
  PENDING = 'pending',
  /** Settled: outcome recorded and hit/miss marked */
  SETTLED = 'settled'
}
