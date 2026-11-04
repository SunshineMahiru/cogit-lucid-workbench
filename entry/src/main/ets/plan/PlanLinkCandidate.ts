import { PlanLinkModule } from '../model/PlanLinkModule';

/** One record that can be linked to a plan node. */
export interface LinkCandidate {
  module: PlanLinkModule;
  targetId: string;
  title: string;
  subtitle: string;
  /** Milliseconds; 0 when the source has no timestamp */
  timestamp: number;
  tags: string[];
  /** True when the record falls inside the node's week */
  suggested: boolean;
}

/** Marks candidates inside the week and puts them first, then newest first. */
export function markLinkSuggestions(items: LinkCandidate[], weekStart: string, weekEnd: string): LinkCandidate[] {
  const start = new Date(`${weekStart}T00:00:00`).getTime();
  const end = new Date(`${weekEnd}T23:59:59`).getTime();
  for (const item of items) {
    item.suggested = item.timestamp >= start && item.timestamp <= end;
  }
  return items.sort((left: LinkCandidate, right: LinkCandidate) => {
    if (left.suggested !== right.suggested) {
      return left.suggested ? -1 : 1;
    }
    return right.timestamp - left.timestamp;
  });
}
