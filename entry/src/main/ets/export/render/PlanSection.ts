import { PlanLink } from '../../model/PlanLink';
import { PlanItem } from '../../model/PlanItem';
import { PlanNode } from '../../model/PlanNode';
import { PlanLinkModule } from '../../model/PlanLinkModule';
import { PlanExport } from '../PlanExport';

/** Renders the plan section; empty when no plan is exportable. */
export function renderPlanSection(plans: PlanExport[]): string {
  if (plans.length === 0) {
    return '';
  }
  const lines: string[] = ['## 计划', ''];
  for (const entry of plans) {
    lines.push(`### 目标：${entry.plan.title}`, '');
    lines.push(`- 状态：${entry.plan.status}`);
    lines.push(`- 起始：${entry.plan.startDate}`);
    if (entry.plan.targetDate !== undefined && entry.plan.targetDate.length > 0) {
      lines.push(`- 结束：${entry.plan.targetDate}`);
    }
    if (entry.plan.goal.length > 0) {
      lines.push(`- 说明：${entry.plan.goal}`);
    }
    for (const node of entry.nodes) {
      lines.push('', `#### 第 ${node.weekIndex} 周（${node.startDate} 至 ${node.endDate}）`, '');
      const items = itemsForNode(entry.items, node.id);
      if (items.length === 0) {
        lines.push('- 暂无清单');
      } else {
        for (const item of items) {
          lines.push(`- [${item.done ? 'x' : ' '}] ${item.text}${item.carriedFrom !== undefined ? '（上周延续）' : ''}`);
        }
      }
      const links = linksForNode(entry.links, node.id);
      if (links.length > 0) {
        lines.push('', '关联记录：');
        for (const link of links) {
          lines.push(`- ${moduleLabel(link)} · ${link.label}`);
        }
      }
    }
    lines.push('');
  }
  return lines.join('\n');
}

function itemsForNode(items: PlanItem[], nodeId: string): PlanItem[] {
  const rows: PlanItem[] = [];
  for (const item of items) {
    if (item.nodeId === nodeId) {
      rows.push(item);
    }
  }
  return rows;
}

function linksForNode(links: PlanLink[], nodeId: string): PlanLink[] {
  const rows: PlanLink[] = [];
  for (const link of links) {
    if (link.nodeId === nodeId) {
      rows.push(link);
    }
  }
  return rows;
}

function moduleLabel(link: PlanLink): string {
  switch (link.module) {
    case PlanLinkModule.NOTE:
      return '速记';
    case PlanLinkModule.PREDICTION:
      return '预测';
    case PlanLinkModule.REVIEW:
      return '复盘';
    case PlanLinkModule.ANCHOR:
      return '锚点';
    case PlanLinkModule.RELATION:
      return '关系';
    case PlanLinkModule.STATUS:
      return '状态';
    default:
      return link.module;
  }
}
