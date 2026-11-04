import { Plan } from '../model/Plan';
import { PlanStatus } from '../model/PlanStatus';
import { createPlan } from '../plan/PlanFactory';

/** In-memory plans used only when the DevEco Previewer cannot open the database. */
class PlanPreviewStore {
  private plans: Plan[] = [];

  constructor() {
    const seed = createPlan('本周计划', '2026-11-02');
    seed.goal = '把计划模块接入首页，并跑通目标与周节点。';
    seed.isPrimary = true;
    this.plans.push(seed);
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
}

export const planPreviewStore = new PlanPreviewStore();
