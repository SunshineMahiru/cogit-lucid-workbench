import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DbHelper } from '../db/DbHelper';
import { PlanDao } from '../db/dao/PlanDao';
import { Plan } from '../model/Plan';
import { PlanProject } from '../model/PlanProject';
import { PlanNode } from '../model/PlanNode';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanNodeStatus, PlanStatus } from '../model/PlanStatus';
import {
  addPlanDays,
  createPlan,
  createPlanItem,
  createPlanLink,
  createPlanNode,
  createPlanProject
} from './PlanFactory';

/** Application service for plans and their seven-day nodes. */
export class PlanService {
  private dao: PlanDao;

  private constructor(store: relationalStore.RdbStore) {
    this.dao = new PlanDao(store);
  }

  static async open(context: common.Context): Promise<PlanService> {
    const store = await DbHelper.init(context);
    return new PlanService(store);
  }

  async listPlans(): Promise<Plan[]> {
    return this.dao.queryPlans();
  }

  async findPlan(id: string): Promise<Plan | null> {
    return this.dao.findPlan(id);
  }

  async primaryPlan(): Promise<Plan | null> {
    const plans = await this.dao.queryPlans();
    for (const plan of plans) {
      if (plan.isPrimary && plan.status === PlanStatus.ACTIVE) {
        return plan;
      }
    }
    return null;
  }

  /** Creates a goal; it becomes primary when no active primary goal exists. */
  async createPlan(title: string, startDate: string): Promise<Plan> {
    const existing = await this.dao.queryPlans();
    const plan = createPlan(title, startDate);
    plan.isPrimary = !this.hasActivePrimary(existing);
    await this.dao.insertPlan(plan);
    await this.createNextNode(plan.id);
    return plan;
  }

  async updatePlan(plan: Plan): Promise<void> {
    await this.dao.updatePlan(plan);
  }

  async setPrimary(id: string): Promise<void> {
    const plan = await this.dao.findPlan(id);
    if (plan === null || plan.status === PlanStatus.ARCHIVED) {
      return;
    }
    await this.dao.setPrimary(id);
  }

  async archive(id: string): Promise<void> {
    const plan = await this.dao.findPlan(id);
    if (plan === null) {
      return;
    }
    const wasPrimary = plan.isPrimary;
    plan.status = PlanStatus.ARCHIVED;
    plan.isPrimary = false;
    await this.dao.updatePlan(plan);
    if (wasPrimary) {
      await this.promoteFirstActive(id);
    }
  }

  async restore(id: string): Promise<void> {
    const plan = await this.dao.findPlan(id);
    if (plan === null) {
      return;
    }
    plan.status = PlanStatus.ACTIVE;
    const plans = await this.dao.queryPlans();
    if (!this.hasActivePrimary(plans)) {
      plan.isPrimary = true;
    }
    await this.dao.updatePlan(plan);
  }

  private hasActivePrimary(plans: Plan[]): boolean {
    for (const plan of plans) {
      if (plan.isPrimary && plan.status === PlanStatus.ACTIVE) {
        return true;
      }
    }
    return false;
  }

  private async promoteFirstActive(exceptId: string): Promise<void> {
    const plans = await this.dao.queryPlans();
    for (const plan of plans) {
      if (plan.id !== exceptId && plan.status === PlanStatus.ACTIVE) {
        await this.dao.setPrimary(plan.id);
        return;
      }
    }
  }

  async listProjects(planId: string): Promise<PlanProject[]> {
    return this.dao.queryProjects(planId);
  }

  async createProject(planId: string, name: string): Promise<PlanProject> {
    if (name.trim().length === 0) {
      throw new Error('project name required');
    }
    const existing = await this.dao.queryProjects(planId);
    const project = createPlanProject(planId, name, existing.length);
    await this.dao.insertProject(project);
    return project;
  }

  async listNodes(planId: string): Promise<PlanNode[]> {
    return this.dao.queryNodes(planId);
  }

