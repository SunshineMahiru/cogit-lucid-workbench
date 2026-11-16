import { Anchor } from '../model/Anchor';
import { CostNote } from '../model/CostNote';
import { Decision } from '../model/Decision';
import { DecisionRecord } from '../model/DecisionRecord';
import { Event } from '../model/Event';
import { EvidenceItem } from '../model/EvidenceItem';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { InteractionLog, Relation } from '../model/Relation';
import { Prediction } from '../model/Prediction';
import { ReviewResult } from '../model/ReviewResult';
import { SecurityLevel } from '../model/SecurityLevel';
import { StatusRecord } from '../model/StatusRecord';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { visibleInExport, isOtherStatement } from '../relation/InteractionSource';
import * as DeletionPolicy from '../policy/DeletionPolicy';
import { ExportBundle } from './ExportBundle';
import { ExportOptions } from './ExportOptions';
import { PlanExport } from './PlanExport';

/** Sealed records never leave the device, so exports drop them. */
export function isExportable(level: SecurityLevel): boolean {
  return DeletionPolicy.isExportable({ deleted: false, level: level });
}

/** Options kept for callers that export every level except sealed records. */
export function allExportOptions(): ExportOptions {
  return {
    includeLocalOnly: true,
    includeOtherStatements: false,
    includeDemoRecords: true,
    includeHistory: false
  };
}

/** Drops sealed records and orders every section for reading. */
export function prepareExportBundle(bundle: ExportBundle,
  options: ExportOptions = allExportOptions()): ExportBundle {
  const sealedKeys = collectSealedKeys(bundle);
  const events = prepareEvents(bundle.events, options);
  const reviews = prepareReviews(bundle.reviews, options);
  const reviewIds = reviews.map((review) => review.id);
  return {
    events: events,
    decisions: prepareDecisions(bundle.decisions, options),
    relations: prepareRelations(bundle.relations, options),
    predictions: preparePredictions(bundle.predictions, options),
    anchors: prepareAnchors(bundle.anchors, options),
    statusRecords: prepareStatusRecords(bundle.statusRecords, options),
    reviews: reviews,
    evidenceItems: prepareEvidence(bundle.evidenceItems ?? [], reviewIds, options),
    costNotes: prepareCosts(bundle.costNotes ?? [], reviewIds),
    materials: prepareMaterials(bundle.materials ?? [], events, options),
    plans: preparePlans(bundle.plans ?? [], sealedKeys, options),
    decisionRecords: prepareDecisionRecords(bundle.decisionRecords ?? [], options),
    exportedAt: bundle.exportedAt
  };
}

/** Reports whether a record at this level is written under the chosen options. */
function keepLevel(level: SecurityLevel, options: ExportOptions, deleted: boolean = false): boolean {
  if (!DeletionPolicy.isExportable({ deleted: deleted, level: level })) {
    return false;
  }
  if (level === SecurityLevel.LOCAL_ONLY) {
    return options.includeLocalOnly;
  }
  return true;
}

