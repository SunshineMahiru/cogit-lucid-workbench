import { InteractionLog, Relation } from '../model/Relation';
import { TrustLevel } from '../model/TrustLevel';
import { RelationDetail, RelationListItem } from './RelationListItem';
import { normalizeInteractionLog } from './InteractionSource';

/** Chinese label for a trust tier; unknown values fall back to 友好. */
export function trustLevelText(level: TrustLevel): string {
  if (level === TrustLevel.TRANSPARENT) {
    return '透明';
  }
  if (level === TrustLevel.SINCERE) {
    return '真诚';
  }
  return '友好';
}

/** Projects one relation into a list row. */
export function toRelationListItem(relation: Relation): RelationListItem {
  const latest = latestInteraction(relation.interactionLog);
  return {
    id: relation.id,
    name: relation.name,
    trustLevel: relation.trustLevel,
    interactionCount: relation.interactionLog.length,
    lastInteractionLabel: latest === null ? '暂无互动' : formatInteractionTime(latest.timestamp),
    lastInteractionAt: latest === null ? 0 : latest.timestamp,
    rawMaterialTest: relation.rawMaterialTest,
    forbidAnalysis: relation.forbidAnalysis,
    level: relation.level,
    notes: relation.notes,
    correction: relation.correction ?? '',
    correctionAt: relation.correctionAt ?? 0,
    pendingCorrections: pendingCorrectionsOf(relation),
    latestCorrectionExcerpt: correctionExcerptOf(relation)
  };
}

/** Projects a batch: unanswered corrections first, then the freshest correction and interaction. */
export function toRelationListItems(relations: Relation[]): RelationListItem[] {
  const items: RelationListItem[] = [];
  for (const relation of relations) {
    items.push(toRelationListItem(relation));
  }
  items.sort((left: RelationListItem, right: RelationListItem) => {
    const pendingDiff = (right.pendingCorrections ?? 0) - (left.pendingCorrections ?? 0);
    if (pendingDiff !== 0) {
      return pendingDiff;
    }
    const correctionDiff = (right.correctionAt ?? 0) - (left.correctionAt ?? 0);
    if (correctionDiff !== 0) {
      return correctionDiff;
    }
    return right.lastInteractionAt - left.lastInteractionAt;
  });
  return items;
}

/** Filters rows by tier; null keeps every row. */
export function filterRelationItems(items: RelationListItem[], level: TrustLevel | null): RelationListItem[] {
  if (level === null) {
    return items;
  }
  const filtered: RelationListItem[] = [];
  for (const item of items) {
    if (item.trustLevel === level) {
      filtered.push(item);
    }
  }
  return filtered;
}

/** Projects one relation into the detail model, newest interaction first. */
export function toRelationDetail(relation: Relation): RelationDetail {
  const logs: InteractionLog[] = [];
  for (const log of relation.interactionLog) {
    logs.push(normalizeInteractionLog(log));
  }
  logs.sort((left: InteractionLog, right: InteractionLog) => right.timestamp - left.timestamp);
  return {
    id: relation.id,
    name: relation.name,
    trustLevel: relation.trustLevel,
    interactionCount: relation.interactionLog.length,
    lastInteractionLabel: logs.length === 0 ? '暂无互动' : formatInteractionTime(logs[0].timestamp),
    lastInteractionAt: logs.length === 0 ? 0 : logs[0].timestamp,
    rawMaterialTest: relation.rawMaterialTest,
    forbidAnalysis: relation.forbidAnalysis,
    level: relation.level,
    notes: relation.notes,
    interactionLog: logs,
    correction: relation.correction ?? '',
    correctionAt: relation.correctionAt ?? 0,
    pendingCorrections: pendingCorrectionsOf(relation),
    latestCorrectionExcerpt: correctionExcerptOf(relation),
    linkedEvents: [],
    linkedDecisions: [],
    linkedRecords: []
  };
}

/** Trims a correction and keeps it within 40 characters for the list row. */
function correctionExcerptOf(relation: Relation): string {
  const text = (relation.correction ?? '').trim();
  return text.length <= 40 ? text : text.substring(0, 40);
}

/** A correction stays pending until the author logs an own observation after it. */
function pendingCorrectionsOf(relation: Relation): number {
  const correction = (relation.correction ?? '').trim();
  if (correction.length === 0) {
    return 0;
  }
  const correctionAt = relation.correctionAt ?? 0;
  for (const log of relation.interactionLog) {
    if (log.timestamp > correctionAt && (log.source ?? 'observation') === 'observation') {
      return 0;
    }
  }
  return 1;
}

/** Formats a log timestamp as YYYY-MM-DD HH:mm. */
export function formatInteractionTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ` +
    `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

function latestInteraction(logs: InteractionLog[]): InteractionLog | null {
  let latest: InteractionLog | null = null;
  for (const log of logs) {
    if (latest === null || log.timestamp > latest.timestamp) {
      latest = log;
    }
  }
  return latest;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
