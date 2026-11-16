import { CostDraft } from './CostNote';
import { DecisionDraft } from './DecisionRecord';
import { EvidenceDraft } from './EvidenceItem';
import { WorkDepth } from './WorkDepth';

/** Where the drive behind one action comes from. */
export type MotivationKind = 'autonomous' | 'external' | 'internal_command' | 'unclear';

/** Every motivation in display order. */
export const MOTIVATION_KINDS: MotivationKind[] = [
  'autonomous',
  'external',
  'internal_command',
  'unclear'
];

/** Human label for one motivation; empty reads as not filled in. */
export function motivationText(value: string): string {
  if (value === 'autonomous') {
    return '自主选择';
  }
  if (value === 'external') {
    return '外部要求';
  }
  if (value === 'internal_command') {
    return '内部命令';
  }
  if (value === 'unclear') {
    return '无法辨认';
  }
  return '未填写';
}

/** One anchor cited by a review, with the reason it was chosen. */
export interface AnchorCitation {
  anchorId: string;
  /** Legacy single reason; kept so old reviews stay readable */
  reason: string;
  /** What this anchor supports in the current situation */
  supports?: string;
  /** What it limits or rules out */
  limits?: string;
  /** Where it does not apply */
  notApplicable?: string;
}

/** How a session ended when no decision was formed. */
export type ReviewStanding = 'decided' | 'no_action' | 'cannot_judge' | 'stop_analysis';

export const REVIEW_STANDINGS: ReviewStanding[] = [
  'decided',
  'no_action',
  'cannot_judge',
  'stop_analysis'
];

export function standingText(value: ReviewStanding): string {
  if (value === 'no_action') {
    return '暂未形成行动';
  }
  if (value === 'cannot_judge') {
    return '暂时无法判断';
  }
  if (value === 'stop_analysis') {
    return '不想继续分析';
  }
  return '已形成决定';
}

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
  /** Main decision the session recorded; absent when no type was chosen */
  decisionDraft?: DecisionDraft;
  /** Where the drive behind the recorded action comes from; absent when not answered */
  motivation?: MotivationKind;
  /** How much attention this session is meant to take; absent reads as normal */
  depth?: WorkDepth;
  /** Minutes the session is allowed to take; absent or 0 means no budget */
  timeBudget?: number;
  /** Anchors this session used, with the reason each one was chosen */
  anchorCitations?: AnchorCitation[];
  /** How the session ended; absent reads as decided */
  standing?: ReviewStanding;
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
