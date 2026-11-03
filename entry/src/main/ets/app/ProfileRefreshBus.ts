import { Profile } from '../profile/ProfileStore';

type ProfileListener = (profile?: Profile) => void;

const listeners: ProfileListener[] = [];

/** Registers the identity band reload callback; duplicate registrations are ignored. */
export function subscribeProfileRefresh(listener: ProfileListener): void {
  if (!listeners.includes(listener)) {
    listeners.push(listener);
  }
}

/** Removes one identity band reload callback. */
export function unsubscribeProfileRefresh(listener: ProfileListener): void {
  const index = listeners.indexOf(listener);
  if (index >= 0) {
    listeners.splice(index, 1);
  }
}

/** Carries the saved profile so the band can update before the pop animation starts. */
export function notifyProfileRefresh(profile?: Profile): void {
  for (const listener of listeners.slice()) {
    listener(profile);
  }
}
