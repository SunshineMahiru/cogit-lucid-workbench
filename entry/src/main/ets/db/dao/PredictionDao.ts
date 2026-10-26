import { relationalStore } from '@kit.ArkData';
import { Prediction } from '../../model/Prediction';
import { PredictionStatus } from '../../model/PredictionStatus';
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
      [PREDICTION_COLS.CREATED_AT]: prediction.createdAt
    };
    return this.store.insert(DB_TABLES.PREDICTION, values);
  }

  /** Returns all predictions. */
  async queryAll(): Promise<Prediction[]> {
    const predicates = new relationalStore.RdbPredicates(DB_TABLES.PREDICTION);
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
      createdAt: resultSet.getLong(resultSet.getColumnIndex(PREDICTION_COLS.CREATED_AT))
    };
  }
}
