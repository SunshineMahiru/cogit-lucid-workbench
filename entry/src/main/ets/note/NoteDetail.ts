import { Event } from '../model/Event';
import { SecurityLevel } from '../model/SecurityLevel';
import { formatNoteTime } from './NoteListMapper';

/** Read-only projection of one stored note. */
export interface NoteDetail {
  id: string;
  title: string;
  type: string;
  content: string;
  tags: string[];
  level: SecurityLevel;
  timestamp: number;
  /** Relations linked to the note, used when editing */
  relatedRelationIds: string[];
  timeLabel: string;
}

/** Projects an event into the detail view model. */
export function toNoteDetail(event: Event, now: number = Date.now()): NoteDetail {
  return {
    id: event.id,
    title: event.title,
    type: event.type,
    content: event.content,
    tags: event.tags.slice(),
    level: event.level,
    timestamp: event.timestamp,
    relatedRelationIds: event.relatedRelationIds.slice(),
    timeLabel: formatNoteTime(event.timestamp, now)
  };
}

/** Chinese label for the security level shown on the detail page. */
export function securityLevelText(level: SecurityLevel): string {
  if (level === SecurityLevel.ANALYZABLE) {
    return '可分析';
  }
  if (level === SecurityLevel.SEALED) {
    return '已封存';
  }
  return '仅本地';
}
