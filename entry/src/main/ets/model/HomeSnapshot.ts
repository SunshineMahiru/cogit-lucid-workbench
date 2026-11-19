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
  /** False when the summary read failed; callers show placeholders instead of zeroes */
  summaryAvailable: boolean;
  /** Today's actionable rows */
  agenda: AgendaItem[];
  /** Number of actionable rows, pending predictions and open hypotheses combined */
  agendaPending: number;
  /** Corrections that still have no own response */
  agendaReply: number;
  /** Open plan nodes across active plans */
  planOpenCount: number;
  /** Every node of the active plans */
  planNodeCount: number;
  /** False when plans, predictions or relations could not be read for the agenda */
  agendaAvailable: boolean;
  /** True when at least one source failed; the view keeps what it got and offers a retry */
  partial: boolean;
}