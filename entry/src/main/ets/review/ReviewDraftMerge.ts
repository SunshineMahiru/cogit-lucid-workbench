import { ReviewDraft } from './ReviewDraft';

/**
 * Returns the weekly draft for one plan node with the new facts merged in.
 * A missing draft is created; blank facts are replaced in place; repeated facts are skipped.
 */
export function mergeWeeklyDraft(existing: ReviewDraft | null, facts: string, planId: string,
  planNodeId: string): ReviewDraft {
  if (existing === null) {
    return {
      facts: facts,
      interpretation: '',
      contradiction: '',
      action: '',
      anchorIds: [],
      planId: planId,
      planNodeId: planNodeId
    };
  }
  if (existing.facts.trim().length === 0) {
    existing.facts = facts;
  } else if (!existing.facts.includes(facts)) {
    existing.facts = `${existing.facts.trimEnd()}\n\n${facts}`;
  }
  existing.planId = planId;
  existing.planNodeId = planNodeId;
  return existing;
}