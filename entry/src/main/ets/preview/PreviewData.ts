import {
  MOCK_ANCHORS,
  MOCK_EVENTS,
  MOCK_PREDICTIONS,
  MOCK_RELATIONS,
  MOCK_STATUS_RECORDS
} from '../model/mockData';
import { Anchor } from '../model/Anchor';
import { HomeSummary, BodyReading, PredictionItem } from '../model/HomeModel';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewResult } from '../model/ReviewResult';
import { NoteDetail, toNoteDetail } from '../note/NoteDetail';
import { NoteListItem } from '../note/NoteListItem';
import { toNoteListItems } from '../note/NoteListMapper';
import {
  PredictionDetail,
  PredictionListItem,
  PredictionSummary,
  PredictionStats,
  buildPredictionStats,
  summarizePredictions,
  toPredictionDetail,
  toPredictionListItems
} from '../prediction';
import { RelationDetail, RelationListItem, toRelationDetail, toRelationListItems } from '../relation';
import { StatusDayRow, StatusOverview, buildStatusOverview, toStatusDayRows } from '../status';
import { ThresholdReadingRules } from '../analysis/status/ThresholdReadingRules';
import { ReviewDetailView, ReviewHistoryItem, toReviewDetailView, toReviewHistoryItem } from '../review';
import { ReviewStats } from '../review/ReviewDraft';
import { AppSettings, defaultAppSettings } from '../settings/AppSettings';

const PREVIEW_NOW = 1761609600000;

/** Synthetic dashboard readings used only when no database context is available. */
export const PREVIEW_READINGS: BodyReading[] = [
  { label: '睡眠', value: '7.2', unit: ' 小时' },
  { label: '运动', value: '1', unit: ' 次' },
  { label: '速记', value: '2', unit: ' 条' }
];

/** Synthetic pending predictions for the dashboard. */
export const PREVIEW_PENDING_PREDICTIONS: PredictionItem[] = [
  { id: 'pr_demo_1', title: '本周作息', confidence: 70, dueDate: '2026-10-31' },
  { id: 'pr_demo_10', title: '十一月作息', confidence: 55, dueDate: '2026-11-30' }
];

/** Synthetic summary matching the demo records. */
export const PREVIEW_HOME_SUMMARY: HomeSummary = {
  totalNotes: MOCK_EVENTS.length,
  todayNotes: Math.min(2, MOCK_EVENTS.length),
  totalPredictions: MOCK_PREDICTIONS.length,
  pendingPredictions: 2,
  settledPredictions: MOCK_PREDICTIONS.length - 2,
  hitRate: summarizePredictions(MOCK_PREDICTIONS).hitRate,
  unreviewedDecisions: 1,
  totalAnchors: MOCK_ANCHORS.length,
  totalRelations: MOCK_RELATIONS.length
};

export const PREVIEW_NOTE_ITEMS: NoteListItem[] = toNoteListItems(MOCK_EVENTS, PREVIEW_NOW);
export const PREVIEW_NOTE_DETAILS: NoteDetail[] = MOCK_EVENTS.map((event) => toNoteDetail(event, PREVIEW_NOW));
export const PREVIEW_RECENT_NOTES: NoteListItem[] = PREVIEW_NOTE_ITEMS.slice(0, 5);

export const PREVIEW_ANCHORS: Anchor[] = MOCK_ANCHORS.slice();

export const PREVIEW_PREDICTION_ITEMS: PredictionListItem[] = toPredictionListItems(MOCK_PREDICTIONS);
export const PREVIEW_PREDICTION_SUMMARY: PredictionSummary = summarizePredictions(MOCK_PREDICTIONS);
export const PREVIEW_PREDICTION_STATS: PredictionStats = buildPredictionStats(MOCK_PREDICTIONS);
export const PREVIEW_PREDICTION_DETAILS: PredictionDetail[] = MOCK_PREDICTIONS.map((prediction) =>
  toPredictionDetail(prediction));

export const PREVIEW_RELATION_ITEMS: RelationListItem[] = toRelationListItems(MOCK_RELATIONS);
export const PREVIEW_RELATION_DETAILS: RelationDetail[] = MOCK_RELATIONS.map((relation) =>
  toRelationDetail(relation));

const PREVIEW_RULES = new ThresholdReadingRules();
export const PREVIEW_STATUS_ROWS: StatusDayRow[] = toStatusDayRows(MOCK_STATUS_RECORDS, PREVIEW_RULES);
export const PREVIEW_STATUS_OVERVIEW: StatusOverview =
  buildStatusOverview(MOCK_STATUS_RECORDS, PREVIEW_RULES, 7);

const PREVIEW_REVIEW: ReviewResult = {
  id: 'rv_demo_1',
  period: ReviewPeriod.WEEK,
  rangeLabel: '10 月 20 日 – 10 月 26 日',
  facts: '本周完成了三次速记，预测结算两次。',
  interpretation: '记录频率稳定，但复盘集中在周末。',
  contradiction: '把忙碌当成不记录的原因，实际记录只需要一分钟。',
  action: '下周把速记固定在午休后。',
  anchorIds: ['an_demo_1', 'an_demo_2'],
  createdAt: PREVIEW_NOW
};

export const PREVIEW_REVIEW_HISTORY: ReviewHistoryItem[] = [toReviewHistoryItem(PREVIEW_REVIEW)];
export const PREVIEW_REVIEW_DETAIL: ReviewDetailView =
  toReviewDetailView(PREVIEW_REVIEW, MOCK_ANCHORS);

export const PREVIEW_REVIEW_STATS: ReviewStats = {
  rangeLabel: '10 月 26 日 – 11 月 1 日',
  noteCount: MOCK_EVENTS.length,
  decisionCount: 1,
  pendingPredictions: 2,
  settledPredictions: 8,
  hitRate: summarizePredictions(MOCK_PREDICTIONS).hitRate,
  anchorCount: MOCK_ANCHORS.length
};

export const PREVIEW_WEEK_REVIEWED: boolean = true;

export const PREVIEW_SETTINGS: AppSettings = defaultAppSettings();

/** Finds one synthetic note by id; returns null when the id is unknown. */
export function findPreviewNote(id: string): NoteDetail | null {
  for (const note of PREVIEW_NOTE_DETAILS) {
    if (note.id === id) {
      return note;
    }
  }
  return null;
}

/** Finds one synthetic prediction by id; returns null when the id is unknown. */
export function findPreviewPrediction(id: string): PredictionDetail | null {
  for (const prediction of PREVIEW_PREDICTION_DETAILS) {
    if (prediction.id === id) {
      return prediction;
    }
  }
  return null;
}

/** Finds one synthetic relation by id; returns null when the id is unknown. */
export function findPreviewRelation(id: string): RelationDetail | null {
  for (const relation of PREVIEW_RELATION_DETAILS) {
    if (relation.id === id) {
      return relation;
    }
  }
  return null;
}

/** Finds one synthetic review by id; returns null when the id is unknown. */
export function findPreviewReview(id: string): ReviewDetailView | null {
  return id === PREVIEW_REVIEW_DETAIL.id ? PREVIEW_REVIEW_DETAIL : null;
}
