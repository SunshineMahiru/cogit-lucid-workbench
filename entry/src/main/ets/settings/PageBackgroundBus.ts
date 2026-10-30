type BackgroundListener = () => void;

const listeners: BackgroundListener[] = [];

let pageIsEmpty: boolean = false;

/** Pages without content report it, so the shared layer can step back and stay out of the way. */
export function setPageEmpty(value: boolean): void {
  if (pageIsEmpty === value) {
    return;
  }
  pageIsEmpty = value;
  notifyPageBackgroundChanged();
}

export function isPageEmpty(): boolean {
  return pageIsEmpty;
}

/** Subscribes a page background to local image changes. */
export function subscribePageBackground(listener: BackgroundListener): void {
  if (!listeners.includes(listener)) {
    listeners.push(listener);
  }
}

/** Removes one background listener. */
export function unsubscribePageBackground(listener: BackgroundListener): void {
  const next: BackgroundListener[] = [];
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

/** Notifies open pages after a background is selected or cleared. */
export function notifyPageBackgroundChanged(): void {
  for (const listener of listeners.slice()) {
    listener();
  }
}
