import { Plan } from '../model/Plan';
import { PlanNode } from '../model/PlanNode';
import { PlanItem } from '../model/PlanItem';
import { PlanLink } from '../model/PlanLink';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanProject } from '../model/PlanProject';
import { PlanNodeStatus, PlanStatus } from '../model/PlanStatus';
import {
  addPlanDays,
  createPlan,
  createPlanItem,
  createPlanLink,
  createPlanNode,
  createPlanProject
} from '../plan/PlanFactory';

/** In-memory plans used only when the DevEco Previewer cannot open the database. */
class PlanPreviewStore {
  private plans: Plan[] = [];
  private planNodes: PlanNode[] = [];
  private planItems: PlanItem[] = [];
  private planLinks: PlanLink[] = [];
  private planProjects: PlanProject[] = [];

  constructor() {
    const seed = createPlan('本周计划', '2026-11-02');
    seed.goal = '把计划模块接入首页，并跑通目标与周节点。';
    seed.isPrimary = true;
    this.plans.push(seed);
    const node = createPlanNode(seed.id, 1, seed.startDate);
    this.planNodes.push(node);
    this.planItems.push(createPlanItem(node.id, '把计划卡放进首页内容', 0));
    const second = createPlanItem(node.id, '补七日节点与清单', 1);
    second.done = true;
    this.planItems.push(second);
  }

  list(): Plan[] {
    return this.plans.slice();
  }

  primary(): Plan | null {
    for (const plan of this.plans) {
      if (plan.isPrimary && plan.status === PlanStatus.ACTIVE) {
        return plan;
      }
    }
    return null;
  }

  find(id: string): Plan | null {
    for (const plan of this.plans) {
      if (plan.id === id) {
        return plan;
      }
    }
    return null;
  }

  create(title: string, startDate: string): Plan {
    const plan = createPlan(title, startDate);
    plan.isPrimary = this.plans.length === 0;
    this.plans.push(plan);
    this.planNodes.push(createPlanNode(plan.id, 1, plan.startDate));
    return plan;
  }

  update(plan: Plan): void {
    for (let index = 0; index < this.plans.length; index += 1) {
      if (this.plans[index].id === plan.id) {
        this.plans[index] = plan;
        return;
      }
    }
  }

  setPrimary(id: string): void {
    for (const plan of this.plans) {
      plan.isPrimary = plan.id === id;
    }
  }

  projects(planId: string): PlanProject[] {
    const rows: PlanProject[] = [];
    for (const project of this.planProjects) {
      if (project.planId === planId) {
        rows.push(project);
      }
    }
    return rows;
  }

  createProject(planId: string, name: string): PlanProject {
    const project = createPlanProject(planId, name, this.projects(planId).length);
    this.planProjects.push(project);
    return project;
  }

  renameProject(projectId: string, name: string): void {
    for (const project of this.planProjects) {
      if (project.id === projectId) {
        project.name = name;
        return;
      }
    }
  }

  deleteProject(planId: string, projectId: string): void {
    for (const node of this.planNodes) {
      if (node.planId === planId && node.projectId === projectId) {
        node.projectId = '';
      }
    }
    const rows: PlanProject[] = [];
    for (const project of this.planProjects) {
      if (project.id !== projectId) {
        rows.push(project);
      }
    }
    this.planProjects = rows;
  }

  archive(id: string): void {
    const plan = this.find(id);
    if (plan !== null) {
      plan.status = PlanStatus.ARCHIVED;
      plan.isPrimary = false;
    }
  }

  restore(id: string): void {
    const plan = this.find(id);
    if (plan !== null) {
      plan.status = PlanStatus.ACTIVE;
      if (this.primary() === null) {
        plan.isPrimary = true;
      }
    }
  }

  nodes(planId: string): PlanNode[] {
    const rows: PlanNode[] = [];
    for (const node of this.planNodes) {
      if (node.planId === planId) {
        rows.push(node);
      }
    }
    return rows;
  }

  findNode(id: string): PlanNode | null {
    for (const node of this.planNodes) {
      if (node.id === id) {
        return node;
      }
    }
    return null;
  }

  setNodeProject(nodeId: string, projectId: string): void {
    const node = this.findNode(nodeId);
    if (node !== null) {
      node.projectId = projectId;
    }
  }

  ensureFirstNode(planId: string): PlanNode | null {
    const plan = this.find(planId);
    if (plan === null) {
      return null;
    }
    const existing = this.nodes(planId);
    if (existing.length > 0) {
      return existing[0];
    }
    const node = createPlanNode(planId, 1, plan.startDate);
    this.planNodes.push(node);
    return node;
  }

  listItems(nodeId: string): PlanItem[] {
    const rows: PlanItem[] = [];
    for (const item of this.planItems) {
      if (item.nodeId === nodeId) {
        rows.push(item);
      }
    }
    return rows;
  }

  addItem(nodeId: string, text: string): PlanItem | null {
    if (text.trim().length === 0) {
      return null;
    }
    const item = createPlanItem(nodeId, text, this.listItems(nodeId).length);
    this.planItems.push(item);
    return item;
  }

  setItemDone(id: string, done: boolean): void {
    for (const item of this.planItems) {
      if (item.id === id) {
        item.done = done;
        return;
      }
    }
  }

  removeItem(id: string): void {
    const rows: PlanItem[] = [];
    for (const item of this.planItems) {
      if (item.id !== id) {
        rows.push(item);
      }
    }
    this.planItems = rows;
  }

  links(nodeId: string): PlanLink[] {
    const rows: PlanLink[] = [];
    for (const link of this.planLinks) {
      if (link.nodeId === nodeId) {
        rows.push(link);
      }
    }
    return rows;
  }

  clearLinks(nodeId: string): void {
    const rows: PlanLink[] = [];
    for (const link of this.planLinks) {
      if (link.nodeId !== nodeId) {
        rows.push(link);
      }
    }
    this.planLinks = rows;
  }

  /** Replaces every node that points at one record. */
  replaceLinksForTarget(module: PlanLinkModule, targetId: string, links: PlanLink[]): void {
    const rows: PlanLink[] = [];
    for (const link of this.planLinks) {
      if (link.module !== module || link.targetId !== targetId) {
        rows.push(link);
      }
    }
    for (const link of links) {
      rows.push(link);
    }
    this.planLinks = rows;
  }

  addLink(planId: string, nodeId: string, module: PlanLinkModule, targetId: string, label: string): void {
    this.planLinks.push(createPlanLink(planId, nodeId, module, targetId, label));
  }

  /** Closes one node, appends the next week and copies every unfinished item. */
  closeAndCarry(nodeId: string): PlanNode | null {
    const node = this.findNode(nodeId);
    if (node === null || node.status === PlanNodeStatus.CLOSED) {
      return null;
    }
    node.status = PlanNodeStatus.CLOSED;
    const next = createPlanNode(node.planId, node.weekIndex + 1, addPlanDays(node.startDate, 7), node.projectId);
    this.planNodes.push(next);
    const pending = this.listItems(nodeId);
    let order = 0;
    for (const item of pending) {
      if (!item.done) {
        this.planItems.push(createPlanItem(next.id, item.text, order, item.id));
        order += 1;
      }
    }
    return next;
  }
}

export const planPreviewStore = new PlanPreviewStore();
