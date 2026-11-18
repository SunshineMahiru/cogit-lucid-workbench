/**
 * Stable identifiers of the sortable workbench blocks. The persisted layout stores
 * these strings, so the values must not change once released.
 */
export enum HomeBlockKind {
  QUICK_CAPTURE = 'quick_capture',
  AGENDA = 'agenda',
  RECENT_NOTES = 'recent_notes',
  MODULE_STATUS = 'module_status',
  READINGS = 'readings',
  REVIEW_PROMPT = 'review_prompt'
}

/** Default block order; also the fallback whenever the stored layout is missing or corrupt. */
export const DEFAULT_HOME_BLOCK_ORDER: HomeBlockKind[] = [
  HomeBlockKind.QUICK_CAPTURE,
  HomeBlockKind.AGENDA,
  HomeBlockKind.RECENT_NOTES,
  HomeBlockKind.MODULE_STATUS,
  HomeBlockKind.READINGS,
  HomeBlockKind.REVIEW_PROMPT
];

/** Display title per block, used by the sort toolbar and the accessibility labels. */
export const HOME_BLOCK_TITLES: Record<string, string> = {
  'quick_capture': '快速速记',
  'agenda': '待处置',
  'recent_notes': '最近速记',
  'module_status': '模块状态',
  'readings': '身体读数',
  'review_prompt': '复盘提示'
};

/** Parses one stored identifier; returns null for unknown values. */
export function parseHomeBlockKind(value: string): HomeBlockKind | null {
  for (const kind of DEFAULT_HOME_BLOCK_ORDER) {
    if (kind === value) {
      return kind;
    }
  }
  return null;
}

/**
 * Turns stored identifiers into a usable order: unknown values are dropped, duplicates are
 * removed, and every block missing from the input is appended in the default order. An empty
 * input therefore produces the default order.
 */
export function normalizeBlockOrder(raw: string[]): HomeBlockKind[] {
  const result: HomeBlockKind[] = [];
  for (const value of raw) {
    const kind = parseHomeBlockKind(value.trim());
    if (kind === null || result.includes(kind)) {
      continue;
    }
    result.push(kind);
  }
  for (const kind of DEFAULT_HOME_BLOCK_ORDER) {
    if (!result.includes(kind)) {
      result.push(kind);
    }
  }
  return result;
}

/** Title of one block; unknown kinds fall back to the enum value. */
export function homeBlockTitle(kind: HomeBlockKind): string {
  const title: string | undefined = HOME_BLOCK_TITLES[kind];
  return title === undefined ? kind : title;
}