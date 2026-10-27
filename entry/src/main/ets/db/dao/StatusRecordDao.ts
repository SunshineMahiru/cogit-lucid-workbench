import { relationalStore } from '@kit.ArkData';
import { StatusRecord } from '../../model/StatusRecord';
import { DB_TABLES, STATUS_RECORD_COLS } from '../DbConstants';

/** Data access for the status record table. */
export class StatusRecordDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts a status record, returns the row id. */
  async insert(record: StatusRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [STATUS_RECORD_COLS.ID]: record.id,
      [STATUS_RECORD_COLS.DATE]: record.date,
      [STATUS_RECORD_COLS.SLEEP_HOURS]: record.sleepHours,
      [STATUS_RECORD_COLS.EXERCISE_COUNT]: record.exerciseCount,
      [STATUS_RECORD_COLS.ALERT_COUNT]: record.alertCount,
      [STATUS_RECORD_COLS.NOTE]: record.note
    };
    return this.store.insert(DB_TABLES.STATUS_RECORD, values);
  }

  /** Returns all status records. */
  async queryAll(): Promise<StatusRecord[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    const resultSet = await this.store.query(predicates);
    const records: StatusRecord[] = [];
    while (resultSet.goToNextRow()) {
      records.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return records;
  }

  /** Returns the status record for one date, or null when absent. */
  async queryByDate(date: string): Promise<StatusRecord | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    predicates.equalTo(STATUS_RECORD_COLS.DATE, date);
    const resultSet = await this.store.query(predicates);
    let record: StatusRecord | null = null;
    if (resultSet.goToNextRow()) {
      record = this.mapRow(resultSet);
    }
    resultSet.close();
    return record;
  }

  /** Returns the most recent status records, newest first. */
  async queryRecent(limit: number): Promise<StatusRecord[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    predicates.orderByDesc(STATUS_RECORD_COLS.DATE).limitAs(limit);
    const resultSet = await this.store.query(predicates);
    const records: StatusRecord[] = [];
    while (resultSet.goToNextRow()) {
      records.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return records;
  }

  private mapRow(resultSet: relationalStore.ResultSet): StatusRecord {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(STATUS_RECORD_COLS.ID)),
      date: resultSet.getString(resultSet.getColumnIndex(STATUS_RECORD_COLS.DATE)),
      sleepHours: resultSet.getDouble(resultSet.getColumnIndex(STATUS_RECORD_COLS.SLEEP_HOURS)),
      exerciseCount: resultSet.getLong(resultSet.getColumnIndex(STATUS_RECORD_COLS.EXERCISE_COUNT)),
      alertCount: resultSet.getLong(resultSet.getColumnIndex(STATUS_RECORD_COLS.ALERT_COUNT)),
      note: resultSet.getString(resultSet.getColumnIndex(STATUS_RECORD_COLS.NOTE))
    };
  }
}
