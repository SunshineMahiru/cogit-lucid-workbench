import { Relation } from '../../model/Relation';
import {
  EMPTY_FIELD,
  formatExportTime,
  inlineText,
  securityLevelLabel,
  trustLevelLabel,
  yesNoLabel
} from '../MarkdownText';

/** Renders the relation section; returns an empty string when nothing is left to export. */
export function renderRelationSection(relations: Relation[]): string {
  if (relations.length === 0) {
    return '';
  }
  const lines: string[] = ['## 关系', ''];
  for (const relation of relations) {
    lines.push(`### ${inlineText(relation.name)}`);
    lines.push('');
    lines.push(`- 信任分层：${trustLevelLabel(relation.trustLevel)}`);
    lines.push(`- 未加工材料测试：${yesNoLabel(relation.rawMaterialTest)}`);
    lines.push(`- 禁止动机分析：${yesNoLabel(relation.forbidAnalysis)}`);
    lines.push(`- 备注：${inlineText(relation.notes)}`);
    lines.push(`- 密级：${securityLevelLabel(relation.level)}`);
    if (relation.interactionLog.length === 0) {
      lines.push(`- 互动记录：${EMPTY_FIELD}`);
    } else {
      lines.push('- 互动记录：');
      for (const log of relation.interactionLog) {
        lines.push(`  - ${formatExportTime(log.timestamp)}：${inlineText(log.content)}`);
      }
    }
    lines.push('');
  }
  return lines.join('\n').trim();
}
