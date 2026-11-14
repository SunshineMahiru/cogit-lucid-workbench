import { relationalStore } from '@kit.ArkData';
import { StatusRecord } from '../../model/StatusRecord';
import { CapacityJudgment } from '../../model/CapacityJudgment';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, STATUS_RECORD_COLS } from '../DbConstants';
import { queryRows } from '../QuerySupport';

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
      [STATUS_RECORD_COLS.NOTE]: record.note,
      [STATUS_RECORD_COLS.BODY_SIGNALS]: record.bodySignals ?? '',
      [STATUS_RECORD_COLS.FUNCTION_STATE]: record.functionState ?? '',
      [STATUS_RECORD_COLS.EMOTION]: record.emotion ?? '',
      [STATUS_RECORD_COLS.ENVIRONMENT]: record.environment ?? '',
      [STATUS_RECORD_COLS.CAPACITY]: record.capacity ?? '',
      [STATUS_RECORD_COLS.FUNCTION_GAIN]: record.functionGain ?? '',
      [STATUS_RECORD_COLS.COST_PAID]: record.costPaid ?? '',
      [STATUS_RECORD_COLS.UNKNOWN_READINGS]: record.unknownReadings ?? '',
      [STATUS_RECORD_COLS.CORRECTED_AT]: record.correctedAt ?? 0,
      [STATUS_RECORD_COLS.REVISIONS]: record.revisions ?? '',
      [STATUS_RECORD_COLS.LEVEL]: record.level ?? SecurityLevel.LOCAL_ONLY,
      [STATUS_RECORD_COLS.DELETED]: record.deleted === true ? 1 : 0
    };
    return this.store.insert(DB_TABLES.STATUS_RECORD, values);
  }

  /** Updates all editable fields of a status record. */
  async update(record: StatusRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [STATUS_RECORD_COLS.DATE]: record.date,
      [STATUS_RECORD_COLS.SLEEP_HOURS]: record.sleepHours,
      [STATUS_RECORD_COLS.EXERCISE_COUNT]: record.exerciseCount,
      [STATUS_RECORD_COLS.ALERT_COUNT]: record.alertCount,
      [STATUS_RECORD_COLS.NOTE]: record.note,
      [STATUS_RECORD_COLS.BODY_SIGNALS]: record.bodySignals ?? '',
      [STATUS_RECORD_COLS.FUNCTION_STATE]: record.functionState ?? '',
      [STATUS_RECORD_COLS.EMOTION]: record.emotion ?? '',
      [STATUS_RECORD_COLS.ENVIRONMENT]: record.environment ?? '',
      [STATUS_RECORD_COLS.CAPACITY]: record.capacity ?? '',
      [STATUS_RECORD_COLS.FUNCTION_GAIN]: record.functionGain ?? '',
      [STATUS_RECORD_COLS.COST_PAID]: record.costPaid ?? '',
      [STATUS_RECORD_COLS.UNKNOWN_READINGS]: record.unknownReadings ?? '',
      [STATUS_RECORD_COLS.CORRECTED_AT]: record.correctedAt ?? 0,
      [STATUS_RECORD_COLS.REVISIONS]: record.revisions ?? '',
      [STATUS_RECORD_COLS.LEVEL]: record.level ?? SecurityLevel.LOCAL_ONLY
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    predicates.equalTo(STATUS_RECORD_COLS.ID, record.id);
    return this.store.update(values, predicates);
  }

  /** Returns all status records. */
  async queryAll(): Promise<StatusRecord[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    predicates.equalTo(STATUS_RECORD_COLS.DELETED, 0);
    return queryRows<StatusRecord>(this.store, predicates,
      (resultSet: relationalStore.ResultSet) => this.mapRow(resultSet));
  }

  /** Returns the status record for one date, or null when absent. */
  async queryByDate(date: string): Promise<StatusRecord | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    predicates.equalTo(STATUS_RECORD_COLS.DATE, date).equalTo(STATUS_RECORD_COLS.DELETED, 0);
    const resultSet = await this.store.query(predicates);
    try {
      let record: StatusRecord | null = null;
      if (resultSet.goToNextRow()) {
        record = this.mapRow(resultSet);
      }
      return record;
    } finally {
      resultSet.close();
    }
  }

  /** Returns the most recent active status records, newest first. */
  async queryRecent(limit: number): Promise<StatusRecord[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    predicates.equalTo(STATUS_RECORD_COLS.DELETED, 0).orderByDesc(STATUS_RECORD_COLS.DATE).limitAs(limit);
    return queryRows<StatusRecord>(this.store, predicates,
      (resultSet: relationalStore.ResultSet) => this.mapRow(resultSet));
  }

  /** Marks a status record as deleted without removing its history. */
  async softDelete(id: string): Promise<number> {
    return this.updateDeleted(id, 1);
  }

  /** Restores a soft-deleted status record. */
  async restore(id: string): Promise<number> {
    return this.updateDeleted(id, 0);
  }

  private async updateDeleted(id: string, deleted: number): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [STATUS_RECORD_COLS.DELETED]: deleted
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.STATUS_RECORD);
    predicates.equalTo(STATUS_RECORD_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  private mapRow(resultSet: relationalStore.ResultSet): StatusRecord {
    return {
      id: resultSet.getString(resultSet.getColumnIndex(STATUS_RECORD_COLS.ID)),
      date: resultSet.getString(resultSet.getColumnIndex(STATUS_RECORD_COLS.DATE)),
      sleepHours: resultSet.getDouble(resultSet.getColumnIndex(STATUS_RECORD_COLS.SLEEP_HOURS)),
      exerciseCount: resultSet.getLong(resultSet.getColumnIndex(STATUS_RECORD_COLS.EXERCISE_COUNT)),
      alertCount: resultSet.getLong(resultSet.getColumnIndex(STATUS_RECORD_COLS.ALERT_COUNT)),
      note: resultSet.getString(resultSet.getColumnIndex(STATUS_RECORD_COLS.NOTE)),
      bodySignals: this.readText(resultSet, STATUS_RECORD_COLS.BODY_SIGNALS),
      functionState: this.readText(resultSet, STATUS_RECORD_COLS.FUNCTION_STATE),
      emotion: this.readText(resultSet, STATUS_RECORD_COLS.EMOTION),
      environment: this.readText(resultSet, STATUS_RECORD_COLS.ENVIRONMENT),
      capacity: this.readText(resultSet, STATUS_RECORD_COLS.CAPACITY) as CapacityJudgment,
      functionGain: this.readText(resultSet, STATUS_RECORD_COLS.FUNCTION_GAIN),
      costPaid: this.readText(resultSet, STATUS_RECORD_COLS.COST_PAID),
      unknownReadings: this.readText(resultSet, STATUS_RECORD_COLS.UNKNOWN_READINGS),
      correctedAt: this.readLong(resultSet, STATUS_RECORD_COLS.CORRECTED_AT),
      revisions: this.readText(resultSet, STATUS_RECORD_COLS.REVISIONS),
      level: resultSet.getString(resultSet.getColumnIndex(STATUS_RECORD_COLS.LEVEL)) as SecurityLevel,
      deleted: resultSet.getLong(resultSet.getColumnIndex(STATUS_RECORD_COLS.DELETED)) === 1
    };
  }

  /** Reads an optional text column; a missing column reads as empty instead of throwing. */
  private readText(resultSet: relationalStore.ResultSet, column: string): string {
    const index = resultSet.getColumnIndex(column);
    if (index < 0) {
      return '';
    }
    const value = resultSet.getString(index);
    return value === undefined ? '' : value;
  }

  /** Reads an optional integer column; a missing column reads as zero. */
  private readLong(resultSet: relationalStore.ResultSet, column: string): number {
    const index = resultSet.getColumnIndex(column);
    return index < 0 ? 0 : resultSet.getLong(index);
  }
}
