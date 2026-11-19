type BackHandler = () => boolean;

let handler: BackHandler | null = null;

/** Registers the single UI-level back handler; a later registration replaces the previous one. */
export function setBackHandler(next: BackHandler | null): void {
  handler = next;
}

/** Runs the registered handler; true means the UI consumed the back press. */
export function runBackHandler(): boolean {
  return handler === null ? false : handler();
}