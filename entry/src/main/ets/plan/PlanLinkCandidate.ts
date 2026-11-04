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
  relationIds: string[];
  /** True when the record falls inside the node's week */
  suggested: boolean;
  /** Higher means closer to the current node and its existing links */
  score: number;
}

/** Scores candidates: same week first, then shared relations, then shared tags, then recency. */
export function markLinkSuggestions(items: LinkCandidate[], weekStart: string, weekEnd: string,
  preferredRelations: string[], preferredTags: string[]): LinkCandidate[] {
  const start = new Date(`${weekStart}T00:00:00`).getTime();
  const end = new Date(`${weekEnd}T23:59:59`).getTime();
  for (const item of items) {
    item.suggested = item.timestamp >= start && item.timestamp <= end;
    let score = item.suggested ? 4 : 0;
    for (const relationId of item.relationIds) {
      if (preferredRelations.includes(relationId)) {
        score += 2;
      }
    }
    for (const tag of item.tags) {
      if (preferredTags.includes(tag)) {
        score += 1;
      }
    }
    item.score = score;
  }
  return items.sort((left: LinkCandidate, right: LinkCandidate) => {
    if (left.score !== right.score) {
      return right.score - left.score;
    }
    return right.timestamp - left.timestamp;
  });
}
