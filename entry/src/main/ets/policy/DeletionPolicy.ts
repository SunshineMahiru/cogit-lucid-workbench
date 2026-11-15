import { SecurityLevel } from '../model/SecurityLevel';

/** Minimal state needed to decide visibility, export and citation. */
export interface RecordState {
  deleted: boolean;
  level: SecurityLevel;
}

/** True while the row still represents a record the user has not deleted. */
export function isLive(state: RecordState): boolean {
  return !state.deleted;
}

/** True when a live row may leave the device through export or backup. */
export function isExportable(state: RecordState): boolean {
  return isLive(state) && state.level !== SecurityLevel.SEALED;
}

/** True when a live, non-sealed row may be quoted; a missing source cannot be cited. */
export function isCitable(state: RecordState, snapshotMissing: boolean = false): boolean {
  return isExportable(state) && !snapshotMissing;
}