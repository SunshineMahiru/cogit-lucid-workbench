import { CitationScope, InteractionLog, InteractionSource } from '../model/Relation';
import { EvidenceDraft, EvidenceEffect, EvidenceSource } from '../model/EvidenceItem';
import { ReviewPayload } from '../model/ReviewPayload';

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
    evidenceDrafts: readEvidenceDrafts(entry.evidenceDrafts)
  };
}
