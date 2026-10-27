import { InteractionLog, Relation } from '../model/Relation';
import { TrustLevel } from '../model/TrustLevel';
import { RelationDetail, RelationListItem } from './RelationListItem';

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
    notes: relation.notes
  };
}

/** Projects a batch: closer tiers first, then the most recently active. */
export function toRelationListItems(relations: Relation[]): RelationListItem[] {
  const items: RelationListItem[] = [];
  for (const relation of relations) {
    items.push(toRelationListItem(relation));
  }
  items.sort((left: RelationListItem, right: RelationListItem) => {
    const rankDiff = trustRank(right.trustLevel) - trustRank(left.trustLevel);
    if (rankDiff !== 0) {
      return rankDiff;
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
  const logs: InteractionLog[] = relation.interactionLog.slice();
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
    interactionLog: logs
  };
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

function trustRank(level: TrustLevel): number {
  if (level === TrustLevel.TRANSPARENT) {
    return 3;
  }
  if (level === TrustLevel.SINCERE) {
    return 2;
  }
  return 1;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
