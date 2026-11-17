import { isSameDay } from '../analysis/time/DateTime';
import { Plan } from '../model/Plan';
import { PlanItem } from '../model/PlanItem';
import { PlanNode } from '../model/PlanNode';
import { PlanNodeStatus } from '../model/PlanStatus';
import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { NoteListItem } from '../note/NoteListItem';
import { PredictionListItem } from '../prediction/PredictionListItem';
import { RelationListItem } from '../relation/RelationListItem';
import { ROUTES } from '../navigation/Routes';

/** Where one agenda row goes; each kind has its own detail route. */
export enum AgendaKind {
  PLAN_NODE = 'plan_node',
  PREDICTION_SETTLE = 'prediction_settle',
  RELATION_REPLY = 'relation_reply',
  PREDICTION_OPEN = 'prediction_open',
  NOTE_TODAY = 'note_today'
}

/** Category colour of one agenda row, resolved to a token by the card. */
export enum AgendaTone {
  PRACTICE = 'practice',
  OTHER = 'other',
  TIME = 'time',
  BOOK = 'book',
  PUBLIC = 'public'
}

/** One actionable object on today's practice board. */
export interface AgendaItem {
  key: string;
  kind: AgendaKind;
  title: string;
  /** Status or time line under the title */
  detail: string;
  /** Category colour shared with the module rail */
  tone: AgendaTone;
  route: string;
  /** Real record id carried to the detail page */
  targetId: string;
}

/** Read-only inputs, each already loaded through the existing services. */
export interface AgendaSource {
  plans: Plan[];
  nodes: PlanNode[];
  /** Every item of the supplied nodes */
  items: PlanItem[];
  predictions: PredictionListItem[];
  relations: RelationListItem[];
  /** Recent notes; rows outside today are ignored */
  todayNotes: NoteListItem[];
}

/** Rows plus the two counts shown in the masthead. */
export interface AgendaResult {
  items: AgendaItem[];
  /** Plan items, pending predictions and open hypotheses */
  pendingCount: number;
  /** Corrections that still have no own response */
  replyCount: number;
}

const RANK_PLAN = 0;
const RANK_SETTLE = 1;
const RANK_REPLY = 2;
const RANK_OPEN = 3;
const RANK_NOTE = 4;
const EXCERPT_LIMIT = 24;

/** Aggregates the five home sources into one ordered board without touching any service. */
export function buildAgenda(source: AgendaSource): AgendaResult {
  const rows: AgendaItem[] = [];
  let pendingCount = 0;
  let replyCount = 0;

  for (const node of source.nodes) {
    if (node.status !== PlanNodeStatus.OPEN) {
      continue;
    }
    const openItems = source.items.filter((item: PlanItem) => item.nodeId === node.id && !item.done);
    if (openItems.length === 0) {
      continue;
    }
    const plan = source.plans.find((entry: Plan) => entry.id === node.planId);
    const row: AgendaItem = {
      key: `plan_${node.id}`,
      kind: AgendaKind.PLAN_NODE,
      title: plan === undefined ? `第 ${node.weekIndex} 周清单` : plan.title,
      detail: `第 ${node.weekIndex} 周 · ${openItems.length} 项待处置`,
      tone: AgendaTone.PRACTICE,
      route: ROUTES.PLAN_NODE,
      targetId: node.id
    };
    rows.push(row);
    pendingCount += openItems.length;
  }

  const today = todayDateString();
  for (const prediction of source.predictions) {
    if (prediction.level === SecurityLevel.SEALED) {
      continue;
    }
    if (prediction.status === PredictionStatus.PENDING) {
      const row: AgendaItem = {
        key: `settle_${prediction.id}`,
        kind: AgendaKind.PREDICTION_SETTLE,
        title: prediction.target,
        detail: settlementDetail(prediction.settlementDate, today),
        tone: AgendaTone.TIME,
        route: ROUTES.PREDICTION_SETTLE,
        targetId: prediction.id
      };
      rows.push(row);
      pendingCount += 1;
      continue;
    }
    if (prediction.version > 1 || prediction.termOnly) {
      const row: AgendaItem = {
        key: `open_${prediction.id}`,
        kind: AgendaKind.PREDICTION_OPEN,
        title: prediction.target,
        detail: `第 ${prediction.version} 版假设待检验`,
        tone: AgendaTone.OTHER,
        route: ROUTES.PREDICTION_DETAIL,
        targetId: prediction.id
      };
      rows.push(row);
      pendingCount += 1;
    }
  }

  for (const relation of source.relations) {
    if (relation.level === SecurityLevel.SEALED || (relation.pendingCorrections ?? 0) === 0) {
      continue;
    }
    const excerpt = truncate((relation.correction ?? '').trim(), EXCERPT_LIMIT);
    const row: AgendaItem = {
      key: `reply_${relation.id}`,
      kind: AgendaKind.RELATION_REPLY,
      title: relation.name,
      detail: excerpt.length === 0 ? '对方纠正待回应' : `对方纠正待回应：${excerpt}`,
      tone: AgendaTone.PUBLIC,
      route: ROUTES.RELATION_DETAIL,
      targetId: relation.id
    };
    rows.push(row);
    replyCount += 1;
  }

  const now = Date.now();
  for (const note of source.todayNotes) {
    if (!isSameDay(note.timestamp, now)) {
      continue;
    }
    const row: AgendaItem = {
      key: `note_${note.id}`,
      kind: AgendaKind.NOTE_TODAY,
      title: note.title,
      detail: `${note.type} · ${note.timeLabel}`,
      tone: AgendaTone.BOOK,
      route: ROUTES.NOTE_DETAIL,
      targetId: note.id
    };
    rows.push(row);
  }

  rows.sort((left: AgendaItem, right: AgendaItem) => rankOf(left.kind) - rankOf(right.kind));
  return { items: rows, pendingCount: pendingCount, replyCount: replyCount };
}

function rankOf(kind: AgendaKind): number {
  if (kind === AgendaKind.PLAN_NODE) {
    return RANK_PLAN;
  }
  if (kind === AgendaKind.PREDICTION_SETTLE) {
    return RANK_SETTLE;
  }
  if (kind === AgendaKind.RELATION_REPLY) {
    return RANK_REPLY;
  }
  if (kind === AgendaKind.PREDICTION_OPEN) {
    return RANK_OPEN;
  }
  return RANK_NOTE;
}

function settlementDetail(settlementDate: string, today: string): string {
  if (settlementDate.length === 0) {
    return '未设期限';
  }
  const monthDay = settlementDate.length >= 10 ? settlementDate.slice(5) : settlementDate;
  if (settlementDate <= today) {
    return `${monthDay} 已到期`;
  }
  return `${monthDay} 到期`;
}

function truncate(text: string, limit: number): string {
  return text.length <= limit ? text : `${text.slice(0, limit)}…`;
}

function todayDateString(): string {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${now.getFullYear()}-${month}-${day}`;
}