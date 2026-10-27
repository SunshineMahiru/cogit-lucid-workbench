import { Anchor } from '../model/Anchor';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { Prediction } from '../model/Prediction';
import { Relation } from '../model/Relation';
import { StatusRecord } from '../model/StatusRecord';

/** All records collected for one Markdown export. */
export interface ExportBundle {
  events: Event[];
  decisions: Decision[];
  relations: Relation[];
  predictions: Prediction[];
  anchors: Anchor[];
  statusRecords: StatusRecord[];
  /** Export time in milliseconds */
  exportedAt: number;
}

/** Row counts shown in the document header. */
export interface ExportCounts {
  events: number;
  decisions: number;
  relations: number;
  predictions: number;
  anchors: number;
  statusRecords: number;
}

/** Counts every section of the bundle. */
export function countExportBundle(bundle: ExportBundle): ExportCounts {
  return {
    events: bundle.events.length,
    decisions: bundle.decisions.length,
    relations: bundle.relations.length,
    predictions: bundle.predictions.length,
    anchors: bundle.anchors.length,
    statusRecords: bundle.statusRecords.length
  };
}

/** Sums the counts into the number shown as the record total. */
export function totalExportRecords(counts: ExportCounts): number {
  return counts.events + counts.decisions + counts.relations + counts.predictions + counts.anchors +
    counts.statusRecords;
}
