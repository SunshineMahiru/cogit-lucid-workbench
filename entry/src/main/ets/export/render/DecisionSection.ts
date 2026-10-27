import { Decision } from '../../model/Decision';
import { formatExportTime, inlineList, inlineText, securityLevelLabel } from '../MarkdownText';

/** Renders the decision section; returns an empty string when nothing is left to export. */
export function renderDecisionSection(decisions: Decision[]): string {
  if (decisions.length === 0) {
    return '';
  }
  const lines: string[] = ['## 决策', ''];
  for (const decision of decisions) {
    lines.push(`### ${inlineText(decision.title)}`);
    lines.push('');
    lines.push(`- 背景：${inlineText(decision.background)}`);
    lines.push(`- 选项：${inlineList(decision.options)}`);
    lines.push(`- 选择：${inlineText(decision.choice)}`);
    lines.push(`- 预期：${inlineText(decision.expectedOutcome)}`);
    lines.push(`- 时间：${formatExportTime(decision.timestamp)}`);
    lines.push(`- 状态：${decision.reviewed ? '已复盘' : '未复盘'}`);
    lines.push(`- 密级：${securityLevelLabel(decision.level)}`);
    lines.push('');
  }
  return lines.join('\n').trim();
}
