import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../db/DbHelper';
import { AnchorDao } from '../db/dao/AnchorDao';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { RelationDao } from '../db/dao/RelationDao';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { Prediction } from './Prediction';
import { PredictionStatus } from './PredictionStatus';
import { StatusRecord } from './StatusRecord';
import { BodyReading, PredictionItem, HomeSummary } from './HomeModel';
import { NoteListItem } from '../note/NoteListItem';
import { toNoteListItems } from '../note/NoteListMapper';

/** Loads home page data from the database, replacing mock data. */
export class HomeDataService {
  private store: relationalStore.RdbStore;
  private eventDao: EventDao;
  private decisionDao: DecisionDao;
  private relationDao: RelationDao;
  private predictionDao: PredictionDao;
  private anchorDao: AnchorDao;
  private statusRecordDao: StatusRecordDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.relationDao = new RelationDao(store);
    this.predictionDao = new PredictionDao(store);
    this.anchorDao = new AnchorDao(store);
    this.statusRecordDao = new StatusRecordDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: Context): Promise<HomeDataService> {
    const store = await DbHelper.init(context);
    return new HomeDataService(store);
  }

  /** Returns today's body readings: sleep, exercise, note count. */
  async loadReadings(): Promise<BodyReading[]> {
    const today = formatDate(new Date());
    const status = await this.statusRecordDao.queryByDate(today);
    const recentEvents = await this.eventDao.queryRecent(100);
    const todayEvents = recentEvents.filter(e => formatDate(new Date(e.timestamp)) === today);

    const readings: BodyReading[] = [
      { label: '睡眠', value: status ? String(status.sleepHours) : '--', unit: ' 小时' },
      { label: '运动', value: status ? String(status.exerciseCount) : '--', unit: ' 次' },
      { label: '速记', value: String(todayEvents.length), unit: ' 条' }
    ];
    return readings;
  }

  /** Returns pending predictions for the home list. */
  async loadPendingPredictions(): Promise<PredictionItem[]> {
    const all = await this.predictionDao.queryAll();
    const pending = all.filter(p => p.status === PredictionStatus.PENDING);
    return pending.map(p => ({
      id: p.id,
      title: p.target,
      confidence: p.confidence,
      dueDate: p.settlementDate
    }));
  }

  /** Returns the most recent notes for the home list. */
  async loadRecentNotes(limit: number = 5): Promise<NoteListItem[]> {
    const events = await this.eventDao.queryRecent(limit);
    return toNoteListItems(events);
  }

  /** Returns summary statistics for the dashboard. */
  async loadSummary(): Promise<HomeSummary> {
    const allEvents = await this.eventDao.queryAll();
    const allDecisions = await this.decisionDao.queryAll();
    const allRelations = await this.relationDao.queryAll();
    const allPredictions = await this.predictionDao.queryAll();
    const allAnchors = await this.anchorDao.queryAll();
    const pending = allPredictions.filter(p => p.status === PredictionStatus.PENDING);
    const settled = allPredictions.filter(p => p.status === PredictionStatus.SETTLED);
    const hits = settled.filter(p => p.hit === true);
    const hitRate = settled.length > 0 ? Math.round(hits.length / settled.length * 100) : 0;
    return {
      totalNotes: allEvents.length,
      totalPredictions: allPredictions.length,
      pendingPredictions: pending.length,
      settledPredictions: settled.length,
      hitRate: hitRate,
      unreviewedDecisions: allDecisions.filter(d => !d.reviewed).length,
      totalAnchors: allAnchors.length,
      totalRelations: allRelations.length
    };
  }
}

function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}