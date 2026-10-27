import { Event } from '../model/Event';
import { NoteListItem } from './NoteListItem';

/** Maximum length of the list summary. */
export const NOTE_SUMMARY_MAX_LENGTH = 48;

/** Projects a stored event into a list row. */
export function toNoteListItem(event: Event, now: number = Date.now()): NoteListItem {
  return {
    id: event.id,
    title: event.title,
    summary: summarize(event.content),
    type: event.type,
    tags: event.tags.slice(),
    level: event.level,
    timestamp: event.timestamp,
    timeLabel: formatNoteTime(event.timestamp, now)
  };
}

/** Projects a batch of stored events, newest first as returned by the query. */
export function toNoteListItems(events: Event[], now: number = Date.now()): NoteListItem[] {
  const items: NoteListItem[] = [];
  for (const event of events) {
    items.push(toNoteListItem(event, now));
  }
  return items;
}

/** Formats a capture time: HH:mm for today, MM-DD HH:mm for earlier days. */
export function formatNoteTime(timestamp: number, now: number = Date.now()): string {
  const date = new Date(timestamp);
  const today = new Date(now);
  const clock = `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
  const sameDay = date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() &&
    date.getDate() === today.getDate();
  return sameDay ? clock : `${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ${clock}`;
}

function summarize(content: string): string {
  const line = content.replace(/\s+/g, ' ').trim();
  return line.length > NOTE_SUMMARY_MAX_LENGTH ? `${line.slice(0, NOTE_SUMMARY_MAX_LENGTH)}…` : line;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}
