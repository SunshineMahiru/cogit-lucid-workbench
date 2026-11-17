import { Anchor } from '../../model/Anchor';
import { CostDimension, CostNote } from '../../model/CostNote';
import { DecisionRecord, DecisionRecordType } from '../../model/DecisionRecord';
import { EvidenceEffect, EvidenceItem } from '../../model/EvidenceItem';
import { ReviewResult } from '../../model/ReviewResult';
import { standingText } from '../../model/ReviewPayload';
import { EMPTY_FIELD, formatExportTime, inlineText } from '../MarkdownText';

/** Renders saved reviews with the anchors they referenced and the decisions they wrote. */
export function renderReviewSection(reviews: ReviewResult[], anchors: Anchor[],
  decisionRecords: DecisionRecord[] = [], evidenceItems: EvidenceItem[] = [],
  costNotes: CostNote[] = []): string {
  if (reviews.length === 0) {
    return '';
  }
  const lines: string[] = ['## 复盘', ''];
  for (const review of reviews) {
    const period = review.period === 'week' ? '周复盘' : '月复盘';
    lines.push(`### ${period} · ${inlineText(review.rangeLabel)}`);
    lines.push('');
    lines.push(`- 保存时间：${formatExportTime(review.createdAt)}`);
    lines.push(`- 引用锚点：${anchorText(review.anchorIds, anchors)}`);
    const payload = review.payload;
    if (payload !== undefined) {
      if (payload.standing !== undefined && payload.standing !== 'decided') {
        lines.push(`- 本次结果：${standingText(payload.standing)}`);
      }
      const citations = payload.anchorCitations ?? [];
      for (const citation of citations) {
        if (citation.reason.trim().length > 0) {
          lines.push(`  - 锚点理由：${inlineText(citation.reason)}`);
        }
        if ((citation.supports ?? '').trim().length > 0) {
          lines.push(`  - 锚点支持：${inlineText(citation.supports as string)}`);
        }
        if ((citation.limits ?? '').trim().length > 0) {
          lines.push(`  - 锚点限制：${inlineText(citation.limits as string)}`);
        }
        if ((citation.notApplicable ?? '').trim().length > 0) {
          lines.push(`  - 锚点不适用：${inlineText(citation.notApplicable as string)}`);
        }
      }
    }
    if (payload !== undefined) {
      lines.push(`- 现场：${fieldText(payload.scene)}`);
      lines.push(`- 模型：${fieldText(payload.model)}`);
      lines.push(`- 关系与矛盾：${fieldText(payload.relation)}`);
      lines.push(`- 多源校正：${fieldText(payload.evidence)}`);
      lines.push(`- 成本与动机：${fieldText(payload.cost)}`);
      lines.push(`- 调节与修订：${fieldText(payload.revision)}`);
    } else {
      lines.push(`- 事实：${fieldText(review.facts)}`);
      lines.push(`- 解释：${fieldText(review.interpretation)}`);
      lines.push(`- 矛盾：${fieldText(review.contradiction)}`);
      lines.push(`- 行动：${fieldText(review.action)}`);
    }
    appendEvidence(lines, review.id, evidenceItems);
    appendCosts(lines, review.id, costNotes);
    appendDecisions(lines, decisionsOf(review.id, decisionRecords));
    lines.push('');
  }
  return lines.join('\n').trim();
}

function decisionsOf(reviewId: string, records: DecisionRecord[]): DecisionRecord[] {
  const items: DecisionRecord[] = [];
  for (const record of records) {
    if (record.reviewId === reviewId) {
      items.push(record);
    }
  }
  return items;
}

function appendEvidence(lines: string[], reviewId: string, items: EvidenceItem[]): void {
  const rows = items.filter((item: EvidenceItem) => item.targetType === 'review' && item.targetId === reviewId);
  if (rows.length === 0) {
    return;
  }
  lines.push('- 证据：');
  for (const item of rows) {
    lines.push(`  - ${evidenceSourceText(item.sourceType)} · ${evidenceEffectText(item.effect)}：${fieldText(item.note)}`);
  }
}

/** Six evidence sources keep their distinct strength in export; none implies universal proof. */
function evidenceSourceText(source: string): string {
  if (source === 'practice') {
    return '现场与行动';
  }
  if (source === 'other_person') {
    return '他者叙述';
  }
  if (source === 'body') {
    return '身体反馈';
  }
  if (source === 'time') {
    return '长期结果';
  }
  if (source === 'book') {
    return '书本理论';
  }
  if (source === 'public') {
    return '公共资料';
  }
  return '自我观察';
}

function appendCosts(lines: string[], reviewId: string, notes: CostNote[]): void {
  const rows = notes.filter((note: CostNote) => note.reviewId === reviewId);
  if (rows.length === 0) {
    return;
  }
  lines.push('- 成本：');
  for (const note of rows) {
    lines.push(`  - ${costDimensionText(note.dimension)} · ${fieldText(note.text)} · ${note.bearable ? '可承受' : '难以承受'}`);
  }
}

function evidenceEffectText(effect: EvidenceEffect): string {
  if (effect === 'supports') {
    return '支持';
  }
  if (effect === 'challenges') {
    return '挑战';
  }
  return '不清楚';
}

function costDimensionText(dimension: CostDimension): string {
  if (dimension === 'meaning') {
    return '意义';
  }
  if (dimension === 'body') {
    return '身体';
  }
  if (dimension === 'relationship') {
    return '关系';
  }
  if (dimension === 'time') {
    return '时间';
  }
  if (dimension === 'public') {
    return '公共生活';
  }
  return '其他';
}

function appendDecisions(lines: string[], records: DecisionRecord[]): void {
  if (records.length === 0) {
    return;
  }
  lines.push('- 本次决定：');
  for (const record of records) {
    lines.push(`  - 类型：${decisionTypeLabel(record.type)}`);
    lines.push(`    - 原因：${fieldText(record.reason)}`);
    lines.push(`    - 行动：${actionText(record.action)}`);
    lines.push(`    - 承诺：${fieldText(record.commitment ?? '')}`);
    lines.push(`    - 共同实践结果：${fieldText(record.outcome ?? '')}`);
    lines.push(`    - 回看日期：${fieldText(record.reviewAt ?? '')}`);
  }
}

function decisionTypeLabel(type: DecisionRecordType): string {
  if (type === 'continue') {
    return '继续';
  }
  if (type === 'switch') {
    return '切换';
  }
  if (type === 'pause') {
    return '暂停';
  }
  if (type === 'discard') {
    return '舍弃';
  }
  if (type === 'exit') {
    return '退出';
  }
  return '共同实践';
}

function anchorText(ids: string[], anchors: Anchor[]): string {
  if (ids.length === 0) {
    return EMPTY_FIELD;
  }
  const texts: string[] = [];
  for (const id of ids) {
    const anchor = anchors.find((item: Anchor) => item.id === id);
    texts.push(anchor !== undefined ? inlineText(anchor.text) : '（已封存或已删除的锚点）');
  }
  return texts.join('；');
}

function actionText(value: string | undefined): string {
  if (value === undefined || value.trim().length === 0) {
    return '未填写';
  }
  return inlineText(value);
}

function fieldText(value: string): string {
  return value.trim().length > 0 ? inlineText(value) : EMPTY_FIELD;
}