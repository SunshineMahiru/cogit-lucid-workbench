import { common } from '@kit.AbilityKit';
import { PlanItem } from '../model/PlanItem';
import { PlanNode } from '../model/PlanNode';
import { ReviewDraftStore } from '../review/ReviewDraftStore';

/** Builds the facts block written into the weekly review draft when a node closes. */
export function buildPlanReviewFacts(planTitle: string, node: PlanNode, items: PlanItem[],
  next: PlanNode | null): string {
  const done: string[] = [];
  const pending: string[] = [];
  for (const item of items) {
    if (item.done) {
      done.push(`- [完成] ${item.text}`);
    } else {
      pending.push(`- [未完成] ${item.text}`);
    }
  }
  const lines: string[] = [
    `【计划：${planTitle.length > 0 ? planTitle : '未命名目标'} · 第 ${node.weekIndex} 周】`,
    `第 ${node.weekIndex} 周（${node.startDate} 至 ${node.endDate}）计划清单：`,
    `完成 ${done.length} 项，未完成 ${pending.length} 项。`
  ];
  if (done.length > 0) {
    lines.push('完成：');
    for (const line of done) {
      lines.push(line);
    }
  }
  if (pending.length > 0) {
    lines.push('未完成：');
    for (const line of pending) {
      lines.push(line);
    }
  }
  if (pending.length === 0 && done.length === 0) {
    lines.push('本周没有清单项。');
  }
  if (next !== null && pending.length > 0) {
    lines.push(`以上未完成项已带入第 ${next.weekIndex} 周（${next.startDate} 至 ${next.endDate}）。`);
  }
  return lines.join('\n');
}

/** Writes the plan summary into the weekly review draft, preserving existing text. */
export async function writePlanReviewDraft(context: common.Context, facts: string): Promise<void> {
  const store = await ReviewDraftStore.open(context);
  await store.prefillWeekly(facts);
}
