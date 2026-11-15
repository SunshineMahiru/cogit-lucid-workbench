import { relationalStore } from '@kit.ArkData';
import { common, Want } from '@kit.AbilityKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { copyBetween } from '../app/DocumentTransfer';
import { AnchorDao } from '../db/dao/AnchorDao';
import { DecisionDao } from '../db/dao/DecisionDao';
import { EventDao } from '../db/dao/EventDao';
import { ExperienceMaterialDao } from '../db/dao/ExperienceMaterialDao';
import { PredictionDao } from '../db/dao/PredictionDao';
import { RelationDao } from '../db/dao/RelationDao';
import { ReviewResultDao } from '../db/dao/ReviewResultDao';
import { StatusRecordDao } from '../db/dao/StatusRecordDao';
import { PlanDao } from '../db/dao/PlanDao';
import { DbHelper } from '../db/DbHelper';
import { Event } from '../model/Event';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { PlanItem } from '../model/PlanItem';
import { PlanExport } from './PlanExport';
import { countExportBundle, ExportBundle, ExportCounts } from './ExportBundle';
import { prepareExportBundle } from './ExportFilter';
import { ExportOptions, defaultExportOptions } from './ExportOptions';
import { buildExportFileName, writeExportFile } from './ExportFileWriter';
import { renderExportDocument } from './render';
import { latestPerRoot } from '../note/QuickNoteService';

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
  private materialDao: ExperienceMaterialDao;
  private decisionDao: DecisionDao;
  private relationDao: RelationDao;
  private predictionDao: PredictionDao;
  private anchorDao: AnchorDao;
  private statusRecordDao: StatusRecordDao;
  private reviewDao: ReviewResultDao;
  private planDao: PlanDao;

  private constructor(store: relationalStore.RdbStore) {
    this.eventDao = new EventDao(store);
    this.materialDao = new ExperienceMaterialDao(store);
    this.decisionDao = new DecisionDao(store);
    this.relationDao = new RelationDao(store);
    this.predictionDao = new PredictionDao(store);
    this.anchorDao = new AnchorDao(store);
    this.statusRecordDao = new StatusRecordDao(store);
    this.reviewDao = new ReviewResultDao(store);
    this.planDao = new PlanDao(store);
  }

  /** Opens the database and returns a service bound to it. */
  static async open(context: common.Context): Promise<ExportService> {
    const store = await DbHelper.init(context);
    return new ExportService(store);
  }

  /** Renders the document without writing a file, for previews. */
  async buildMarkdown(now: number = Date.now(),
    options: ExportOptions = defaultExportOptions()): Promise<string> {
    const bundle = await this.loadPreparedBundle(now, options);
    return renderExportDocument(bundle);
  }

  /** Opens the system share sheet for an exported Markdown file. */
  async share(context: common.Context, filePath: string): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.sendData',
      uri: fileUri.getUriFromPath(filePath),
      type: 'text/markdown'
    };
    await (context as common.UIAbilityContext).startAbility(want);
  }

  /** Copies an exported file to a user-selected document URI. */
  async saveAs(context: common.Context, result: ExportResult): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [result.fileName];
    options.fileSuffixChoices = ['Markdown|.md'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    if (uris.length === 0) {
      return false;
    }
    await copyBetween(result.filePath, uris[0]);
    return true;
  }

  /** Exports every exportable record and returns the file that was written. */
  async exportMarkdown(context: common.Context, now: number = Date.now(),
    options: ExportOptions = defaultExportOptions()): Promise<ExportResult> {
    const bundle = await this.loadPreparedBundle(now, options);
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

  private async loadPreparedBundle(exportedAt: number,
    options: ExportOptions = defaultExportOptions()): Promise<ExportBundle> {
    const plans: PlanExport[] = [];
    for (const plan of await this.planDao.queryPlans()) {
      const nodes = await this.planDao.queryNodes(plan.id);
      const items: PlanItem[] = [];
      for (const node of nodes) {
        const nodeItems = await this.planDao.queryItems(node.id);
        for (const item of nodeItems) {
          items.push(item);
        }
      }
      plans.push({
        plan: plan,
        nodes: nodes,
        items: items,
        links: await this.planDao.queryLinksByPlan(plan.id)
      });
    }
    const liveEvents: Event[] = await this.eventDao.queryAllLive();
    // Superseded revisions stay in the database unless the author asks for history.
    const events: Event[] = options.includeHistory ? liveEvents : latestPerRoot(liveEvents);
    const materials: ExperienceMaterial[] = [];
    for (const event of events) {
      for (const material of await this.materialDao.queryByEvent(event.id)) {
        materials.push(material);
      }
    }
    const bundle: ExportBundle = {
      events: events,
      decisions: await this.decisionDao.queryAll(),
      relations: await this.relationDao.queryAll(),
      predictions: await this.predictionDao.queryAll(),
      anchors: await this.anchorDao.queryAll(),
      statusRecords: await this.statusRecordDao.queryAll(),
      reviews: await this.reviewDao.queryRecent(1000),
      materials: materials,
      plans: plans,
      exportedAt: exportedAt
    };
    return prepareExportBundle(bundle, options);
  }
}
