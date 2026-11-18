/** Keys of the five persistent main tabs; the order is fixed and never user-editable. */
export enum TabKey {
  WORKBENCH = 'workbench',
  LOGS = 'logs',
  PREDICTION = 'prediction',
  DRAWER = 'drawer',
  MINE = 'mine'
}

/** One bottom-bar entry: label, symbol glyph name and the page-background group it follows. */
export interface TabItem {
  key: TabKey;
  label: string;
  /** System symbol name without the `sys.symbol.` prefix; the shell resolves it to a Resource. */
  iconName: string;
  /** Existing page-background group key owned by PageBackgroundService. */
  backgroundKey: string;
}

/** The five main tabs in their fixed order. */
export const TAB_ITEMS: TabItem[] = [
  { key: TabKey.WORKBENCH, label: '工作台', iconName: 'house', backgroundKey: 'home' },
  { key: TabKey.LOGS, label: '日志', iconName: 'calendar', backgroundKey: 'note' },
  { key: TabKey.PREDICTION, label: '预测', iconName: 'scope', backgroundKey: 'prediction' },
  { key: TabKey.DRAWER, label: '抽屉', iconName: 'diagnostic_analytics', backgroundKey: 'home' },
  { key: TabKey.MINE, label: '我的', iconName: 'person_2', backgroundKey: 'settings' }
];

/** Index of a tab key; unknown keys fall back to the workbench. */
export function tabIndex(key: TabKey): number {
  for (let index = 0; index < TAB_ITEMS.length; index += 1) {
    if (TAB_ITEMS[index].key === key) {
      return index;
    }
  }
  return 0;
}

/** Tab key at a position; out-of-range indexes fall back to the workbench. */
export function tabKeyAt(index: number): TabKey {
  if (index < 0 || index >= TAB_ITEMS.length) {
    return TabKey.WORKBENCH;
  }
  return TAB_ITEMS[index].key;
}

/** Tab item at a position; out-of-range indexes fall back to the workbench. */
export function tabItemAt(index: number): TabItem {
  if (index < 0 || index >= TAB_ITEMS.length) {
    return TAB_ITEMS[0];
  }
  return TAB_ITEMS[index];
}

/** Page-background group key of one tab. */
export function tabBackgroundKey(key: TabKey): string {
  return tabItemAt(tabIndex(key)).backgroundKey;
}