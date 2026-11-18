import { BodyReading, HomeSummary } from './HomeModel';
import { NoteListItem } from '../note/NoteListItem';
import { AgendaItem } from '../home/AgendaMapper';

/**
 * One read of everything the workbench and the drawer show. Built by HomeSnapshotService so the
 * two views share a single counting pass instead of querying the database twice.
 */
export interface HomeSnapshot {
  /** Sleep, exercise and note count; a missing record keeps the placeholder value */
  readings: BodyReading[];
  /** Newest notes, one row per revision chain */
  recentNotes: NoteListItem[];
  /** Existing home summary; field shapes stay unchanged */
  summary: HomeSummary;
  /** Today's actionable rows */
  agenda: AgendaItem[];
  /** Plan items, pending predictions and open hypotheses */
  agendaPending: number;
  /** Corrections that still have no own response */
  agendaReply: number;
  /** Open plan nodes across active plans */
  planOpenCount: number;
  /** Every node of the active plans */
  planNodeCount: number;
  /** True when at least one source failed; the view keeps what it got and offers a retry */
  partial: boolean;
}