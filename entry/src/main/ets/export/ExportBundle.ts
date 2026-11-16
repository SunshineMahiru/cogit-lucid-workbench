import { Anchor } from '../model/Anchor';
import { CostNote } from '../model/CostNote';
import { Decision } from '../model/Decision';
import { DecisionRecord } from '../model/DecisionRecord';
import { Event } from '../model/Event';
import { EvidenceItem } from '../model/EvidenceItem';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { Prediction } from '../model/Prediction';
import { Relation } from '../model/Relation';
import { ReviewResult } from '../model/ReviewResult';
import { StatusRecord } from '../model/StatusRecord';
import { PlanExport } from './PlanExport';

/** All records collected for one Markdown export. */
export interface ExportBundle {
  events: Event[];
  decisions: Decision[];
  relations: Relation[];
  predictions: Prediction[];
  anchors: Anchor[];
  statusRecords: StatusRecord[];
  reviews: ReviewResult[];
  /** Evidence rows attached to reviews; each keeps its targetId */
  evidenceItems?: EvidenceItem[];
  /** Costs attached to reviews; each keeps its reviewId */
  costNotes?: CostNote[];
  /** Experience materials carried by the exported events; each keeps its eventId */
  materials?: ExperienceMaterial[];
  /** Optional plan section; absent in older callers */
  plans?: PlanExport[];
  /** Decisions written by review sessions; absent in older callers */
  decisionRecords?: DecisionRecord[];
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
  reviews: number;
  plans: number;
}

/** Counts every section of the bundle. */
export function countExportBundle(bundle: ExportBundle): ExportCounts {
  return {
    events: countEventRoots(bundle.events),
    decisions: bundle.decisions.length,
    relations: bundle.relations.length,
    predictions: bundle.predictions.length,
    anchors: bundle.anchors.length,
    statusRecords: bundle.statusRecords.length,
    reviews: bundle.reviews.length,
    plans: (bundle.plans ?? []).length
  };
}

/** Counts events by root note, so revision history adds no extra records. */
function countEventRoots(events: Event[]): number {
  const roots: string[] = [];
  for (const event of events) {
    const root = event.revisionOf !== undefined && event.revisionOf !== '' ? event.revisionOf : event.id;
    if (!roots.includes(root)) {
      roots.push(root);
    }
  }
  return roots.length;
}

/** Sums the counts into the number shown as the record total. */
export function totalExportRecords(counts: ExportCounts): number {
  return counts.events + counts.decisions + counts.relations + counts.predictions + counts.anchors +
    counts.statusRecords + counts.reviews + counts.plans;
}