/** Synthetic demo rows carry a "demo" id segment; they are written only on request. */
function keepRecord(id: string, options: ExportOptions): boolean {
  if (options.includeDemoRecords) {
    return true;
  }
  return id.indexOf('demo') < 0;
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

function prepareEvents(events: Event[], options: ExportOptions): Event[] {
  const items: Event[] = [];
  for (const event of events) {
    if (keepLevel(event.level, options, event.deleted ?? false) && keepRecord(event.id, options)) {
      items.push(event);
    }
  }
  items.sort((left, right) => right.timestamp - left.timestamp);
  return items;
}

/** Keeps the materials of events that survive the options; sealed and deleted rows stay out. */
function prepareMaterials(materials: ExperienceMaterial[], events: Event[],
  options: ExportOptions): ExperienceMaterial[] {
  const eventIds: string[] = [];
  for (const event of events) {
    eventIds.push(event.id);
  }
  const items: ExperienceMaterial[] = [];
  for (const material of materials) {
    if (!eventIds.includes(material.eventId)) {
      continue;
    }
    if (!keepLevel(material.level, options, material.deleted) || !keepRecord(material.id, options)) {
      continue;
    }
    items.push(material);
  }
  return items;
}

function prepareDecisions(decisions: Decision[], options: ExportOptions): Decision[] {
  const items: Decision[] = [];
  for (const decision of decisions) {
    if (keepLevel(decision.level, options) && keepRecord(decision.id, options)) {
      items.push(decision);
    }
  }
  items.sort((left, right) => right.timestamp - left.timestamp);
  return items;
}

function prepareRelations(relations: Relation[], options: ExportOptions): Relation[] {
  const items: Relation[] = [];
  for (const relation of relations) {
    if (keepLevel(relation.level, options, relation.deleted ?? false) && keepRecord(relation.id, options)) {
      const logs: InteractionLog[] = [];
      for (const log of relation.interactionLog) {
        const other = isOtherStatement(log);
        if (other && !(options.includeOtherStatements && visibleInExport(log))) {
          logs.push({
            timestamp: log.timestamp,
            content: '（对方陈述仅保存在本机）',
            source: 'stated',
            citation: 'hidden',
            allowContext: false
          });
          continue;
        }
        const level = log.level ?? relation.level;
        if (level === SecurityLevel.SEALED) {
          continue;
        }
        if (level === SecurityLevel.LOCAL_ONLY && !options.includeLocalOnly) {
          logs.push({
            timestamp: log.timestamp,
            content: '（仅本地记录）',
            source: log.source ?? 'observation',
            citation: 'hidden',
            allowContext: false
          });
          continue;
        }
        logs.push(log);
      }
      items.push({
        id: relation.id,
        name: relation.name,
        trustLevel: relation.trustLevel,
        interactionLog: logs,
        rawMaterialTest: relation.rawMaterialTest,
        forbidAnalysis: relation.forbidAnalysis,
        correction: relation.correction ?? '',
        correctionAt: relation.correctionAt ?? 0,
        level: relation.level,
        notes: relation.notes
      });
    }
  }
  return items;
}

function preparePredictions(predictions: Prediction[], options: ExportOptions): Prediction[] {
  const items: Prediction[] = [];
  for (const prediction of predictions) {
    const level = prediction.level ?? SecurityLevel.LOCAL_ONLY;
    if (keepLevel(level, options) && keepRecord(prediction.id, options)) {
      items.push(prediction);
    }
  }
  items.sort((left, right) => right.createdAt - left.createdAt);
  return items;
}

function prepareAnchors(anchors: Anchor[], options: ExportOptions): Anchor[] {
  const items: Anchor[] = [];
  for (const anchor of anchors) {
    const level = anchor.level ?? SecurityLevel.LOCAL_ONLY;
    if (keepLevel(level, options) && keepRecord(anchor.id, options)) {
      items.push(anchor);
    }
  }
  items.sort((left, right) => left.order - right.order);
  return items;
}

function prepareStatusRecords(records: StatusRecord[], options: ExportOptions): StatusRecord[] {
  const items: StatusRecord[] = [];
  for (const record of records) {
    const level = record.level ?? SecurityLevel.LOCAL_ONLY;
    if (keepLevel(level, options, record.deleted ?? false) && keepRecord(record.id, options)) {
      items.push(record);
    }
  }
  items.sort((left, right) => compareDateDesc(left.date, right.date));
  return items;
}

function prepareReviews(reviews: ReviewResult[], options: ExportOptions): ReviewResult[] {
  const items: ReviewResult[] = [];
  for (const review of reviews) {
    const level = review.level ?? SecurityLevel.LOCAL_ONLY;
    if (keepLevel(level, options) && keepRecord(review.id, options)) {
      items.push(review);
    }
  }
  items.sort((left, right) => right.createdAt - left.createdAt);
  return items;
}

/** Keeps evidence attached to exported reviews and at an exportable level. */
function prepareEvidence(items: EvidenceItem[], reviewIds: string[], options: ExportOptions): EvidenceItem[] {
  return items.filter((item: EvidenceItem) => item.targetType === 'review' &&
    reviewIds.includes(item.targetId) && keepLevel(item.level ?? SecurityLevel.LOCAL_ONLY, options));
}

/** Costs follow the review they belong to; a cost has no level of its own. */
function prepareCosts(notes: CostNote[], reviewIds: string[]): CostNote[] {
  return notes.filter((note: CostNote) => reviewIds.includes(note.reviewId));
}

/** Drops sealed decisions; the rest keep the reviewing order. */
function prepareDecisionRecords(records: DecisionRecord[], options: ExportOptions): DecisionRecord[] {
  const items: DecisionRecord[] = [];
  for (const record of records) {
    if (keepLevel(record.level, options)) {
      items.push(record);
    }
  }
  return items;
}

function preparePlans(plans: PlanExport[], sealedKeys: string[], options: ExportOptions): PlanExport[] {
  const rows: PlanExport[] = [];
  for (const entry of plans) {
    const level = entry.plan.level ?? SecurityLevel.LOCAL_ONLY;
    if (!keepLevel(level, options) || !keepRecord(entry.plan.id, options)) {
      continue;
    }
    const items: PlanItem[] = [];
    for (const item of entry.items) {
      const itemLevel = item.level ?? SecurityLevel.LOCAL_ONLY;
      if (keepLevel(itemLevel, options)) {
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
