import { StatusRecord } from '../../model/StatusRecord';
import { EMPTY_FIELD, inlineText } from '../MarkdownText';

/** Renders one line per day for the status records. */
export function renderStatusSection(records: StatusRecord[]): string {
  if (records.length === 0) {
    return '';
  }
  const lines: string[] = ['## 状态记录', ''];
  for (const record of records) {
    const date = record.date.trim().length > 0 ? record.date.trim() : EMPTY_FIELD;
    lines.push(`- ${date}：睡眠 ${record.sleepHours} 小时 · 运动 ${record.exerciseCount} 次 · 报警 ${record.alertCount} 次`);
    const note = record.note.trim();
    if (note.length > 0) {
      lines.push(`  - 备注：${inlineText(note)}`);
    }
  }
  return lines.join('\n');
}
