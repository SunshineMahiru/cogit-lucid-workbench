import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ReadingRules } from '../analysis/status/ReadingRules';
import { ThresholdReadingRules } from '../analysis/status/ThresholdReadingRules';
import { ObservationRule, defaultObservationRule } from '../analysis/status/ObservationRule';
import { MOCK_STATUS_RECORDS } from '../model/mockData';
import { StatusRecord } from '../model/StatusRecord';
import { CapacityJudgment } from '../model/CapacityJudgment';
import { SecurityLevel } from '../model/SecurityLevel';
import { createStatusRecord } from '../model/factories';
import { DbHelper } from '../db/DbHelper';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { ObservationRuleStore } from '../settings/ObservationRuleStore';
import { StatusDayRow, StatusOverview } from './StatusListItem';
import { buildStatusOverview, toStatusDayRow, toStatusDayRows } from './StatusMapper';
import { parseStatusRevisions, statusRevisionOf, stringifyStatusRevisions } from './StatusRevisions';

/** Everything one status day carries when it is saved. */
export interface StatusDraft {
  date: string;
  sleepHours: number;
  exerciseCount: number;
  alertCount: number;
  unknownReadings: string;
  note: string;
  bodySignals: string;
  functionState: string;
  emotion: string;
  environment: string;
  capacity: CapacityJudgment;
  functionGain: string;
  costPaid: string;
}

/** Reads status records for the panel and the history page. */
export class StatusService {
  private statusDao: StatusRecordDao;
  private rules: ReadingRules;
  private ruleStore: ObservationRuleStore;
  private rule: ObservationRule;

  private constructor(store: relationalStore.RdbStore, ruleStore: ObservationRuleStore, rule: ObservationRule) {
    this.statusDao = new StatusRecordDao(store);
    this.ruleStore = ruleStore;
    this.rule = rule;
    this.rules = new ThresholdReadingRules(rule);
  }

  /** Opens the database and settings, then returns a service bound to both. */
  static async open(context: common.Context): Promise<StatusService> {
    const store = await DbHelper.init(context);
    const ruleStore = await ObservationRuleStore.open(context);
    const rule = await ruleStore.load();
    return new StatusService(store, ruleStore, rule);
  }

  /** Returns the observation rule currently in use. */
  observationRule(): ObservationRule {
    return this.rule;
  }

  /** Persists a new observation rule and applies it to later reads. */
  async saveObservationRule(rule: ObservationRule): Promise<void> {
    await this.ruleStore.save(rule);
    this.rule = await this.ruleStore.load();
    this.rules = new ThresholdReadingRules(this.rule);
  }

  /** Restores the default observation rule. */
  async resetObservationRule(): Promise<ObservationRule> {
    this.rule = await this.ruleStore.reset();
    this.rules = new ThresholdReadingRules(this.rule);
    return this.rule;
  }

  /** Returns the recent window used by the panel. */
  async overview(limit: number = 7): Promise<StatusOverview> {
    const records = (await this.statusDao.queryRecent(limit)).filter(r => r.level !== SecurityLevel.SEALED);
    return buildStatusOverview(records, this.rules, limit);
  }

  /** Returns all rendered rows, newest first. */
  async history(limit: number = 50): Promise<StatusDayRow[]> {
    const records = (await this.statusDao.queryRecent(limit)).filter(r => r.level !== SecurityLevel.SEALED);
    return toStatusDayRows(records, this.rules);
  }

  /** Returns one day's rendered reading, or null when it is absent. */
  async find(date: string): Promise<StatusDayRow | null> {
    const record = await this.statusDao.queryByDate(date);
    return record === null ? null : toStatusDayRow(record, this.rules);
  }

  /** Returns the stored record for one date, used by the editor to keep corrections. */
  async findRecord(date: string): Promise<StatusRecord | null> {
    return this.statusDao.queryByDate(date);
  }

  /**
   * Creates or updates one day's reading and returns the refreshed overview.
   * A same-day change keeps the previous values as a revision and stamps the correction time.
   */
  async save(draft: StatusDraft, now: number = Date.now()): Promise<StatusOverview> {
    const existing = await this.statusDao.queryByDate(draft.date);
    const record: StatusRecord = existing === null ? createStatusRecord() : existing;
    if (existing !== null && hasReadingChanged(existing, draft)) {
      const revisions = parseStatusRevisions(existing.revisions ?? '');
      revisions.push(statusRevisionOf(existing.correctedAt !== undefined && existing.correctedAt > 0 ? existing.correctedAt : now,
        existing.sleepHours, existing.exerciseCount, existing.alertCount, existing.note,
        existing.capacity ?? ''));
      record.revisions = stringifyStatusRevisions(revisions);
      record.correctedAt = now;
    }
    record.date = draft.date;
    record.sleepHours = draft.sleepHours;
    record.exerciseCount = draft.exerciseCount;
    record.alertCount = draft.alertCount;
    record.note = draft.note.trim();
    record.bodySignals = draft.bodySignals.trim();
    record.functionState = draft.functionState.trim();
    record.emotion = draft.emotion.trim();
    record.environment = draft.environment.trim();
    record.capacity = draft.capacity;
    record.functionGain = draft.functionGain.trim();
    record.costPaid = draft.costPaid.trim();
    record.unknownReadings = draft.unknownReadings;
    if (existing === null) {
      await this.statusDao.insert(record);
    } else {
      await this.statusDao.update(record);
    }
    return this.overview();
  }

  /** Soft-deletes one day's reading while keeping it available for undo. */
  async softDelete(id: string): Promise<void> {
    await this.statusDao.softDelete(id);
  }

  /** Restores a status reading removed by mistake. */
  async restore(id: string): Promise<void> {
    await this.statusDao.restore(id);
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

/** Reports whether a same-day save replaces any reading, note or judgment. */
function hasReadingChanged(existing: StatusRecord, draft: StatusDraft): boolean {
  return existing.sleepHours !== draft.sleepHours ||
    existing.exerciseCount !== draft.exerciseCount ||
    existing.alertCount !== draft.alertCount ||
    existing.note !== draft.note.trim() ||
    (existing.capacity ?? '') !== draft.capacity ||
    (existing.unknownReadings ?? '') !== draft.unknownReadings;
}

/** Returns the default draft for a date. */
export function emptyStatusDraft(date: string): StatusDraft {
  return {
    date: date,
    sleepHours: 0,
    exerciseCount: 0,
    alertCount: 0,
    unknownReadings: '',
    note: '',
    bodySignals: '',
    functionState: '',
    emotion: '',
    environment: '',
    capacity: '',
    functionGain: '',
    costPaid: ''
  };
}

/** Returns the defaults used before the author changes the observation rule. */
export function defaultRule(): ObservationRule {
  return defaultObservationRule();
}
