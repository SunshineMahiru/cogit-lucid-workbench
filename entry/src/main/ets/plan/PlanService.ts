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
import { PlanStatus } from '../model/PlanStatus';
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

  /** Creates a goal; the first active goal becomes the primary one. */
  async createPlan(title: string, startDate: string): Promise<Plan> {
    const existing = await this.dao.queryPlans();
    const plan = createPlan(title, startDate);
    plan.isPrimary = existing.length === 0;
    await this.dao.insertPlan(plan);
    return plan;
  }

  async updatePlan(plan: Plan): Promise<void> {
    await this.dao.updatePlan(plan);
  }

  async setPrimary(id: string): Promise<void> {
    await this.dao.setPrimary(id);
  }

  async archive(id: string): Promise<void> {
    const plan = await this.dao.findPlan(id);
    if (plan === null) {
      return;
    }
    plan.status = PlanStatus.ARCHIVED;
    plan.isPrimary = false;
    await this.dao.updatePlan(plan);
  }

  async listProjects(planId: string): Promise<PlanProject[]> {
    return this.dao.queryProjects(planId);
  }

  async createProject(planId: string, name: string): Promise<PlanProject> {
    const existing = await this.dao.queryProjects(planId);
    const project = createPlanProject(planId, name, existing.length);
    await this.dao.insertProject(project);
    return project;
  }

  async listNodes(planId: string): Promise<PlanNode[]> {
    return this.dao.queryNodes(planId);
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
}
