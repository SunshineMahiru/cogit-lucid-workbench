import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DbHelper } from '../db/DbHelper';
import { AnchorDao } from '../db/dao/AnchorDao';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { RelationDao } from '../db/dao/RelationDao';
import { ReviewResultDao } from '../db/dao/ReviewResultDao';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { Prediction } from '../model/Prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { StatusRecord } from '../model/StatusRecord';
import { BodyReading, PredictionItem, HomePulse, HomeSummary, NO_RATE_TEXT } from '../model/HomeModel';
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
  private reviewDao: ReviewResultDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.relationDao = new RelationDao(store);
    this.predictionDao = new PredictionDao(store);
    this.anchorDao = new AnchorDao(store);
    this.statusRecordDao = new StatusRecordDao(store);
    this.reviewDao = new ReviewResultDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<HomeDataService> {
    const store = await DbHelper.init(context);
    return new HomeDataService(store);
  }

  /** Returns today's body readings: sleep, exercise, note count. */
  async loadReadings(): Promise<BodyReading[]> {
    const today = formatDate(new Date());
    const status = await this.statusRecordDao.queryByDate(today);
    const visibleStatus = status === null || status.level === SecurityLevel.SEALED ? null : status;
    const todayCount = await this.eventDao.countVisibleOn(today);

    const readings: BodyReading[] = [
      { label: '睡眠', value: visibleStatus ? String(visibleStatus.sleepHours) : '--', unit: ' 小时' },
      { label: '运动', value: visibleStatus ? String(visibleStatus.exerciseCount) : '--', unit: ' 次' },
      { label: '速记', value: String(todayCount), unit: ' 条' }
    ];
    return readings;
  }

  /** Returns pending predictions for the home list. */
  async loadPendingPredictions(): Promise<PredictionItem[]> {
    const all = await this.predictionDao.queryAll();
    const pending = all.filter(p =>
      p.status === PredictionStatus.PENDING && p.level !== SecurityLevel.SEALED);
    pending.sort((left, right) => left.settlementDate < right.settlementDate ? -1 : 1);
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
    const totalNotes = await this.eventDao.countVisible();
    const today = formatDate(new Date());
    const todayNotes = await this.eventDao.countVisibleOn(today);
    const unreviewedDecisions = await this.decisionDao.countUnreviewed();
    const totalRelations = await this.relationDao.countVisible();
    const allPredictions = (await this.predictionDao.queryAll()).filter(p => p.level !== SecurityLevel.SEALED);
    const totalAnchors = await this.anchorDao.countVisible();
    const pending = allPredictions.filter(p => p.status === PredictionStatus.PENDING);
    const settled = allPredictions.filter(p => p.status === PredictionStatus.SETTLED);
    const hits = settled.filter(p => p.hit === true);
    const hitRate = settled.length > 0 ? Math.round(hits.length / settled.length * 100) : 0;
    return {
      totalNotes: totalNotes,
      todayNotes: todayNotes,
      totalPredictions: allPredictions.length,
      pendingPredictions: pending.length,
      settledPredictions: settled.length,
      hitRate: hitRate,
      unreviewedDecisions: unreviewedDecisions,
      totalAnchors: totalAnchors,
      totalRelations: totalRelations
    };
  }

  /** Counts consecutive record days and finds the latest review for the home header. */
  async loadPulse(): Promise<HomePulse> {
    const events = (await this.eventDao.queryAll()).filter(e => e.level !== SecurityLevel.SEALED);
    const days: string[] = [];
    for (const event of events) {
      const day = formatDate(new Date(event.timestamp));
      if (!days.includes(day)) {
        days.push(day);
      }
    }
    let streakDays = 0;
    const cursor = new Date();
    if (!days.includes(formatDate(cursor))) {
      cursor.setDate(cursor.getDate() - 1);
    }
    while (days.includes(formatDate(cursor))) {
      streakDays += 1;
      cursor.setDate(cursor.getDate() - 1);
    }
    const reviews = await this.reviewDao.queryRecent(1);
    const lastReviewLabel = reviews.length > 0 ? formatMonthDay(new Date(reviews[0].createdAt)) : NO_RATE_TEXT;
    const pulse: HomePulse = {
      streakDays: streakDays,
      lastReviewLabel: lastReviewLabel
    };
    return pulse;
  }
}

function formatMonthDay(date: Date): string {
  return `${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}