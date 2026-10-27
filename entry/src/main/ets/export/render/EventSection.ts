import { Event } from '../../model/Event';
import { formatExportTime, inlineList, inlineText, securityLevelLabel } from '../MarkdownText';

/** Renders the event section; returns an empty string when nothing is left to export. */
export function renderEventSection(events: Event[]): string {
  if (events.length === 0) {
    return '';
  }
  const lines: string[] = ['## 事件', ''];
  for (const event of events) {
    lines.push(`### ${inlineText(event.title)}`);
    lines.push('');
    lines.push(`- 类型：${inlineText(event.type)}`);
    lines.push(`- 时间：${formatExportTime(event.timestamp)}`);
    lines.push(`- 标签：${inlineList(event.tags)}`);
    lines.push(`- 密级：${securityLevelLabel(event.level)}`);
    const content = event.content.trim();
    if (content.length > 0) {
      lines.push('');
      lines.push(content);
    }
    lines.push('');
  }
  return lines.join('\n').trim();
}
