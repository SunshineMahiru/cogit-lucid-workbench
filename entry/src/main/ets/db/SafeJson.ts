import { toCostDimension, CostDraft } from '../model/CostNote';
import { DECISION_RECORD_TYPES, DecisionDraft, DecisionRecordType } from '../model/DecisionRecord';
import { CitationScope, InteractionLog, InteractionSource } from '../model/Relation';
import { EvidenceDraft, EvidenceEffect, EvidenceSource } from '../model/EvidenceItem';
import { AnchorCitation, MotivationKind, MOTIVATION_KINDS, ReviewPayload } from '../model/ReviewPayload';
import { WorkDepth } from '../model/WorkDepth';

/** 整个进程累计的字段解析异常次数，供首页提示使用。 */
let issueCount: number = 0;

/** 读取累计次数并清零。 */
export function consumeJsonIssues(): number {
  const total = issueCount;
  issueCount = 0;
  return total;
}

/** 读取 JSON 文本；空文本视为空列，损坏时记一次异常并返回 null。 */
function readJson(raw: string): Object | null {
  if (raw.trim().length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as Object;
  } catch (error) {
    issueCount += 1;
    return null;
  }
}

/** 读取字符串数组列；非数组、元素类型不符时跳过坏数据。 */
export function parseStringArray(raw: string): string[] {
  const value = readJson(raw);
  if (value === null) {
    return [];
  }
  if (!Array.isArray(value)) {
    issueCount += 1;
    return [];
  }
  const items: Object[] = value as Object[];
  const result: string[] = [];
  for (const item of items) {
    if (typeof item === 'string') {
      result.push(item);
    } else {
      issueCount += 1;
    }
  }
  return result;
}

/** 读取互动记录列；单条记录字段缺失时只跳过该条。 */
export function parseInteractionLog(raw: string): InteractionLog[] {
  const value = readJson(raw);
  if (value === null) {
    return [];
  }
  if (!Array.isArray(value)) {
    issueCount += 1;
    return [];
  }
  const items: Object[] = value as Object[];
  const result: InteractionLog[] = [];
  for (const item of items) {
    const entry = item as Record<string, Object>;
    const timestamp = entry.timestamp;
    const content = entry.content;
    if (typeof timestamp === 'number' && typeof content === 'string') {
      const log: InteractionLog = { timestamp: timestamp, content: content };
      const source = entry.source;
      const citation = entry.citation;
      const allowContext = entry.allowContext;
      if (typeof source === 'string') {
        log.source = source as InteractionSource;
      }
      if (typeof citation === 'string') {
        log.citation = citation as CitationScope;
      }
      if (typeof allowContext === 'boolean') {
        log.allowContext = allowContext;
      }
      result.push(log);
    } else {
      issueCount += 1;
    }
  }
  return result;
}

/** Reads an optional string array field; a non-array or any non-string element falls back to []. */
function readStringFieldList(value: Object | undefined): string[] {
  if (!Array.isArray(value)) {
    if (value !== undefined) {
      issueCount += 1;
    }
    return [];
  }
  const items: Object[] = value as Object[];
  const result: string[] = [];
  for (const item of items) {
    if (typeof item !== 'string') {
      issueCount += 1;
      return [];
    }
    result.push(item as string);
  }
  return result;
}

/** Drops repeated ids, keeping each id at its first position. */
export function uniqueStrings(items: string[]): string[] {
  const seen: Set<string> = new Set<string>();
  const result: string[] = [];
  for (const item of items) {
    if (!seen.has(item)) {
      seen.add(item);
      result.push(item);
    }
  }
  return result;
}

/** Reads the evidence drafts of a payload; a malformed entry is skipped and counted. */
function readEvidenceDrafts(value: Object | undefined): EvidenceDraft[] {
  if (!Array.isArray(value)) {
    if (value !== undefined) {
      issueCount += 1;
    }
    return [];
  }
  const items: Object[] = value as Object[];
  const result: EvidenceDraft[] = [];
  for (const item of items) {
    const entry = item as Record<string, Object>;
    const sourceType = entry.sourceType;
    const note = entry.note;
    const effect = entry.effect;
    if (typeof sourceType === 'string' && typeof note === 'string' && typeof effect === 'string') {
      const draft: EvidenceDraft = {
        sourceType: sourceType as EvidenceSource,
        note: note,
        effect: effect as EvidenceEffect
      };
      result.push(draft);
    } else {
      issueCount += 1;
    }
  }
  return result;
}

