import { SecurityLevel } from '../model/SecurityLevel';

/** Row model rendered by the note list. */
export interface NoteListItem {
  id: string;
  title: string;
  /** Single-line preview of the stored content */
  summary: string;
  /** Event type, matching the template label or the free-form type */
  type: string;
  tags: string[];
  level: SecurityLevel;
  timestamp: number;
  /** Short display time: HH:mm for today, MM-DD HH:mm otherwise */
  timeLabel: string;
}
