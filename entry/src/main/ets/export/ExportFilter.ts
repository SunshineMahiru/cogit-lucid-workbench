import { Anchor } from '../model/Anchor';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { Prediction } from '../model/Prediction';
import { Relation } from '../model/Relation';
import { ReviewResult } from '../model/ReviewResult';
import { SecurityLevel } from '../model/SecurityLevel';
import { StatusRecord } from '../model/StatusRecord';
import { ExportBundle } from './ExportBundle';

/** Sealed records never leave the device, so exports drop them. */
export function isExportable(level: SecurityLevel): boolean {
  return level !== SecurityLevel.SEALED;
}

/** Drops sealed records and orders every section for reading. */
export function prepareExportBundle(bundle: ExportBundle): ExportBundle {
  return {
    events: prepareEvents(bundle.events),
    decisions: prepareDecisions(bundle.decisions),
    relations: prepareRelations(bundle.relations),
    predictions: preparePredictions(bundle.predictions),
    anchors: prepareAnchors(bundle.anchors),
    statusRecords: prepareStatusRecords(bundle.statusRecords),
    reviews: prepareReviews(bundle.reviews),
    exportedAt: bundle.exportedAt
  };
}

function prepareEvents(events: Event[]): Event[] {
  const items: Event[] = [];
  for (const event of events) {
    if (isExportable(event.level)) {
      items.push(event);
    }
  }
  items.sort((left, right) => right.timestamp - left.timestamp);
  return items;
}

function prepareDecisions(decisions: Decision[]): Decision[] {
  const items: Decision[] = [];
  for (const decision of decisions) {
    if (isExportable(decision.level)) {
      items.push(decision);
    }
  }
  items.sort((left, right) => right.timestamp - left.timestamp);
  return items;
}

function prepareRelations(relations: Relation[]): Relation[] {
  const items: Relation[] = [];
  for (const relation of relations) {
    if (isExportable(relation.level)) {
      items.push(relation);
    }
  }
  return items;
}

function preparePredictions(predictions: Prediction[]): Prediction[] {
  const items: Prediction[] = [];
  for (const prediction of predictions) {
    if (isExportable(prediction.level ?? SecurityLevel.LOCAL_ONLY)) {
      items.push(prediction);
    }
  }
  items.sort((left, right) => right.createdAt - left.createdAt);
  return items;
}

function prepareAnchors(anchors: Anchor[]): Anchor[] {
  const items: Anchor[] = [];
  for (const anchor of anchors) {
    if (isExportable(anchor.level ?? SecurityLevel.LOCAL_ONLY)) {
      items.push(anchor);
    }
  }
  items.sort((left, right) => left.order - right.order);
  return items;
}

function prepareStatusRecords(records: StatusRecord[]): StatusRecord[] {
  const items: StatusRecord[] = [];
  for (const record of records) {
    if (isExportable(record.level ?? SecurityLevel.LOCAL_ONLY)) {
      items.push(record);
    }
  }
  items.sort((left, right) => compareDateDesc(left.date, right.date));
  return items;
}

function prepareReviews(reviews: ReviewResult[]): ReviewResult[] {
  const items: ReviewResult[] = [];
  for (const review of reviews) {
    if (isExportable(review.level ?? SecurityLevel.LOCAL_ONLY)) {
      items.push(review);
    }
  }
  items.sort((left, right) => right.createdAt - left.createdAt);
  return items;
}

function compareDateDesc(left: string, right: string): number {
  if (left === right) {
    return 0;
  }
  return left < right ? 1 : -1;
}
