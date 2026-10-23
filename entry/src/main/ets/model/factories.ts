import { SecurityLevel } from './SecurityLevel';
import { TrustLevel } from './TrustLevel';
import { Event } from './Event';
import { Decision } from './Decision';
import { Relation } from './Relation';
import { Prediction } from './Prediction';
import { PredictionStatus } from './PredictionStatus';
import { Anchor } from './Anchor';
import { StatusRecord } from './StatusRecord';

let seq = 0;

function newId(prefix: string): string {
  seq += 1;
  return `${prefix}_${Date.now()}_${seq}`;
}

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
    createdAt: Date.now()
  };
}

export function createAnchor(): Anchor {
  return {
    id: newId('an'),
    text: '',
    source: '',
    order: 0
  };
}

export function createStatusRecord(): StatusRecord {
  return {
    id: newId('st'),
    date: '',
    sleepHours: 0,
    exerciseCount: 0,
    alertCount: 0,
    note: ''
  };
}
