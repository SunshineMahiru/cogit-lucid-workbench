/** Lifecycle of a plan goal. */
export enum PlanStatus {
  ACTIVE = 'active',
  PAUSED = 'paused',
  DONE = 'done',
  ARCHIVED = 'archived'
}

/** Lifecycle of an optional project under a plan. */
export enum PlanProjectStatus {
  ACTIVE = 'active',
  DONE = 'done',
  ARCHIVED = 'archived'
}

/** Lifecycle of one seven-day node. */
export enum PlanNodeStatus {
  OPEN = 'open',
  CLOSED = 'closed'
}