/** Reads the cost drafts of a payload; a malformed entry is skipped and counted. */
function readCostDrafts(value: Object | undefined): CostDraft[] {
  if (!Array.isArray(value)) {
    if (value !== undefined) {
      issueCount += 1;
    }
    return [];
  }
  const items: Object[] = value as Object[];
  const result: CostDraft[] = [];
  for (const item of items) {
    const entry = item as Record<string, Object>;
    const dimension = entry.dimension;
    const text = entry.text;
    const bearable = entry.bearable;
    if (typeof dimension === 'string' && typeof text === 'string' && typeof bearable === 'boolean') {
      const draft: CostDraft = {
        dimension: toCostDimension(dimension),
        text: text,
        bearable: bearable
      };
      result.push(draft);
    } else {
      issueCount += 1;
    }
  }
  return result;
}

/** Reads an optional text field; absent or non-text values read as empty. */
function readOptionalText(value: Object | undefined): string {
  return typeof value === 'string' ? value as string : '';
}

/** Reads the main decision draft; a malformed entry is dropped and counted. */
function readDecisionDraft(value: Object | undefined): DecisionDraft | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value !== 'object') {
    issueCount += 1;
    return undefined;
  }
  const entry = value as Record<string, Object>;
  const type = entry.type;
  const reason = entry.reason;
  if (typeof type !== 'string' || DECISION_RECORD_TYPES.indexOf(type as DecisionRecordType) < 0 ||
    typeof reason !== 'string') {
    issueCount += 1;
    return undefined;
  }
  return {
    type: type as DecisionRecordType,
    reason: reason,
    action: readOptionalText(entry.action),
    commitment: readOptionalText(entry.commitment),
    relationId: readOptionalText(entry.relationId),
    planItemId: readOptionalText(entry.planItemId),
    outcome: readOptionalText(entry.outcome),
    reviewAt: readOptionalText(entry.reviewAt)
  };
}

/** Reads the motivation answer; an unknown value reads as not answered. */
function readMotivation(value: Object | undefined): MotivationKind | undefined {
  if (typeof value !== 'string' || MOTIVATION_KINDS.indexOf(value as MotivationKind) < 0) {
    return undefined;
  }
  return value as MotivationKind;
}

/** Reads anchor citations; entries without an id are dropped and repeated ids keep the first. */
function readAnchorCitations(value: Object | undefined): AnchorCitation[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const items: Object[] = value as Object[];
  const result: AnchorCitation[] = [];
  for (const item of items) {
    const entry = item as Record<string, Object>;
    const anchorId = entry.anchorId;
    if (typeof anchorId !== 'string' || anchorId.length === 0) {
      continue;
    }
    let duplicate = false;
    for (const existing of result) {
      if (existing.anchorId === anchorId) {
        duplicate = true;
        break;
      }
    }
    if (duplicate) {
      continue;
    }
    result.push({
      anchorId: anchorId,
      reason: typeof entry.reason === 'string' ? (entry.reason as string).trim() : ''
    });
  }
  return result;
}

/** Reads the work depth; absent or unknown reads as not recorded. */
function readWorkDepth(value: Object | undefined): WorkDepth | undefined {
  if (value === 'quick' || value === 'normal' || value === 'deep') {
    return value as WorkDepth;
  }
  return undefined;
}

/** Reads the optional time budget; non-positive or non-numeric reads as absent. */
function readTimeBudget(value: Object | undefined): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    return undefined;
  }
  return Math.round(value);
}

/** Reads the six-zone payload; returns undefined for old records without one. */
export function parseReviewPayload(raw: string): ReviewPayload | undefined {
  const value = readJson(raw);
  if (value === null) {
    return undefined;
  }
  const entry = value as Record<string, Object>;
  const readZone = (key: string): string => {
    const field = entry[key];
    return typeof field === 'string' ? field as string : '';
  };
  return {
    scene: readZone('scene'),
    model: readZone('model'),
    relation: readZone('relation'),
    evidence: readZone('evidence'),
    cost: readZone('cost'),
    revision: readZone('revision'),
    materialIds: readStringFieldList(entry.materialIds),
    decisionIds: uniqueStrings(readStringFieldList(entry.decisionIds)),
    evidenceDrafts: readEvidenceDrafts(entry.evidenceDrafts),
    costDrafts: readCostDrafts(entry.costDrafts),
    decisionDraft: readDecisionDraft(entry.decisionDraft),
    motivation: readMotivation(entry.motivation),
    depth: readWorkDepth(entry.depth),
    timeBudget: readTimeBudget(entry.timeBudget),
    anchorCitations: readAnchorCitations(entry.anchorCitations)
  };
}
