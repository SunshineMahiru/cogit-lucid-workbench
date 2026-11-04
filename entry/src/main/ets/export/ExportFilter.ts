import { Anchor } from '../model/Anchor';
import { Decision } from '../model/Decision';
import { Event } from '../model/Event';
import { Prediction } from '../model/Prediction';
import { Relation } from '../model/Relation';
import { ReviewResult } from '../model/ReviewResult';
import { SecurityLevel } from '../model/SecurityLevel';
import { StatusRecord } from '../model/StatusRecord';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { ExportBundle } from './ExportBundle';
import { PlanExport } from './PlanExport';

/** Sealed records never leave the device, so exports drop them. */
export function isExportable(level: SecurityLevel): boolean {
  return level !== SecurityLevel.SEALED;
}

/** Drops sealed records and orders every section for reading. */
export function prepareExportBundle(bundle: ExportBundle): ExportBundle {
  const sealedKeys = collectSealedKeys(bundle);
  return {
    events: prepareEvents(bundle.events),
    decisions: prepareDecisions(bundle.decisions),
    relations: prepareRelations(bundle.relations),
    predictions: preparePredictions(bundle.predictions),
    anchors: prepareAnchors(bundle.anchors),
    statusRecords: prepareStatusRecords(bundle.statusRecords),
    reviews: prepareReviews(bundle.reviews),
    plans: preparePlans(bundle.plans ?? [], sealedKeys),
    exportedAt: bundle.exportedAt
  };
}

/** 记录被封存的六模块目标，导出时只用占位文字代替它们的标题。 */
function collectSealedKeys(bundle: ExportBundle): string[] {
  const keys: string[] = [];
  for (const event of bundle.events) {
    if (!isExportable(event.level)) {
      keys.push(`${PlanLinkModule.NOTE}:${event.id}`);
    }
  }
  for (const prediction of bundle.predictions) {
    if (!isExportable(prediction.level ?? SecurityLevel.LOCAL_ONLY)) {
      keys.push(`${PlanLinkModule.PREDICTION}:${prediction.id}`);
    }
  }
  for (const review of bundle.reviews) {
    if (!isExportable(review.level ?? SecurityLevel.LOCAL_ONLY)) {
      keys.push(`${PlanLinkModule.REVIEW}:${review.id}`);
    }
  }
  for (const anchor of bundle.anchors) {
    if (!isExportable(anchor.level ?? SecurityLevel.LOCAL_ONLY)) {
      keys.push(`${PlanLinkModule.ANCHOR}:${anchor.id}`);
    }
  }
  for (const relation of bundle.relations) {
    if (!isExportable(relation.level)) {
      keys.push(`${PlanLinkModule.RELATION}:${relation.id}`);
    }
  }
  for (const record of bundle.statusRecords) {
    if (!isExportable(record.level ?? SecurityLevel.LOCAL_ONLY)) {
      keys.push(`${PlanLinkModule.STATUS}:${record.id}`);
    }
  }
  return keys;
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

function preparePlans(plans: PlanExport[], sealedKeys: string[]): PlanExport[] {
  const rows: PlanExport[] = [];
  for (const entry of plans) {
    if (!isExportable(entry.plan.level ?? SecurityLevel.LOCAL_ONLY)) {
      continue;
    }
    const items: PlanItem[] = [];
    for (const item of entry.items) {
      if (isExportable(item.level ?? SecurityLevel.LOCAL_ONLY)) {
        items.push(item);
      }
    }
    rows.push({ plan: entry.plan, nodes: entry.nodes, items: items, links: maskSealedLinks(entry.links, sealedKeys) });
  }
  rows.sort((left, right) => right.plan.createdAt - left.plan.createdAt);
  return rows;
}

/** 封存目标的关联只保留占位文字，避免标题随导出文件离开设备。 */
function maskSealedLinks(links: PlanLink[], sealedKeys: string[]): PlanLink[] {
  const rows: PlanLink[] = [];
  for (const link of links) {
    if (!sealedKeys.includes(`${link.module}:${link.targetId}`)) {
      rows.push(link);
      continue;
    }
    const masked: PlanLink = {
      id: link.id,
      planId: link.planId,
      module: link.module,
      targetId: link.targetId,
      label: '已封存记录',
      createdAt: link.createdAt
    };
    if (link.nodeId !== undefined) {
      masked.nodeId = link.nodeId;
    }
    rows.push(masked);
  }
  return rows;
}

function compareDateDesc(left: string, right: string): number {
  if (left === right) {
    return 0;
  }
  return left < right ? 1 : -1;
}
