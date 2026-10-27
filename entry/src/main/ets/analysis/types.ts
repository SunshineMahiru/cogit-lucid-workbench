/** Shared context for deterministic analyzers. */
export interface AnalysisContext {
  /** Current timestamp, passed in explicitly so analyzers stay testable. */
  now: number;
}

/** A code plus human-readable message used by analyzer outputs. */
export interface AnalysisNote {
  code: string;
  message: string;
}
