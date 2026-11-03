/** Lets the home identity band reload after the profile is changed elsewhere. */
const listeners: Array<() => void> = [];

export function subscribeProfileRefresh(listener: () => void): void {
  if (listeners.indexOf(listener) < 0) {
    listeners.push(listener);
  }
}

export function unsubscribeProfileRefresh(listener: () => void): void {
  const index = listeners.indexOf(listener);
  if (index >= 0) {
    listeners.splice(index, 1);
  }
}

export function notifyProfileRefresh(): void {
  for (const listener of listeners.slice()) {
    listener();
  }
}
