import { relationalStore } from '@kit.ArkData';
import { Prediction } from '../../model/Prediction';
import { PredictionStatus } from '../../model/PredictionStatus';
import { SecurityLevel } from '../../model/SecurityLevel';
import { DB_TABLES, PREDICTION_COLS } from '../DbConstants';

/** Data access for the prediction table. */
export class PredictionDao {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /** Inserts a prediction, returns the row id. */
  async insert(prediction: Prediction): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PREDICTION_COLS.ID]: prediction.id,
      [PREDICTION_COLS.TARGET]: prediction.target,
      [PREDICTION_COLS.JUDGMENT]: prediction.judgment,
      [PREDICTION_COLS.CONFIDENCE]: prediction.confidence,
      [PREDICTION_COLS.REASON]: prediction.reason,
      [PREDICTION_COLS.SETTLEMENT_DATE]: prediction.settlementDate,
      [PREDICTION_COLS.STATUS]: prediction.status,
      [PREDICTION_COLS.ACTUAL_RESULT]: prediction.actualResult,
      [PREDICTION_COLS.HIT]: prediction.hit === null ? null : (prediction.hit ? 1 : 0),
      [PREDICTION_COLS.VERSION]: prediction.version,
      [PREDICTION_COLS.LEVEL]: prediction.level ?? SecurityLevel.LOCAL_ONLY,
      [PREDICTION_COLS.CREATED_AT]: prediction.createdAt
    };
    return this.store.insert(DB_TABLES.PREDICTION, values);
  }

  /** Settles a prediction: updates status, actualResult, hit. */
  async settle(id: string, actualResult: string, hit: boolean): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      [PREDICTION_COLS.STATUS]: PredictionStatus.SETTLED,
      [PREDICTION_COLS.ACTUAL_RESULT]: actualResult,
      [PREDICTION_COLS.HIT]: hit ? 1 : 0
    };
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PREDICTION);
    predicates.equalTo(PREDICTION_COLS.ID, id);
    return this.store.update(values, predicates);
  }

  /** Returns all predictions. */
  async queryAll(): Promise<Prediction[]> {
    return this.queryWith(new relationalStore.RdbPredicates(DB_TABLES.PREDICTION));
  }

  /** Returns predictions of one status. */
  async queryByStatus(status: PredictionStatus): Promise<Prediction[]> {
    return this.queryPage(status, 1000, 0);
  }

  /** Returns one page of predictions, optionally filtered by status. */
  async queryPage(status: PredictionStatus | null, limit: number, offset: number): Promise<Prediction[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PREDICTION);
    if (status !== null) {
      predicates.equalTo(PREDICTION_COLS.STATUS, status);
    }
    predicates.orderByAsc(PREDICTION_COLS.SETTLEMENT_DATE).limitAs(limit).offsetAs(offset);
    return this.queryWith(predicates);
  }

  /** Returns one prediction by id, or null when it does not exist. */
  async queryById(id: string): Promise<Prediction | null> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PREDICTION);
    predicates.equalTo(PREDICTION_COLS.ID, id).limitAs(1);
    const predictions = await this.queryWith(predicates);
    return predictions.length > 0 ? predictions[0] : null;
  }

  private async queryWith(predicates: relationalStore.RdbPredicates): Promise<Prediction[]> {
    const resultSet = await this.store.query(predicates);
    const predictions: Prediction[] = [];
    while (resultSet.goToNextRow()) {
      predictions.push(this.mapRow(resultSet));
    }
    resultSet.close();
    return predictions;
  }

  private mapRow(resultSet: relationalStore.ResultSet): Prediction {
    const hitIndex = resultSet.getColumnIndex(PREDICTION_COLS.HIT);
    const hitValue = resultSet.isColumnNull(hitIndex) ? null : resultSet.getLong(hitIndex) === 1;
    return {
      id: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.ID)),
      target: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.TARGET)),
      judgment: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.JUDGMENT)),
      confidence: resultSet.getLong(resultSet.getColumnIndex(PREDICTION_COLS.CONFIDENCE)),
      reason: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.REASON)),
      settlementDate: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.SETTLEMENT_DATE)),
      status: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.STATUS)) as PredictionStatus,
      actualResult: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.ACTUAL_RESULT)),
      hit: hitValue,
      version: resultSet.getLong(resultSet.getColumnIndex(PREDICTION_COLS.VERSION)),
      level: resultSet.getString(resultSet.getColumnIndex(PREDICTION_COLS.LEVEL)) as SecurityLevel,
      createdAt: resultSet.getLong(resultSet.getColumnIndex(PREDICTION_COLS.CREATED_AT))
    };
  }
}
