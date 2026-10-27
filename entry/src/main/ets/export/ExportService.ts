import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AnchorDao } from '../db/dao/AnchorDao';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { RelationDao } from '../db/dao/RelationDao';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { DbHelper } from '../db/DbHelper';
import { countExportBundle, ExportBundle, ExportCounts } from './ExportBundle';
import { prepareExportBundle } from './ExportFilter';
import { buildExportFileName, writeExportFile } from './ExportFileWriter';
import { renderExportDocument } from './render';

/** Outcome of one Markdown export. */
export interface ExportResult {
  fileName: string;
  filePath: string;
  /** Number of characters written */
  charCount: number;
  counts: ExportCounts;
}

/** Collects records, renders Markdown and writes it into the app sandbox. */
export class ExportService {
  private eventDao: EventDao;
  private decisionDao: DecisionDao;
  private relationDao: RelationDao;
  private predictionDao: PredictionDao;
  private anchorDao: AnchorDao;
  private statusRecordDao: StatusRecordDao;

  private constructor(store: relationalStore.RdbStore) {
    this.eventDao = new EventDao(store);
    this.decisionDao = new DecisionDao(store);
    this.relationDao = new RelationDao(store);
    this.predictionDao = new PredictionDao(store);
    this.anchorDao = new AnchorDao(store);
    this.statusRecordDao = new StatusRecordDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<ExportService> {
    const store = await DbHelper.init(context);
    return new ExportService(store);
  }

  /** Renders the document without writing a file, for previews. */
  async buildMarkdown(now: number = Date.now()): Promise<string> {
    const bundle = await this.loadPreparedBundle(now);
    return renderExportDocument(bundle);
  }

  /** Exports every exportable record and returns the file that was written. */
  async exportMarkdown(context: common.Context, now: number = Date.now()): Promise<ExportResult> {
    const bundle = await this.loadPreparedBundle(now);
    const markdown = renderExportDocument(bundle);
    const fileName = buildExportFileName(now);
    const filePath = await writeExportFile(context, fileName, markdown);
    return {
      fileName: fileName,
      filePath: filePath,
      charCount: markdown.length,
      counts: countExportBundle(bundle)
    };
  }

  private async loadPreparedBundle(exportedAt: number): Promise<ExportBundle> {
    const bundle: ExportBundle = {
      events: await this.eventDao.queryAll(),
      decisions: await this.decisionDao.queryAll(),
      relations: await this.relationDao.queryAll(),
      predictions: await this.predictionDao.queryAll(),
      anchors: await this.anchorDao.queryAll(),
      statusRecords: await this.statusRecordDao.queryAll(),
      exportedAt: exportedAt
    };
    return prepareExportBundle(bundle);
  }
}
