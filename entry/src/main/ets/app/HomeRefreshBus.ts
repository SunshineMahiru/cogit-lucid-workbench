type RefreshListener = () => void;

const listeners: RefreshListener[] = [];

/** Registers the dashboard refresh callback; duplicate registrations are ignored. */
export function subscribeHomeRefresh(listener: RefreshListener): void {
  if (!listeners.includes(listener)) {
    listeners.push(listener);
  }
}

/** Removes one dashboard refresh callback. */
export function unsubscribeHomeRefresh(listener: RefreshListener): void {
  const next: RefreshListener[] = [];
  for (const item of listeners) {
    if (item !== listener) {
      next.push(item);
    }
  }
  listeners.length = 0;
  for (const item of next) {
    listeners.push(item);
  }
}

/** Notifies the dashboard after a local record changes. */
export function notifyHomeRefresh(): void {
  for (const listener of listeners.slice()) {
    listener();
  }
}
