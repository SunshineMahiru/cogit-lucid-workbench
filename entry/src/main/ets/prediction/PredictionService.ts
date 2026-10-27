import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { PredictionStatus } from '../model/PredictionStatus';
import { DbHelper } from '../db/DbHelper';
import { PredictionDao } from '../db/dao/PredictionDao';
import { PredictionListItem, PredictionSummary } from './PredictionListItem';
import { summarizePredictions, toPredictionListItems } from './PredictionListMapper';

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
}
