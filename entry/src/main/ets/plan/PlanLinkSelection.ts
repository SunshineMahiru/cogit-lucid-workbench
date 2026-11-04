import { PlanLink } from '../model/PlanLink';
import { createPlanLink } from './PlanFactory';
import { LinkCandidate } from './PlanLinkCandidate';

/** 关联选择的键，模块与记录 id 一起决定唯一性。 */
export function planLinkKey(module: string, targetId: string): string {
  return `${module}:${targetId}`;
}

/**
 * 把勾选状态换算成节点最终的关联列表。
 * 已在节点上的关联原样保留，标签与创建时间都不重写；取消勾选的移除；
 * 新勾选的记录从候选里取标题后追加。候选未加载到的旧关联因此不会在保存时丢失。
 */
export function mergePlanLinks(planId: string, nodeId: string, existing: PlanLink[],
  candidates: LinkCandidate[], selectedKeys: string[]): PlanLink[] {
  const result: PlanLink[] = [];
  const taken: string[] = [];
  for (const link of existing) {
    const key = planLinkKey(link.module, link.targetId);
    if (selectedKeys.includes(key) && !taken.includes(key)) {
      result.push(link);
      taken.push(key);
    }
  }
  for (const key of selectedKeys) {
    if (taken.includes(key)) {
      continue;
    }
    const candidate = findCandidate(candidates, key);
    if (candidate !== null) {
      result.push(createPlanLink(planId, nodeId, candidate.module, candidate.targetId, candidate.title));
      taken.push(key);
    }
  }
  return result;
}

function findCandidate(candidates: LinkCandidate[], key: string): LinkCandidate | null {
  for (const item of candidates) {
    if (planLinkKey(item.module, item.targetId) === key) {
      return item;
    }
  }
  return null;
}
