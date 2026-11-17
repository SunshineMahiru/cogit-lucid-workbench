import { AgendaTone } from '../home/AgendaMapper';
import { PlanNode } from '../model/PlanNode';
import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { ROUTES } from '../navigation/Routes';
import { PredictionListItem } from '../prediction/PredictionListItem';
import { RelationListItem } from '../relation/RelationListItem';
import { ReviewHistoryItem } from '../review/ReviewHistory';
import { formatPlanDate } from './PlanFactory';

/** The three records a week gathers beside its own checklist. */
export enum WeekAgendaGroup {
  PREDICTION = 'prediction',
  RELATION = 'relation',
  REVIEW = 'review'
}

/** One openable row of the week agenda. */
export interface WeekAgendaRow {
  key: string;
  group: WeekAgendaGroup;
  title: string;
  detail: string;
  route: string;
  targetId: string;
  tone: AgendaTone;
}

/** Three read-only groups, each ordered by relevance inside the week. */
export interface WeekAgenda {
  predictions: WeekAgendaRow[];
  relations: WeekAgendaRow[];
  reviews: WeekAgendaRow[];
}

/** Already-loaded lists; the mapper never queries a service. */
export interface WeekAgendaSource {
  node: PlanNode;
  predictions: PredictionListItem[];
  relations: RelationListItem[];
  reviews: ReviewHistoryItem[];
}

const EXCERPT_LIMIT = 32;

/**
 * Collects the predictions due, the people waiting for a reply and the reviews written
 * inside one seven-day node. Rows outside [startDate, endDate] and sealed records are dropped.
 */
export function buildWeekAgenda(source: WeekAgendaSource): WeekAgenda {
  const start = source.node.startDate;
  const end = source.node.endDate;
  const predictions: WeekAgendaRow[] = [];
  for (const prediction of source.predictions) {
    if (prediction.level === SecurityLevel.SEALED) {
      continue;
    }
    if (prediction.status !== PredictionStatus.PENDING) {
      continue;
    }
    if (!inRange(prediction.settlementDate, start, end)) {
      continue;
    }
    predictions.push({
      key: `week_settle_${prediction.id}`,
      group: WeekAgendaGroup.PREDICTION,
      title: prediction.target,
      detail: dueDetail(prediction.settlementDate),
      route: ROUTES.PREDICTION_SETTLE,
      targetId: prediction.id,
      tone: AgendaTone.TIME
    });
  }
  predictions.sort((left: WeekAgendaRow, right: WeekAgendaRow) => left.detail.localeCompare(right.detail));

  const relations: WeekAgendaRow[] = [];
  for (const relation of source.relations) {
    if (relation.level === SecurityLevel.SEALED || (relation.pendingCorrections ?? 0) === 0) {
      continue;
    }
    if (!inRange(dateOfTimestamp(relation.correctionAt ?? 0), start, end) &&
      !inRange(dateOfTimestamp(relation.lastInteractionAt), start, end)) {
      continue;
    }
    const excerpt = truncate((relation.latestCorrectionExcerpt ?? relation.correction ?? '').trim(), EXCERPT_LIMIT);
    relations.push({
      key: `week_reply_${relation.id}`,
      group: WeekAgendaGroup.RELATION,
      title: relation.name,
      detail: excerpt.length === 0 ? '对方纠正待回应' : `对方纠正待回应：${excerpt}`,
      route: ROUTES.RELATION_DETAIL,
      targetId: relation.id,
      tone: AgendaTone.PUBLIC
    });
  }

  const reviews: WeekAgendaRow[] = [];
  for (const review of source.reviews) {
    const createdAt = review.createdAt ?? 0;
    const sameNode = review.planNodeId !== undefined && review.planNodeId === source.node.id;
    if (!sameNode && !inRange(dateOfTimestamp(createdAt), start, end)) {
      continue;
    }
    reviews.push({
      key: `week_review_${review.id}`,
      group: WeekAgendaGroup.REVIEW,
      title: reviewTitle(review),
      detail: review.rangeLabel,
      route: ROUTES.REVIEW_DETAIL,
      targetId: review.id,
      tone: AgendaTone.OTHER
    });
  }

  return { predictions: predictions, relations: relations, reviews: reviews };
}

/** Count of every gathered row, used for the section caption. */
export function weekAgendaCount(agenda: WeekAgenda): number {
  return agenda.predictions.length + agenda.relations.length + agenda.reviews.length;
}

function inRange(date: string, start: string, end: string): boolean {
  return date.length >= 10 && date >= start && date <= end;
}

function dateOfTimestamp(timestamp: number): string {
  if (timestamp <= 0) {
    return '';
  }
  return formatPlanDate(new Date(timestamp));
}

function dueDetail(settlementDate: string): string {
  const monthDay = settlementDate.slice(5);
  return `${monthDay} 结算`;
}

function reviewTitle(review: ReviewHistoryItem): string {
  const action = review.action.trim();
  if (action.length === 0) {
    return `${review.periodLabel} · ${review.rangeLabel}`;
  }
  return truncate(action, EXCERPT_LIMIT);
}

function truncate(text: string, limit: number): string {
  return text.length <= limit ? text : `${text.slice(0, limit)}…`;
}