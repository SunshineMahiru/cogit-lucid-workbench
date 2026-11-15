import { CostDraft } from './CostNote';
import { EvidenceDraft } from './EvidenceItem';

/** The six working zones of one review session; every field is optional by design. */
export interface ReviewPayload {
  /** 1. Scene and what was already done */
  scene: string;
  /** 2. Current model: explanation, prediction, scope, falsification */
  model: string;
  /** 3. Relations and the main contradiction */
  relation: string;
  /** 4. Multi-source correction: practice, other people, body, time, books */
  evidence: string;
  /** 5. Cost and motivation */
  cost: string;
  /** 6. Revision and the decision that follows */
  revision: string;
  /** Material ids this session quotes, in the order they were cited */
  materialIds?: string[];
  /** Decision ids this session cites, in the order they were cited */
  decisionIds?: string[];
  /** Evidence the session recorded, in the order it was written */
  evidenceDrafts?: EvidenceDraft[];
  /** Costs the session charged, in the order it was written */
  costDrafts?: CostDraft[];
}

/** Empty payload: a review may be saved with only the scene filled in. */
export function emptyReviewPayload(): ReviewPayload {
  return {
    scene: '',
    model: '',
    relation: '',
    evidence: '',
    cost: '',
    revision: '',
    materialIds: [],
    decisionIds: [],
    evidenceDrafts: [],
    costDrafts: []
  };
}

/** True when at least one zone carries text. */
export function hasAnyZone(payload: ReviewPayload): boolean {
  return payload.scene.trim().length > 0 || payload.model.trim().length > 0 ||
    payload.relation.trim().length > 0 || payload.evidence.trim().length > 0 ||
    payload.cost.trim().length > 0 || payload.revision.trim().length > 0;
}
