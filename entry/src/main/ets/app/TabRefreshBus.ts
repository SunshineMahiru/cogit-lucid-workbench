import { TabKey } from '../navigation/TabItems';

type TabRefreshListener = () => void;

const listeners: Map<string, TabRefreshListener[]> = new Map<string, TabRefreshListener[]>();

let activeTabKey: TabKey = TabKey.WORKBENCH;

/** Registers one listener for a tab; duplicate registrations are ignored. */
export function subscribeTabRefresh(key: TabKey, listener: TabRefreshListener): void {
  const current: TabRefreshListener[] = listeners.get(key) ?? [];
  if (!current.includes(listener)) {
    current.push(listener);
    listeners.set(key, current);
  }
}

/** Removes one listener from a tab; unknown listeners are ignored. */
export function unsubscribeTabRefresh(key: TabKey, listener: TabRefreshListener): void {
  const current: TabRefreshListener[] = listeners.get(key) ?? [];
  const next: TabRefreshListener[] = [];
  for (const item of current) {
    if (item !== listener) {
      next.push(item);
    }
  }
  listeners.set(key, next);
}

/** Notifies the listeners of one tab only; other tabs never see the call. */
export function requestTabRefresh(key: TabKey): void {
  for (const listener of (listeners.get(key) ?? []).slice()) {
    listener();
  }
}

/** Records which tab is on screen; the shell calls this on every tab switch. */
export function setActiveTab(key: TabKey): void {
  activeTabKey = key;
}

/** Key of the tab currently on screen. */
export function activeTab(): TabKey {
  return activeTabKey;
}

/** Re-notifies the current tab, used when a pushed page returns to the shell. */
export function requestActiveTabRefresh(): void {
  requestTabRefresh(activeTabKey);
}