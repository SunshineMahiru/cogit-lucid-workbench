import { MOCK_EVENTS, MOCK_PREDICTIONS } from '../model/mockData';
import { BodyReading, HomeSummary, PredictionItem } from '../model/HomeModel';
import { Event } from '../model/Event';
import { Prediction } from '../model/Prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { ReviewResult } from '../model/ReviewResult';
import { createEvent, createPrediction as makePrediction, createReviewResult } from '../model/factories';
import { NoteDetail, toNoteDetail } from '../note/NoteDetail';
import { NoteDraft } from '../note/NoteDraft';
import { NoteListItem } from '../note/NoteListItem';
import { toNoteListItems } from '../note/NoteListMapper';
import { composeNoteContent, deriveNoteTitle } from '../note/NoteContentComposer';
import { findNoteTemplate } from '../note/templates';
import {
  PredictionDetail,
  PredictionListItem,
  PredictionSummary
} from '../prediction/PredictionListItem';
import {
  summarizePredictions,
  toPredictionDetail,
  toPredictionListItems
} from '../prediction/PredictionListMapper';
import { PredictionStats, buildPredictionStats } from '../prediction/PredictionStats';
import { PredictionDraft } from '../prediction/PredictionValidation';
import { ReviewDetailView, ReviewHistoryItem, toReviewDetailView, toReviewHistoryItem } from '../review/ReviewHistory';
import { ReviewDraft, ReviewStats } from '../review/ReviewDraft';
import { PREVIEW_ANCHORS, PREVIEW_REVIEW_RESULT } from './PreviewData';

const FREE_NOTE_TYPE = '速记';

/** In-session mutable data used by the Previewer; it never reaches relationalStore. */
class PreviewStore {
  private notes: Event[] = MOCK_EVENTS.map((event) => copyEvent(event));
  private predictions: Prediction[] = MOCK_PREDICTIONS.map((prediction) => copyPrediction(prediction));
  private reviews: ReviewResult[] = [copyReview(PREVIEW_REVIEW_RESULT)];

  listNotes(filter: string): NoteListItem[] {
    const selected = this.notes.filter((event: Event) => filter.length === 0 || event.type === filter);
    return toNoteListItems(selected);
  }

  findNote(id: string): NoteDetail | null {
    for (const event of this.notes) {
      if (event.id === id) {
        return toNoteDetail(event, Date.now());
      }
    }
    return null;
  }

  addNote(draft: NoteDraft): NoteDetail {
    const event = createEvent();
    event.title = draft.title.trim().length > 0 ? draft.title.trim() : deriveNoteTitle(draft);
    event.content = composeNoteContent(draft);
    event.type = draft.templateId === null ? FREE_NOTE_TYPE : findNoteTemplate(draft.templateId).label;
    event.timestamp = draft.timestamp > 0 ? draft.timestamp : Date.now();
    event.tags = normalizeTags(draft.tags);
    event.relatedRelationIds = draft.relatedRelationIds.slice();
    event.level = draft.level;
    this.notes.unshift(event);
    return toNoteDetail(event, Date.now());
  }

  listPredictions(filter: PredictionStatus | null): PredictionListItem[] {
    const selected: Prediction[] = filter === null ? this.predictions :
      this.predictions.filter((prediction: Prediction) => prediction.status === filter);
    return toPredictionListItems(selected);
  }

  predictionSummary(): PredictionSummary {
    return summarizePredictions(this.predictions);
  }

  predictionStats(): PredictionStats {
    return buildPredictionStats(this.predictions);
  }

  findPrediction(id: string): PredictionDetail | null {
    for (const prediction of this.predictions) {
      if (prediction.id === id) {
        return toPredictionDetail(prediction);
      }
    }
    return null;
  }

  createPrediction(draft: PredictionDraft): PredictionDetail {
    const prediction = makePrediction();
    prediction.target = draft.target.trim();
    prediction.judgment = draft.judgment.trim();
    prediction.confidence = Math.round(draft.confidence);
    prediction.reason = draft.reason.trim();
    prediction.settlementDate = draft.settlementDate.trim();
    this.predictions.unshift(prediction);
    return toPredictionDetail(prediction);
  }

  revisePrediction(sourceId: string, draft: PredictionDraft): PredictionDetail | null {
    let source: Prediction | null = null;
    for (const prediction of this.predictions) {
      if (prediction.id === sourceId) {
        source = prediction;
      }
    }
    if (source === null) {
      return null;
    }
    const prediction = makePrediction();
    prediction.target = draft.target.trim();
    prediction.judgment = draft.judgment.trim();
    prediction.confidence = Math.round(draft.confidence);
    prediction.reason = draft.reason.trim();
    prediction.settlementDate = draft.settlementDate.trim();
    prediction.version = source.version + 1;
    this.predictions.unshift(prediction);
    return toPredictionDetail(prediction);
  }

