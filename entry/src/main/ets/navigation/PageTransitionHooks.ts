/** Per-destination animation hooks keyed by NavDestinationContext.navDestinationId. */
export interface PageTransitionHooks {
  enterStart: () => void;
  enterEnd: () => void;
  exitStart: () => void;
  exitEnd: () => void;
}

const hooks: Map<string, PageTransitionHooks> = new Map();

export function registerPageTransition(id: string, value: PageTransitionHooks): void {
  if (id.length === 0) {
    return;
  }
  hooks.set(id, value);
}

export function unregisterPageTransition(id: string): void {
  hooks.delete(id);
}

export function pageTransitionOf(id: string | undefined): PageTransitionHooks | undefined {
  if (id === undefined || id.length === 0) {
    return undefined;
  }
  return hooks.get(id);
}
