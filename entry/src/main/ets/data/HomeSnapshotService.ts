import { common } from '@kit.AbilityKit';
import { HomeDataService } from './HomeDataService';
import { HomeSnapshot } from '../model/HomeSnapshot';
import { BodyReading, HomeSummary } from '../model/HomeModel';
import { NoteListItem } from '../note/NoteListItem';
import { buildAgenda } from '../home/AgendaMapper';
import { Plan } from '../model/Plan';
import { PlanItem } from '../model/PlanItem';
import { PlanNode } from '../model/PlanNode';
import { PlanNodeStatus, PlanStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { PredictionService } from '../prediction';
import { PredictionListItem } from '../prediction/PredictionListItem';
import { RelationService } from '../relation';
import { RelationListItem } from '../relation/RelationListItem';

/** All-zero summary used before the first read and when the summary read fails. */
function emptySummary(): HomeSummary {
  return {
    totalNotes: 0,
    todayNotes: 0,
    totalPredictions: 0,
    pendingPredictions: 0,
    settledPredictions: 0,
    hitRate: 0,
    unreviewedDecisions: 0,
    totalAnchors: 0,
    totalRelations: 0,
    duePredictions: 0,
    revisionPredictions: 0,
    closedNodeReviews: 0,
    pendingDecisions: 0
  };
}

/**
 * Reads everything the workbench and the drawer display in one call: body readings, recent notes,
 * the home summary, today's agenda and the plan node counts. Each source is read on its own, so a
 * single failure keeps whatever was already loaded and only marks the snapshot as partial.
 */
export class HomeSnapshotService {
  private home: HomeDataService;
  private context: common.Context;

  private constructor(home: HomeDataService, context: common.Context) {
    this.home = home;
    this.context = context;
  }

  /** Opens the underlying database; a failure here is a hard failure for the caller. */
  static async open(context: common.Context): Promise<HomeSnapshotService> {
    const home = await HomeDataService.open(context);
    return new HomeSnapshotService(home, context);
  }

  /** Composes one snapshot; never throws for a single failed source. */
  async load(): Promise<HomeSnapshot> {
    const snapshot: HomeSnapshot = {
      readings: [],
      recentNotes: [],
      summary: emptySummary(),
      summaryAvailable: false,
      agenda: [],
      agendaPending: 0,
      agendaReply: 0,
      planOpenCount: 0,
      planNodeCount: 0,
      agendaAvailable: false,
      partial: false
    };

    try {
      const readings: BodyReading[] = await this.home.loadReadings();
      snapshot.readings = readings;
    } catch (error) {
      snapshot.partial = true;
    }
    try {
      const recentNotes: NoteListItem[] = await this.home.loadRecentNotes(20);
      snapshot.recentNotes = recentNotes;
    } catch (error) {
      snapshot.partial = true;
    }
    try {
      snapshot.summary = await this.home.loadSummary();
      snapshot.summaryAvailable = true;
    } catch (error) {
      snapshot.partial = true;
    }

    await this.loadAgenda(snapshot);
    return snapshot;
  }

  /** Plans, predictions and relations feed the agenda and the two node counters. */
  private async loadAgenda(snapshot: HomeSnapshot): Promise<void> {
    const plans: Plan[] = [];
    const nodes: PlanNode[] = [];
    const items: PlanItem[] = [];
    let plansOk: boolean = true;
    try {
      const planService = await PlanService.open(this.context);
      const allPlans: Plan[] = await planService.listPlans();
      for (const plan of allPlans) {
        plans.push(plan);
      }
      for (const plan of plans) {
        if (plan.status !== PlanStatus.ACTIVE) {
          continue;
        }
        const planNodes: PlanNode[] = await planService.listNodes(plan.id);
        for (const node of planNodes) {
          nodes.push(node);
          const nodeItems: PlanItem[] = await planService.listItems(node.id);
          for (const item of nodeItems) {
            items.push(item);
          }
        }
      }
      snapshot.planNodeCount = nodes.length;
      snapshot.planOpenCount = nodes.filter((node: PlanNode) => node.status === PlanNodeStatus.OPEN).length;
    } catch (error) {
      plansOk = false;
      snapshot.partial = true;
    }

    let predictions: PredictionListItem[] = [];
    let predictionsOk: boolean = true;
    try {
      const predictionService = await PredictionService.open(this.context);
      predictions = await predictionService.list(null);
    } catch (error) {
      predictionsOk = false;
      snapshot.partial = true;
    }

    let relations: RelationListItem[] = [];
    let relationsOk: boolean = true;
    try {
      const relationService = await RelationService.open(this.context);
      relations = await relationService.list(null);
    } catch (error) {
      relationsOk = false;
      snapshot.partial = true;
    }

    try {
      const result = buildAgenda({
        plans: plans,
        nodes: nodes,
        items: items,
        predictions: predictions,
        relations: relations,
        todayNotes: snapshot.recentNotes
      });
      snapshot.agenda = result.items;
      snapshot.agendaPending = result.pendingCount;
      snapshot.agendaReply = result.replyCount;
      snapshot.agendaAvailable = plansOk && predictionsOk && relationsOk;
    } catch (error) {
      snapshot.agendaAvailable = false;
      snapshot.partial = true;
    }
  }
}