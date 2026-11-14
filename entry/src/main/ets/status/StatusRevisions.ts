import { StatusRevision } from '../model/StatusRecord';
import { CapacityJudgment, toCapacityJudgment } from '../model/CapacityJudgment';

/** Parses the stored revision JSON, dropping entries that lack a numeric timestamp. */
export function parseStatusRevisions(text: string): StatusRevision[] {
  if (text.trim().length === 0) {
    return [];
  }
  let parsed: Object | null = null;
  try {
    parsed = JSON.parse(text) as Object;
  } catch (error) {
    return [];
  }
  if (!Array.isArray(parsed)) {
    return [];
  }
  const revisions: StatusRevision[] = [];
  for (const item of parsed as Object[]) {
    const entry = item as Record<string, Object>;
    const at = entry['at'];
    if (typeof at !== 'number') {
      continue;
    }
    const capacityText = entry['capacity'];
    revisions.push({
      at: at as number,
      sleepHours: toNumber(entry['sleepHours']),
      exerciseCount: toNumber(entry['exerciseCount']),
      alertCount: toNumber(entry['alertCount']),
      note: typeof entry['note'] === 'string' ? entry['note'] as string : '',
      capacity: toCapacityJudgment(typeof capacityText === 'string' ? capacityText as string : '')
    });
  }
  return revisions;
}

/** Serializes revision entries for storage. */
export function stringifyStatusRevisions(revisions: StatusRevision[]): string {
  return revisions.length === 0 ? '' : JSON.stringify(revisions);
}

/** Builds one revision entry from the values being replaced. */
export function statusRevisionOf(at: number, sleepHours: number, exerciseCount: number, alertCount: number,
  note: string, capacity: CapacityJudgment): StatusRevision {
  return {
    at: at,
    sleepHours: sleepHours,
    exerciseCount: exerciseCount,
    alertCount: alertCount,
    note: note,
    capacity: capacity
  };
}

function toNumber(value: Object | undefined): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value as number;
  }
  return 0;
}
