import { common } from '@kit.AbilityKit';
import { AnchorService } from '../anchor';
import { NoteListItem, QuickNoteService } from '../note';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { MOCK_STATUS_RECORDS } from '../model/mockData';
import { PredictionListItem, PredictionService } from '../prediction';
import { RelationListItem, RelationService } from '../relation';
import { ReviewHistoryItem, ReviewService } from '../review';
import { StatusDayRow, StatusService } from '../status';
import { previewStore } from '../preview/PreviewStore';
import {
  PREVIEW_ANCHORS,
  PREVIEW_NOTE_ITEMS,
  PREVIEW_PREDICTION_ITEMS,
  PREVIEW_RELATION_ITEMS
} from '../preview/PreviewData';
import { LinkCandidate } from './PlanLinkCandidate';

/** 选择器一次加载的上限；页面用关键词过滤并分页显示，历史记录仍可被找到。 */
const CANDIDATE_LIMIT = 200;

/** Loads candidate records from the six modules, or from preview data without a database. */
export async function loadPlanLinkCandidates(
  context: common.Context | undefined,
  weekStart: string,
  weekEnd: string
): Promise<LinkCandidate[]> {
  const items = context === undefined ? previewCandidates() : await databaseCandidates(context);
  return items;
}

function previewCandidates(): LinkCandidate[] {
  const items: LinkCandidate[] = [];
  for (const note of PREVIEW_NOTE_ITEMS) {
    items.push(candidate(PlanLinkModule.NOTE, note.id, note.title, note.type, note.timestamp, note.tags,
      note.relatedRelationIds ?? []));
  }
  for (const prediction of PREVIEW_PREDICTION_ITEMS) {
    items.push(candidate(PlanLinkModule.PREDICTION, prediction.id, prediction.target,
      `${prediction.confidence}% · ${prediction.status}`, prediction.createdAt, [prediction.status]));
  }
  for (const review of previewStore.reviewHistory()) {
    items.push(candidate(PlanLinkModule.REVIEW, review.id, `${review.periodLabel} ${review.rangeLabel}`,
      review.action, review.createdAt ?? 0, []));
  }
  for (const anchor of PREVIEW_ANCHORS) {
    items.push(candidate(PlanLinkModule.ANCHOR, anchor.id, anchor.text, anchor.source, 0, []));
  }
  for (const relation of PREVIEW_RELATION_ITEMS) {
    items.push(candidate(PlanLinkModule.RELATION, relation.id, relation.name,
      `${relation.trustLevel} · ${relation.interactionCount} 次互动`, relation.lastInteractionAt,
      [relation.trustLevel], [relation.id]));
  }
  for (const record of MOCK_STATUS_RECORDS.slice(0, 5)) {
    const timestamp = new Date(`${record.date}T00:00:00`).getTime();
    items.push(candidate(PlanLinkModule.STATUS, record.id, record.date,
      `睡眠 ${record.sleepHours} 小时`, timestamp, []));
  }
  return items;
}

async function databaseCandidates(context: common.Context): Promise<LinkCandidate[]> {
  const items: LinkCandidate[] = [];
  const noteService = await QuickNoteService.open(context);
  const notes: NoteListItem[] = await noteService.listRecentPage(CANDIDATE_LIMIT, 0);
  for (const note of notes) {
    items.push(candidate(PlanLinkModule.NOTE, note.id, note.title, note.type, note.timestamp, note.tags,
      note.relatedRelationIds ?? []));
  }

  const predictionService = await PredictionService.open(context);
  const predictions: PredictionListItem[] = await predictionService.list(null);
  for (const prediction of predictions) {
    items.push(candidate(PlanLinkModule.PREDICTION, prediction.id, prediction.target,
      `${prediction.confidence}% · ${prediction.status}`, prediction.createdAt, [prediction.status]));
  }

  const reviewService = await ReviewService.open(context);
  const reviews: ReviewHistoryItem[] = await reviewService.history(CANDIDATE_LIMIT);
  for (const review of reviews) {
    items.push(candidate(PlanLinkModule.REVIEW, review.id, `${review.periodLabel} ${review.rangeLabel}`,
      review.action, review.createdAt ?? 0, []));
  }

  const anchorService = await AnchorService.open(context);
  const anchors = await anchorService.list();
  for (const anchor of anchors) {
    items.push(candidate(PlanLinkModule.ANCHOR, anchor.id, anchor.text, anchor.source, 0, []));
  }

  const relationService = await RelationService.open(context);
  const relations: RelationListItem[] = await relationService.list(null);
  for (const relation of relations) {
    items.push(candidate(PlanLinkModule.RELATION, relation.id, relation.name,
      `${relation.trustLevel} · ${relation.interactionCount} 次互动`, relation.lastInteractionAt,
      [relation.trustLevel], [relation.id]));
  }

  const statusService = await StatusService.open(context);
  const rows: StatusDayRow[] = await statusService.history(CANDIDATE_LIMIT);
  for (const row of rows) {
    const timestamp = new Date(`${row.date}T00:00:00`).getTime();
    items.push(candidate(PlanLinkModule.STATUS, row.id, row.date,
      `睡眠 ${row.sleepHours} 小时`, timestamp, []));
  }
  return items;
}

function candidate(module: PlanLinkModule, targetId: string, title: string, subtitle: string,
  timestamp: number, tags: string[], relationIds: string[] = []): LinkCandidate {
  return {
    module: module,
    targetId: targetId,
    title: title,
    subtitle: subtitle,
    timestamp: timestamp,
    tags: tags,
    relationIds: relationIds,
    suggested: false,
    score: 0
  };
}

/** Chinese tab label for one module. */
export function planLinkModuleLabel(module: PlanLinkModule): string {
  switch (module) {
    case PlanLinkModule.NOTE:
      return '速记';
    case PlanLinkModule.PREDICTION:
      return '预测';
    case PlanLinkModule.REVIEW:
      return '复盘';
    case PlanLinkModule.ANCHOR:
      return '锚点';
    case PlanLinkModule.RELATION:
      return '关系';
    case PlanLinkModule.STATUS:
      return '状态';
    default:
      return module;
  }
}
