import { Relation } from '../../model/Relation';
import { disclosureBoundaryOf } from '../../relation/DisclosureBoundary';
import { sourceText, toInteractionSource } from '../../relation/InteractionSource';
import {
  EMPTY_FIELD,
  formatExportTime,
  inlineText,
  securityLevelLabel,
  trustLevelLabel
} from '../MarkdownText';

/** Renders the relation section; returns an empty string when nothing is left to export. */
export function renderRelationSection(relations: Relation[]): string {
  if (relations.length === 0) {
    return '';
  }
  const lines: string[] = ['## 关系', ''];
  for (const relation of relations) {
    const boundary = disclosureBoundaryOf(relation.trustLevel, relation.forbidAnalysis);
    lines.push(`### ${inlineText(relation.name)}`);
    lines.push('');
    lines.push(`- 披露层级：${trustLevelLabel(relation.trustLevel)}`);
    lines.push(`- 披露与引用边界：${boundary.shareable}`);
    lines.push(`- 禁止推断：${relation.forbidAnalysis ? '是，只做事实描述' : '否，但本应用不推断动机与关系结局'}`);
    if ((relation.correction ?? '').length > 0) {
      lines.push(`- 对方怎样纠正了我的理解：${inlineText(relation.correction ?? '')}`);
    }
    lines.push(`- 备注：${inlineText(relation.notes)}`);
    lines.push(`- 密级：${securityLevelLabel(relation.level)}`);
    if (relation.interactionLog.length === 0) {
      lines.push(`- 互动记录：${EMPTY_FIELD}`);
    } else {
      lines.push('- 互动记录：');
      for (const log of relation.interactionLog) {
        const source = sourceText(toInteractionSource(log.source ?? ''));
        lines.push(`  - ${formatExportTime(log.timestamp)} · ${source}：${inlineText(log.content)}`);
      }
    }
    lines.push('');
  }
  return lines.join('\n').trim();
}