  settlePrediction(id: string, actualResult: string, hit: boolean): PredictionDetail | null {
    for (const prediction of this.predictions) {
      if (prediction.id === id && prediction.status === PredictionStatus.PENDING) {
        prediction.status = PredictionStatus.SETTLED;
        prediction.actualResult = actualResult.trim();
        prediction.hit = hit;
        return toPredictionDetail(prediction);
      }
    }
    return null;
  }

  previewReadings(): BodyReading[] {
    return [
      { label: '睡眠', value: '7.2', unit: ' 小时' },
      { label: '运动', value: '1', unit: ' 次' },
      { label: '速记', value: String(this.notes.length), unit: ' 条' }
    ];
  }

  homeSummary(): HomeSummary {
    const summary = this.predictionSummary();
    return {
      totalNotes: this.notes.length,
      todayNotes: Math.min(2, this.notes.length),
      totalPredictions: summary.total,
      pendingPredictions: summary.pending,
      settledPredictions: summary.settled,
      hitRate: summary.hitRate,
      unreviewedDecisions: 1,
      totalAnchors: 2,
      totalRelations: 3
    };
  }

  pendingPredictions(): PredictionItem[] {
    const rows: PredictionItem[] = [];
    const pending = this.predictions.filter(p => p.status === PredictionStatus.PENDING);
    pending.sort((left, right) => left.settlementDate < right.settlementDate ? -1 : 1);
    for (const prediction of pending) {
      rows.push({
        id: prediction.id,
        title: prediction.target,
        confidence: prediction.confidence,
        dueDate: prediction.settlementDate
      });
    }
    return rows;
  }

  recentNotes(limit: number = 5): NoteListItem[] {
    return toNoteListItems(this.notes.slice(0, limit));
  }

  weekStats(): ReviewStats {
    const summary = this.predictionSummary();
    return {
      rangeLabel: '10 月 26 日 – 11 月 1 日',
      noteCount: this.notes.length,
      decisionCount: 1,
      pendingPredictions: summary.pending,
      settledPredictions: summary.settled,
      hitRate: summary.hitRate,
      anchorCount: 2
    };
  }

  weekReviewed(): boolean {
    return this.reviews.length > 0;
  }

  reviewHistory(): ReviewHistoryItem[] {
    return this.reviews.map((review: ReviewResult) => toReviewHistoryItem(review));
  }

  findReview(id: string): ReviewDetailView | null {
    for (const review of this.reviews) {
      if (review.id === id) {
        return toReviewDetailView(review, PREVIEW_ANCHORS);
      }
    }
    return null;
  }

  saveReview(period: ReviewPeriod, draft: ReviewDraft, rangeLabel: string): string {
    const result = createReviewResult();
    result.period = period;
    result.rangeLabel = rangeLabel;
    result.facts = draft.facts.trim();
    result.interpretation = draft.interpretation.trim();
    result.contradiction = draft.contradiction.trim();
    result.action = draft.action.trim();
    result.anchorIds = draft.anchorIds.slice();
    this.reviews.unshift(result);
    return result.id;
  }
}

function copyEvent(event: Event): Event {
  return {
    id: event.id,
    title: event.title,
    content: event.content,
    type: event.type,
    timestamp: event.timestamp,
    tags: event.tags.slice(),
    level: event.level,
    relatedDecisionIds: event.relatedDecisionIds.slice(),
    relatedRelationIds: event.relatedRelationIds.slice()
  };
}

function copyPrediction(prediction: Prediction): Prediction {
  return {
    id: prediction.id,
    target: prediction.target,
    judgment: prediction.judgment,
    confidence: prediction.confidence,
    reason: prediction.reason,
    settlementDate: prediction.settlementDate,
    status: prediction.status,
    actualResult: prediction.actualResult,
    hit: prediction.hit,
    version: prediction.version,
    createdAt: prediction.createdAt
  };
}

function copyReview(review: ReviewResult): ReviewResult {
  return {
    id: review.id,
    period: review.period,
    rangeLabel: review.rangeLabel,
    facts: review.facts,
    interpretation: review.interpretation,
    contradiction: review.contradiction,
    action: review.action,
    anchorIds: review.anchorIds.slice(),
    createdAt: review.createdAt
  };
}

function normalizeTags(tags: string[]): string[] {
  const values: string[] = [];
  for (const tag of tags) {
    const value = tag.trim();
    if (value.length > 0 && !values.includes(value)) {
      values.push(value);
    }
  }
  return values;
}

export const previewStore = new PreviewStore();
