import { InteractionLog } from '../model/Relation';

/** 整个进程累计的字段解析异常次数，供首页提示使用。 */
let issueCount: number = 0;

/** 读取累计次数并清零。 */
export function consumeJsonIssues(): number {
  const total = issueCount;
  issueCount = 0;
  return total;
}

/** 读取 JSON 文本；损坏时记一次异常并返回 null。 */
function readJson(raw: string): Object | null {
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
      result.push({ timestamp: timestamp, content: content });
    } else {
      issueCount += 1;
    }
  }
  return result;
}
