import { relationalStore } from '@kit.ArkData';
import { Plan } from '../../model/Plan';
import { PlanProject } from '../../model/PlanProject';
import { PlanNode } from '../../model/PlanNode';
import { PlanItem } from '../../model/PlanItem';
import { PlanLink } from '../../model/PlanLink';
import { PlanLinkModule } from '../../model/PlanLinkModule';
import { PlanNodeStatus, PlanProjectStatus, PlanStatus } from '../../model/PlanStatus';
import { SecurityLevel } from '../../model/SecurityLevel';
import {
  DB_TABLES,
  PLAN_COLS,
  PLAN_PROJECT_COLS,
  PLAN_NODE_COLS,
  PLAN_ITEM_COLS,
  PLAN_LINK_COLS
} from '../DbConstants';

/** Data access for plans, projects, seven-day nodes, checklist items and record links. */
export class PlanDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  async insertPlan(plan: Plan): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_COLS.ID]: plan.id,
      [PLAN_COLS.TITLE]: plan.title,
      [PLAN_COLS.GOAL]: plan.goal,
      [PLAN_COLS.PROJECT_ID]: plan.projectId ?? '',
      [PLAN_COLS.START_DATE]: plan.startDate,
      [PLAN_COLS.STATUS]: plan.status,
      [PLAN_COLS.IS_PRIMARY]: plan.isPrimary ? 1 : 0,
      [PLAN_COLS.LEVEL]: plan.level ?? SecurityLevel.LOCAL_ONLY,
      [PLAN_COLS.CREATED_AT]: plan.createdAt
    };
    return this.store.insert(DB_TABLES.PLAN, values);
  }

  /** Inserts a goal together with its first week inside one transaction. */
  async insertPlanWithFirstNode(plan: Plan, node: PlanNode): Promise<void> {
    this.store.beginTransaction();
    try {
      await this.insertPlan(plan);
      await this.insertNode(node);
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
  }

  async updatePlan(plan: Plan): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_COLS.TITLE]: plan.title,
      [PLAN_COLS.GOAL]: plan.goal,
      [PLAN_COLS.PROJECT_ID]: plan.projectId ?? '',
      [PLAN_COLS.START_DATE]: plan.startDate,
      [PLAN_COLS.STATUS]: plan.status,
      [PLAN_COLS.IS_PRIMARY]: plan.isPrimary ? 1 : 0,
      [PLAN_COLS.LEVEL]: plan.level ?? SecurityLevel.LOCAL_ONLY
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN);
    predicates.equalTo(PLAN_COLS.ID, plan.id);
    return this.store.update(values, predicates);
  }

  async queryPlans(): Promise<Plan[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN);
    predicates.orderByDesc(PLAN_COLS.IS_PRIMARY);
    predicates.orderByDesc(PLAN_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const rows: Plan[] = [];
      while (resultSet.goToNextRow()) {
        rows.push(this.mapPlan(resultSet));
      }
      return rows;
    } finally {
      resultSet.close();
    }
  }

  async findPlan(id: string): Promise<Plan | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN);
    predicates.equalTo(PLAN_COLS.ID, id);
    const resultSet = await this.store.query(predicates);
    try {
      return resultSet.goToFirstRow() ? this.mapPlan(resultSet) : null;
    } finally {
      resultSet.close();
    }
  }

  /** Clears the old primary goal before setting the new one. */
  async setPrimary(id: string): Promise<void> {
    const clear: relationalStore.ValuesBucket = { [PLAN_COLS.IS_PRIMARY]: 0 };
    const all = new relationalStore.RdbPredicates(DB_TABLES.PLAN);
    await this.store.update(clear, all);
    const one: relationalStore.ValuesBucket = { [PLAN_COLS.IS_PRIMARY]: 1 };
    const target = new relationalStore.RdbPredicates(DB_TABLES.PLAN);
    target.equalTo(PLAN_COLS.ID, id);
    await this.store.update(one, target);
  }

  async insertProject(project: PlanProject): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_PROJECT_COLS.ID]: project.id,
      [PLAN_PROJECT_COLS.PLAN_ID]: project.planId,
      [PLAN_PROJECT_COLS.NAME]: project.name,
      [PLAN_PROJECT_COLS.GOAL]: project.goal,
      [PLAN_PROJECT_COLS.STATUS]: project.status,
      [PLAN_PROJECT_COLS.SORT_ORDER]: project.sortOrder
    };
    return this.store.insert(DB_TABLES.PLAN_PROJECT, values);
  }

  async queryProjects(planId: string): Promise<PlanProject[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_PROJECT);
    predicates.equalTo(PLAN_PROJECT_COLS.PLAN_ID, planId);
    predicates.orderByAsc(PLAN_PROJECT_COLS.SORT_ORDER);
    const resultSet = await this.store.query(predicates);
    try {
      const rows: PlanProject[] = [];
      while (resultSet.goToNextRow()) {
        rows.push(this.mapProject(resultSet));
      }
      return rows;
    } finally {
      resultSet.close();
    }
  }

  async renameProject(id: string, name: string): Promise<number> {
    const values: relationalStore.ValuesBucket = { [PLAN_PROJECT_COLS.NAME]: name };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_PROJECT);
    predicates.equalTo(PLAN_PROJECT_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  /** Deletes one project and unlinks its nodes inside a transaction; nodes and items stay. */
  async deleteProject(planId: string, projectId: string): Promise<void> {
    this.store.beginTransaction();
    try {
      const clear: relationalStore.ValuesBucket = { [PLAN_NODE_COLS.PROJECT_ID]: '' };
      const nodes = new relationalStore.RdbPredicates(DB_TABLES.PLAN_NODE);
      nodes.equalTo(PLAN_NODE_COLS.PLAN_ID, planId);
      nodes.equalTo(PLAN_NODE_COLS.PROJECT_ID, projectId);
      await this.store.update(clear, nodes);
      const target = new relationalStore.RdbPredicates(DB_TABLES.PLAN_PROJECT);
      target.equalTo(PLAN_PROJECT_COLS.ID, projectId);
      await this.store.delete(target);
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
  }

  async insertNode(node: PlanNode): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_NODE_COLS.ID]: node.id,
      [PLAN_NODE_COLS.PLAN_ID]: node.planId,
      [PLAN_NODE_COLS.PROJECT_ID]: node.projectId ?? '',
      [PLAN_NODE_COLS.WEEK_INDEX]: node.weekIndex,
      [PLAN_NODE_COLS.START_DATE]: node.startDate,
      [PLAN_NODE_COLS.END_DATE]: node.endDate,
      [PLAN_NODE_COLS.STATUS]: node.status,
      [PLAN_NODE_COLS.REVIEW_ID]: node.reviewId ?? ''
    };
    return this.store.insert(DB_TABLES.PLAN_NODE, values);
  }

  async queryNodes(planId: string): Promise<PlanNode[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_NODE);
    predicates.equalTo(PLAN_NODE_COLS.PLAN_ID, planId);
    predicates.orderByAsc(PLAN_NODE_COLS.WEEK_INDEX);
    const resultSet = await this.store.query(predicates);
    try {
      const rows: PlanNode[] = [];
      while (resultSet.goToNextRow()) {
        rows.push(this.mapNode(resultSet));
      }
      return rows;
    } finally {
      resultSet.close();
    }
  }

  async findNode(id: string): Promise<PlanNode | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_NODE);
    predicates.equalTo(PLAN_NODE_COLS.ID, id);
    const resultSet = await this.store.query(predicates);
    try {
      return resultSet.goToFirstRow() ? this.mapNode(resultSet) : null;
    } finally {
      resultSet.close();
    }
  }

  async setNodeProject(id: string, projectId: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_NODE_COLS.PROJECT_ID]: projectId
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_NODE);
    predicates.equalTo(PLAN_NODE_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  async closeNode(id: string, reviewId: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_NODE_COLS.STATUS]: PlanNodeStatus.CLOSED,
      [PLAN_NODE_COLS.REVIEW_ID]: reviewId
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_NODE);
    predicates.equalTo(PLAN_NODE_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  async insertItem(item: PlanItem): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_ITEM_COLS.ID]: item.id,
      [PLAN_ITEM_COLS.NODE_ID]: item.nodeId,
      [PLAN_ITEM_COLS.TEXT]: item.text,
      [PLAN_ITEM_COLS.DONE]: item.done ? 1 : 0,
      [PLAN_ITEM_COLS.CARRIED_FROM]: item.carriedFrom ?? '',
      [PLAN_ITEM_COLS.SORT_ORDER]: item.sortOrder,
      [PLAN_ITEM_COLS.LEVEL]: item.level ?? SecurityLevel.LOCAL_ONLY
    };
    return this.store.insert(DB_TABLES.PLAN_ITEM, values);
  }

  async queryItems(nodeId: string): Promise<PlanItem[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_ITEM);
    predicates.equalTo(PLAN_ITEM_COLS.NODE_ID, nodeId);
    predicates.orderByAsc(PLAN_ITEM_COLS.SORT_ORDER);
    const resultSet = await this.store.query(predicates);
    try {
      const rows: PlanItem[] = [];
      while (resultSet.goToNextRow()) {
        rows.push(this.mapItem(resultSet));
      }
      return rows;
    } finally {
      resultSet.close();
    }
  }

  async setItemDone(id: string, done: boolean): Promise<number> {
    const values: relationalStore.ValuesBucket = { [PLAN_ITEM_COLS.DONE]: done ? 1 : 0 };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_ITEM);
    predicates.equalTo(PLAN_ITEM_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  async deleteItem(id: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_ITEM);
    predicates.equalTo(PLAN_ITEM_COLS.ID, id);
    return this.store.delete(predicates);
  }

  async insertLink(link: PlanLink): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PLAN_LINK_COLS.ID]: link.id,
      [PLAN_LINK_COLS.PLAN_ID]: link.planId,
      [PLAN_LINK_COLS.NODE_ID]: link.nodeId ?? '',
      [PLAN_LINK_COLS.MODULE]: link.module,
      [PLAN_LINK_COLS.TARGET_ID]: link.targetId,
      [PLAN_LINK_COLS.LABEL]: link.label,
      [PLAN_LINK_COLS.CREATED_AT]: link.createdAt
    };
    return this.store.insert(DB_TABLES.PLAN_LINK, values);
  }

  async queryLinks(nodeId: string): Promise<PlanLink[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_LINK);
    predicates.equalTo(PLAN_LINK_COLS.NODE_ID, nodeId);
    predicates.orderByDesc(PLAN_LINK_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const rows: PlanLink[] = [];
      while (resultSet.goToNextRow()) {
        rows.push(this.mapLink(resultSet));
      }
      return rows;
    } finally {
      resultSet.close();
    }
  }

  async queryLinksByPlan(planId: string): Promise<PlanLink[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_LINK);
    predicates.equalTo(PLAN_LINK_COLS.PLAN_ID, planId);
    predicates.orderByDesc(PLAN_LINK_COLS.CREATED_AT);
    const resultSet = await this.store.query(predicates);
    try {
      const rows: PlanLink[] = [];
      while (resultSet.goToNextRow()) {
        rows.push(this.mapLink(resultSet));
      }
      return rows;
    } finally {
      resultSet.close();
    }
  }

  async queryLinksByTarget(module: string, targetId: string): Promise<PlanLink[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_LINK);
    predicates.equalTo(PLAN_LINK_COLS.MODULE, module);
    predicates.equalTo(PLAN_LINK_COLS.TARGET_ID, targetId);
    const resultSet = await this.store.query(predicates);
    try {
      const rows: PlanLink[] = [];
      while (resultSet.goToNextRow()) {
        rows.push(this.mapLink(resultSet));
      }
      return rows;
    } finally {
      resultSet.close();
    }
  }

  /** Replaces every link that points at one record inside a transaction, so retries cannot duplicate rows. */
  async replaceLinksByTarget(module: string, targetId: string, links: PlanLink[]): Promise<void> {
    this.store.beginTransaction();
    try {
      const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_LINK);
      predicates.equalTo(PLAN_LINK_COLS.MODULE, module);
      predicates.equalTo(PLAN_LINK_COLS.TARGET_ID, targetId);
      await this.store.delete(predicates);
      for (const link of links) {
        await this.insertLink(link);
      }
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
  }

  /** Replaces every link on one node inside a transaction, so a failure keeps the old set. */
  async replaceLinks(nodeId: string, links: PlanLink[]): Promise<void> {
    this.store.beginTransaction();
    try {
      const predicates = new relationalStore.RdbPredicates(DB_TABLES.PLAN_LINK);
      predicates.equalTo(PLAN_LINK_COLS.NODE_ID, nodeId);
      await this.store.delete(predicates);
      for (const link of links) {
        await this.insertLink(link);
      }
      this.store.commit();
    } catch (error) {
      this.store.rollBack();
      throw error;
    }
  }

  private mapPlan(resultSet: relationalStore.ResultSet): Plan {
    const projectId = resultSet.getString(resultSet.getColumnIndex(PLAN_COLS.PROJECT_ID));
    const plan: Plan = {
      id: resultSet.getString(resultSet.getColumnIndex(PLAN_COLS.ID)),
      title: resultSet.getString(resultSet.getColumnIndex(PLAN_COLS.TITLE)),
      goal: resultSet.getString(resultSet.getColumnIndex(PLAN_COLS.GOAL)),
      startDate: resultSet.getString(resultSet.getColumnIndex(PLAN_COLS.START_DATE)),
      status: resultSet.getString(resultSet.getColumnIndex(PLAN_COLS.STATUS)) as PlanStatus,
      isPrimary: resultSet.getLong(resultSet.getColumnIndex(PLAN_COLS.IS_PRIMARY)) === 1,
      level: resultSet.getString(resultSet.getColumnIndex(PLAN_COLS.LEVEL)) as SecurityLevel,
      createdAt: resultSet.getLong(resultSet.getColumnIndex(PLAN_COLS.CREATED_AT))
    };
    if (projectId.length > 0) {
      plan.projectId = projectId;
    }
    return plan;
  }

  private mapProject(resultSet: relationalStore.ResultSet): PlanProject {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(PLAN_PROJECT_COLS.ID)),
      planId: resultSet.getString(resultSet.getColumnIndex(PLAN_PROJECT_COLS.PLAN_ID)),
      name: resultSet.getString(resultSet.getColumnIndex(PLAN_PROJECT_COLS.NAME)),
      goal: resultSet.getString(resultSet.getColumnIndex(PLAN_PROJECT_COLS.GOAL)),
      status: resultSet.getString(resultSet.getColumnIndex(PLAN_PROJECT_COLS.STATUS)) as PlanProjectStatus,
      sortOrder: resultSet.getLong(resultSet.getColumnIndex(PLAN_PROJECT_COLS.SORT_ORDER))
    };
  }

  private mapNode(resultSet: relationalStore.ResultSet): PlanNode {
    const projectId = resultSet.getString(resultSet.getColumnIndex(PLAN_NODE_COLS.PROJECT_ID));
    const reviewId = resultSet.getString(resultSet.getColumnIndex(PLAN_NODE_COLS.REVIEW_ID));
    const node: PlanNode = {
      id: resultSet.getString(resultSet.getColumnIndex(PLAN_NODE_COLS.ID)),
      planId: resultSet.getString(resultSet.getColumnIndex(PLAN_NODE_COLS.PLAN_ID)),
      weekIndex: resultSet.getLong(resultSet.getColumnIndex(PLAN_NODE_COLS.WEEK_INDEX)),
      startDate: resultSet.getString(resultSet.getColumnIndex(PLAN_NODE_COLS.START_DATE)),
      endDate: resultSet.getString(resultSet.getColumnIndex(PLAN_NODE_COLS.END_DATE)),
      status: resultSet.getString(resultSet.getColumnIndex(PLAN_NODE_COLS.STATUS)) as PlanNodeStatus
    };
    if (projectId.length > 0) {
      node.projectId = projectId;
    }
    if (reviewId.length > 0) {
      node.reviewId = reviewId;
    }
    return node;
  }

  private mapItem(resultSet: relationalStore.ResultSet): PlanItem {
    const carriedFrom = resultSet.getString(resultSet.getColumnIndex(PLAN_ITEM_COLS.CARRIED_FROM));
    const item: PlanItem = {
      id: resultSet.getString(resultSet.getColumnIndex(PLAN_ITEM_COLS.ID)),
      nodeId: resultSet.getString(resultSet.getColumnIndex(PLAN_ITEM_COLS.NODE_ID)),
      text: resultSet.getString(resultSet.getColumnIndex(PLAN_ITEM_COLS.TEXT)),
      done: resultSet.getLong(resultSet.getColumnIndex(PLAN_ITEM_COLS.DONE)) === 1,
      sortOrder: resultSet.getLong(resultSet.getColumnIndex(PLAN_ITEM_COLS.SORT_ORDER)),
      level: resultSet.getString(resultSet.getColumnIndex(PLAN_ITEM_COLS.LEVEL)) as SecurityLevel
    };
    if (carriedFrom.length > 0) {
      item.carriedFrom = carriedFrom;
    }
    return item;
  }

  private mapLink(resultSet: relationalStore.ResultSet): PlanLink {
    const nodeId = resultSet.getString(resultSet.getColumnIndex(PLAN_LINK_COLS.NODE_ID));
    const link: PlanLink = {
      id: resultSet.getString(resultSet.getColumnIndex(PLAN_LINK_COLS.ID)),
      planId: resultSet.getString(resultSet.getColumnIndex(PLAN_LINK_COLS.PLAN_ID)),
      module: resultSet.getString(resultSet.getColumnIndex(PLAN_LINK_COLS.MODULE)) as PlanLinkModule,
      targetId: resultSet.getString(resultSet.getColumnIndex(PLAN_LINK_COLS.TARGET_ID)),
      label: resultSet.getString(resultSet.getColumnIndex(PLAN_LINK_COLS.LABEL)),
      createdAt: resultSet.getLong(resultSet.getColumnIndex(PLAN_LINK_COLS.CREATED_AT))
    };
    if (nodeId.length > 0) {
      link.nodeId = nodeId;
    }
    return link;
  }
}