  async findNode(nodeId: string): Promise<PlanNode | null> {
    return this.dao.findNode(nodeId);
  }

  async setNodeProject(nodeId: string, projectId: string): Promise<void> {
    await this.dao.setNodeProject(nodeId, projectId);
  }

  /** Returns the first node, creating it when the plan has none yet. */
  async ensureFirstNode(planId: string): Promise<PlanNode | null> {
    const nodes = await this.dao.queryNodes(planId);
    if (nodes.length > 0) {
      return nodes[0];
    }
    return this.createNextNode(planId);
  }

  /** Returns the latest open node, or the last node when every node is closed. */
  async currentNode(planId: string): Promise<PlanNode | null> {
    const nodes = await this.dao.queryNodes(planId);
    let latest: PlanNode | null = null;
    for (const node of nodes) {
      if (node.status === PlanNodeStatus.OPEN) {
        latest = node;
      }
    }
    if (latest === null && nodes.length > 0) {
      latest = nodes[nodes.length - 1];
    }
    return latest;
  }

  /**
   * Closes a node and appends the next week. Every unfinished item is copied
   * into the new node with carriedFrom pointing at the source item.
   */
  async closeNodeAndCarry(nodeId: string, reviewId: string = ''): Promise<PlanNode | null> {
    const node = await this.dao.findNode(nodeId);
    if (node === null || node.status === PlanNodeStatus.CLOSED) {
      return null;
    }
    await this.dao.closeNode(nodeId, reviewId);
    const nodes = await this.dao.queryNodes(node.planId);
    const next = createPlanNode(node.planId, nodes.length + 1, addPlanDays(node.startDate, 7), node.projectId);
    await this.dao.insertNode(next);
    const items = await this.dao.queryItems(nodeId);
    let order = 0;
    for (const item of items) {
      if (!item.done) {
        await this.dao.insertItem(createPlanItem(next.id, item.text, order, item.id));
        order += 1;
      }
    }
    return next;
  }

  /** Appends the next Monday-to-Sunday node to a plan. */
  async createNextNode(planId: string, projectId?: string): Promise<PlanNode | null> {
    const plan = await this.dao.findPlan(planId);
    if (plan === null) {
      return null;
    }
    const nodes = await this.dao.queryNodes(planId);
    const weekIndex = nodes.length + 1;
    const monday = addPlanDays(plan.startDate, (weekIndex - 1) * 7);
    const node = createPlanNode(planId, weekIndex, monday, projectId);
    await this.dao.insertNode(node);
    return node;
  }

  async listItems(nodeId: string): Promise<PlanItem[]> {
    return this.dao.queryItems(nodeId);
  }

  async addItem(nodeId: string, text: string): Promise<PlanItem | null> {
    if (text.trim().length === 0) {
      return null;
    }
    const existing = await this.dao.queryItems(nodeId);
    const item = createPlanItem(nodeId, text, existing.length);
    await this.dao.insertItem(item);
    return item;
  }

  async setItemDone(id: string, done: boolean): Promise<void> {
    await this.dao.setItemDone(id, done);
  }

  async removeItem(id: string): Promise<void> {
    await this.dao.deleteItem(id);
  }

  async listLinks(nodeId: string): Promise<PlanLink[]> {
    return this.dao.queryLinks(nodeId);
  }

  async addLink(planId: string, nodeId: string, module: PlanLinkModule,
    targetId: string, label: string): Promise<PlanLink> {
    const link = createPlanLink(planId, nodeId, module, targetId, label);
    await this.dao.insertLink(link);
    return link;
  }

  async removeLink(id: string): Promise<void> {
    await this.dao.deleteLink(id);
  }

  /** Replaces every link on one node atomically. */
  async replaceLinks(nodeId: string, links: PlanLink[]): Promise<void> {
    await this.dao.replaceLinks(nodeId, links);
  }
}
