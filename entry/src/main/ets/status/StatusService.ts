import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ReadingRules } from '../analysis/status/ReadingRules';
import { ThresholdReadingRules } from '../analysis/status/ThresholdReadingRules';
import { MOCK_STATUS_RECORDS } from '../model/mockData';
import { DbHelper } from '../db/DbHelper';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { StatusDayRow, StatusOverview } from './StatusListItem';
import { buildStatusOverview, toStatusDayRows } from './StatusMapper';

/** Reads status records for the panel and the history page. */
export class StatusService {
  private statusDao: StatusRecordDao;
  private rules: ReadingRules = new ThresholdReadingRules();

  private constructor(store: relationalStore.RdbStore) {
    this.statusDao = new StatusRecordDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<StatusService> {
    const store = await DbHelper.init(context);
    return new StatusService(store);
  }

  /** Returns the recent window used by the panel. */
  async overview(limit: number = 7): Promise<StatusOverview> {
    const records = await this.statusDao.queryRecent(limit);
    return buildStatusOverview(records, this.rules, limit);
  }

  /** Returns all rendered rows, newest first. */
  async history(limit: number = 50): Promise<StatusDayRow[]> {
    const records = await this.statusDao.queryRecent(limit);
    return toStatusDayRows(records, this.rules);
  }

  /**
   * Inserts the synthetic demo readings when the table is empty.
   * Returns how many rows were added; existing data is never touched.
   */
  async seedDemoRecords(): Promise<number> {
    const existing = await this.statusDao.queryAll();
    if (existing.length > 0) {
      return 0;
    }
    for (const record of MOCK_STATUS_RECORDS) {
      await this.statusDao.insert(record);
    }
    return MOCK_STATUS_RECORDS.length;
  }
}
