import { countExportBundle, ExportBundle, totalExportRecords } from '../ExportBundle';
import { formatExportTime } from '../MarkdownText';

/** Renders the document title and the summary block. */
export function renderDocumentHeader(bundle: ExportBundle): string {
  const counts = countExportBundle(bundle);
  const summary = `事件 ${counts.events} · 决策 ${counts.decisions} · 关系 ${counts.relations} · ` +
    `预测 ${counts.predictions} · 锚点 ${counts.anchors} · 状态 ${counts.statusRecords}`;
  return [
    '# 元认知外化工作台 · 数据导出',
    '',
    `- 导出时间：${formatExportTime(bundle.exportedAt)}`,
    `- 记录总数：${totalExportRecords(counts)}（${summary}）`,
    '- 密级说明：标记为已封存的记录不会写入导出文件',
    '',
    '---'
  ].join('\n');
}
