/** Security classification for a record, deciding whether it may enter LLM context. */
export enum SecurityLevel {
  /** May enter LLM context with user authorization */
  ANALYZABLE = 'analyzable',
  /** Never touches LLM; default level */
  LOCAL_ONLY = 'local_only',
  /** Sealed: excluded from all aggregation and export */
  SEALED = 'sealed'
}
