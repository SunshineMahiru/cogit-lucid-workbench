import { SecurityLevel } from './SecurityLevel';
import { TrustLevel } from './TrustLevel';
import { Event } from './Event';
import { Decision } from './Decision';
import { Relation } from './Relation';
import { Prediction } from './Prediction';
import { PredictionStatus } from './PredictionStatus';
import { Anchor } from './Anchor';
import { StatusRecord } from './StatusRecord';
import { ReviewPeriod } from './ReviewPeriod';
import { ReviewResult } from './ReviewResult';

let seq = 0;

function newId(prefix: string): string {
  seq += 1;
  return `${prefix}_${Date.now()}_${seq}`;
}

/** Creates a default Event. */
export function createEvent(): Event {
  return {
    id: newId('ev'),
    title: '',
    content: '',
    type: '',
    timestamp: Date.now(),
    tags: [],
    level: SecurityLevel.LOCAL_ONLY,
    relatedDecisionIds: [],
    relatedRelationIds: []
  };
}

/** Creates a default Decision. */
export function createDecision(): Decision {
  return {
    id: newId('dc'),
    title: '',
    background: '',
    options: [],
    choice: '',
    expectedOutcome: '',
    timestamp: Date.now(),
    relatedEventIds: [],
    relatedRelationIds: [],
    level: SecurityLevel.LOCAL_ONLY,
    reviewed: false
  };
}

/** Creates a default Relation. */
export function createRelation(): Relation {
  return {
    id: newId('rl'),
    name: '',
    trustLevel: TrustLevel.FRIENDLY,
    interactionLog: [],
    rawMaterialTest: false,
    forbidAnalysis: false,
    level: SecurityLevel.LOCAL_ONLY,
    notes: ''
  };
}

/** Creates a default Prediction. */
export function createPrediction(): Prediction {
  return {
    id: newId('pr'),
    target: '',
    judgment: '',
    confidence: 0,
    reason: '',
    settlementDate: '',
    status: PredictionStatus.PENDING,
    actualResult: '',
    hit: null,
    version: 1,
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: Date.now()
  };
}

/** Creates a default Anchor. */
export function createAnchor(): Anchor {
  return {
    id: newId('an'),
    text: '',
    source: '',
    order: 0,
    level: SecurityLevel.LOCAL_ONLY
  };
}

/** Creates a default StatusRecord. */
export function createStatusRecord(): StatusRecord {
  return {
    id: newId('st'),
    date: '',
    sleepHours: 0,
    exerciseCount: 0,
    alertCount: 0,
    note: '',
    level: SecurityLevel.LOCAL_ONLY
  };
}

/** Creates a default ReviewResult. */
export function createReviewResult(): ReviewResult {
  return {
    id: newId('rv'),
    period: ReviewPeriod.WEEK,
    rangeLabel: '',
    facts: '',
    interpretation: '',
    contradiction: '',
    action: '',
    anchorIds: [],
    level: SecurityLevel.LOCAL_ONLY,
    createdAt: Date.now()
  };
}
