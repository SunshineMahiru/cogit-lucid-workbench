import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../db/DbHelper';
import { EventDao } from '../db/dao/EventDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { Prediction } from './Prediction';
import { PredictionStatus } from './PredictionStatus';
import { StatusRecord } from './StatusRecord';
import { BodyReading, PredictionItem } from './HomeModel';

/** Loads home page data from the database, replacing mock data. */
export class HomeDataService {
  private store: relationalStore.RdbStore;
  private eventDao: EventDao;
  private predictionDao: PredictionDao;
  private statusRecordDao: StatusRecordDao;

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
    this.eventDao = new EventDao(store);
    this.predictionDao = new PredictionDao(store);
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
}

function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}