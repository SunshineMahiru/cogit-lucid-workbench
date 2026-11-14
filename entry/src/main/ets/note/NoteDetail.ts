import { Event } from '../model/Event';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
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
  /** Typed materials kept with this note; empty when none were stored */
  materials?: ExperienceMaterial[];
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

/** Chinese label for one material kind. */
export function materialKindText(kind: string): string {
  if (kind === 'scene') {
    return '现场';
  }
  if (kind === 'feeling') {
    return '感受';
  }
  if (kind === 'body') {
    return '身体';
  }
  if (kind === 'existing_action') {
    return '已做';
  }
  if (kind === 'interpretation') {
    return '解释';
  }
  return '未分类';
}

/** Chinese label for where a material came from. */
export function materialSourceText(source: string): string {
  if (source === 'reading') {
    return '阅读';
  }
  if (source === 'exercise') {
    return '练习';
  }
  if (source === 'interaction') {
    return '互动';
  }
  if (source === 'reflection') {
    return '反思';
  }
  if (source === 'external') {
    return '外部资料';
  }
  return '直接经历';
}

/** Chinese label for the genre a material was written in. */
export function materialFormText(form: string): string {
  if (form === 'dialogue') {
    return '对话';
  }
  if (form === 'third_person') {
    return '第三人称';
  }
  if (form === 'poem') {
    return '诗';
  }
  if (form === 'reading_note') {
    return '读书笔记';
  }
  if (form === 'public_claim') {
    return '公开说法';
  }
  return '未标注';
}
