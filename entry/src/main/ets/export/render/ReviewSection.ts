import { Anchor } from '../../model/Anchor';
import { ReviewResult } from '../../model/ReviewResult';
import { EMPTY_FIELD, formatExportTime, inlineText } from '../MarkdownText';

/** Renders saved reviews with the anchors they referenced. */
export function renderReviewSection(reviews: ReviewResult[], anchors: Anchor[]): string {
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
    lines.push(`- 事实：${fieldText(review.facts)}`);
    lines.push(`- 解释：${fieldText(review.interpretation)}`);
    lines.push(`- 矛盾：${fieldText(review.contradiction)}`);
    lines.push(`- 行动：${fieldText(review.action)}`);
    lines.push('');
  }
  return lines.join('\n').trim();
}

function anchorText(ids: string[], anchors: Anchor[]): string {
  if (ids.length === 0) {
    return EMPTY_FIELD;
  }
  const texts: string[] = [];
  for (const id of ids) {
    const anchor = anchors.find((item: Anchor) => item.id === id);
    texts.push(anchor !== undefined ? inlineText(anchor.text) : id);
  }
  return texts.join('；');
}

function fieldText(value: string): string {
  return value.trim().length > 0 ? inlineText(value) : EMPTY_FIELD;
}
