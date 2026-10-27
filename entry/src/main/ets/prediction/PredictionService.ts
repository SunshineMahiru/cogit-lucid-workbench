import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { MOCK_PREDICTIONS } from '../model/mockData';
import { PredictionStatus } from '../model/PredictionStatus';
import { DbHelper } from '../db/DbHelper';
import { PredictionDao } from '../db/dao/PredictionDao';
import { PredictionDetail, PredictionListItem, PredictionSummary } from './PredictionListItem';
import { summarizePredictions, toPredictionDetail, toPredictionListItems } from './PredictionListMapper';
import { PredictionStats, buildPredictionStats } from './PredictionStats';

/** Reads predictions for the list page. */
export class PredictionService {
  private predictionDao: PredictionDao;

  private constructor(store: relationalStore.RdbStore) {
    this.predictionDao = new PredictionDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<PredictionService> {
    const store = await DbHelper.init(context);
    return new PredictionService(store);
  }

  /** Returns prediction rows, optionally filtered by status. */
  async list(status: PredictionStatus | null): Promise<PredictionListItem[]> {
    const predictions = status === null ?
      await this.predictionDao.queryAll() :
      await this.predictionDao.queryByStatus(status);
    return toPredictionListItems(predictions);
  }

  /** Returns the counts and hit rate shown above the list. */
  async summary(): Promise<PredictionSummary> {
    const predictions = await this.predictionDao.queryAll();
    return summarizePredictions(predictions);
  }

  /** Returns one prediction for the detail page, or null when it is gone. */
  async find(id: string): Promise<PredictionDetail | null> {
    const prediction = await this.predictionDao.queryById(id);
    if (prediction === null) {
      return null;
    }
    return toPredictionDetail(prediction);
  }

  /** Returns the settled-only aggregate used by the statistics page. */
  async stats(): Promise<PredictionStats> {
    const predictions = await this.predictionDao.queryAll();
    return buildPredictionStats(predictions);
  }

  /**
   * Inserts the synthetic demo predictions when the table is empty.
   * Returns how many rows were added; existing data is never touched.
   */
  async seedDemoPredictions(): Promise<number> {
    const existing = await this.predictionDao.queryAll();
    if (existing.length > 0) {
      return 0;
    }
    for (const prediction of MOCK_PREDICTIONS) {
      await this.predictionDao.insert(prediction);
    }
    return MOCK_PREDICTIONS.length;
  }
}
