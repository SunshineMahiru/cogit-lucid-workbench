import { Event } from '../../model/Event';
import { ExperienceMaterial, MaterialKind } from '../../model/ExperienceMaterial';
import { materialFormText, materialKindText, materialSourceText } from '../../note/NoteDetail';
import { formatExportTime, inlineList, inlineText, securityLevelLabel } from '../MarkdownText';

/** Reading order of material kinds inside one note. */
const MATERIAL_KIND_ORDER: MaterialKind[] = [
  'scene',
  'feeling',
  'body',
  'existing_action',
  'interpretation',
  'unclassified'
];

function materialRank(kind: MaterialKind): number {
  const index = MATERIAL_KIND_ORDER.indexOf(kind);
  return index < 0 ? MATERIAL_KIND_ORDER.length : index;
}

/** Materials of one note, grouped in kind order; ties keep the order they arrived in. */
function materialsOfEvent(materials: ExperienceMaterial[], eventId: string): ExperienceMaterial[] {
  const rows: ExperienceMaterial[] = [];
  for (const material of materials) {
    if (material.eventId === eventId) {
      rows.push(material);
    }
  }
  rows.sort((left, right) => materialRank(left.kind) - materialRank(right.kind));
  return rows;
}

/** Renders the event section; returns an empty string when nothing is left to export. */
export function renderEventSection(events: Event[], materials: ExperienceMaterial[]): string {
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
    const eventMaterials = materialsOfEvent(materials, event.id);
    if (eventMaterials.length > 0) {
      lines.push('');
      for (const material of eventMaterials) {
        lines.push(`- 材料（${materialKindText(material.kind)} · ${materialSourceText(material.source)} · ` +
          `${materialFormText(material.form)}）：${inlineText(material.text)}`);
      }
    }
    lines.push('');
  }
  return lines.join('\n').trim();
}