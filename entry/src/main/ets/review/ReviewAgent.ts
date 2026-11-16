import { common } from '@kit.AbilityKit';
import {
  ContradictionCandidate,
  ContradictionInput
} from '../analysis/contradiction/ContradictionAnalyzer';
import {
  LlmContradictionAnalyzer
} from '../analysis/contradiction/LlmContradictionAnalyzer';
import {
  TemplateContradictionAnalyzer
} from '../analysis/contradiction/TemplateContradictionAnalyzer';
import { LocalMockLlmClient } from '../network/LocalMockLlmClient';
import { OpenAiCompatibleClient } from '../network/OpenAiCompatibleClient';
import { buildAnalysisInput, DroppedItem } from '../security/RequestBuilder';
import { AppSettings, LlmProvider, defaultAppSettings } from '../settings/AppSettings';
import { estimateCostYuan } from '../settings/LlmBudget';
import { LlmSpendStore } from '../settings/LlmSpendStore';
import { SettingsStore } from '../settings/SettingsStore';
import { DbHelper } from '../db/DbHelper';
import { RequestAuditDao } from '../db/dao/RequestAuditDao';
import { RequestAudit } from '../model/RequestAudit';

/** Candidates plus which provider actually answered. */
export interface AgentOutcome {
  candidates: ContradictionCandidate[];
  provider: LlmProvider;
  fellBack: boolean;
  message: string;
  dropped: DroppedItem[];
  /** 本次是否写入审计（模板调用不记录） */
  audited: boolean;
}

/** Metadata recorded with one request; ids and levels only, never text. */
export interface AgentAuditMeta {
  materialIds: string[];
  levels: string[];
  removedCount: number;
}

/** Chooses template, local mock or OpenAI-compatible client from settings. */
export class ReviewAgent {
  private settings: AppSettings;
  private template: TemplateContradictionAnalyzer = new TemplateContradictionAnalyzer();
  private spendStore: LlmSpendStore | null = null;
  private auditDao: RequestAuditDao | null = null;
  private seq: number = 0;

  private constructor(settings: AppSettings, spendStore: LlmSpendStore | null, auditDao: RequestAuditDao | null) {
    this.settings = settings;
    this.spendStore = spendStore;
    this.auditDao = auditDao;
  }

  /** Reads the current settings once per generation; falls back to defaults if storage is unavailable. */
  static async create(context: common.Context): Promise<ReviewAgent> {
    let auditDao: RequestAuditDao | null = null;
    try {
      auditDao = new RequestAuditDao(await DbHelper.init(context));
    } catch (error) {
      auditDao = null;
    }
    try {
      const store = await SettingsStore.open(context);
      const settings = await store.load();
      let spendStore: LlmSpendStore | null = null;
      try {
        spendStore = await LlmSpendStore.open(context);
      } catch (error) {
        spendStore = null;
      }
      return new ReviewAgent(settings, spendStore, auditDao);
    } catch (error) {
      return new ReviewAgent(defaultAppSettings(), null, auditDao);
    }
  }

  async analyze(input: ContradictionInput, now: number = Date.now(),
    confirmed: boolean = false,
    meta: AgentAuditMeta = { materialIds: [], levels: [], removedCount: 0 }): Promise<AgentOutcome> {
    const built = buildAnalysisInput(input, this.settings.llmProvider);
    const safeInput = built.input;
    const dropped = built.dropped;
    if (this.settings.llmProvider === 'template') {
      return {
        candidates: await this.template.analyze(input, { now: now }),
        provider: 'template',
        fellBack: false,
        message: '离线模板',
        dropped: dropped,
        audited: false
      };
    }
    if (safeInput.facts === '' && safeInput.interpretation === '') {
      return {
        candidates: await this.template.analyze(input, { now: now }),
        provider: 'template',
        fellBack: true,
        message: '没有可发送的内容，已改用模板',
        dropped: dropped,
        audited: false
      };
    }
    if (!confirmed) {
      await this.recordAudit(false, 0, true, meta);
      return {
        candidates: await this.template.analyze(input, { now: now }),
        provider: 'template',
        fellBack: true,
        message: '需要确认发送范围后才能调用模型，已改用模板',
        dropped: dropped,
        audited: true
      };
    }
    const inputChars = this.settings.llmProvider === 'mock' ? 0 : this.inputChars(safeInput);
    return ReviewAgent.runExclusive(async (): Promise<AgentOutcome> => {
      try {
        if (this.settings.llmMonthlyBudget <= 0) {
          throw new Error('budget is zero');
        }
        if (this.settings.llmProvider === 'model') {
          if (this.spendStore === null) {
            throw new Error('budget store unavailable');
          }
          const estimated = estimateCostYuan(inputChars, 0);
          if (!(await this.spendStore.canAfford(this.settings.llmMonthlyBudget, estimated, now))) {
            throw new Error('budget exhausted');
          }
        }
        const client = this.settings.llmProvider === 'mock' ?
          new LocalMockLlmClient() :
          new OpenAiCompatibleClient(this.settings.llmBaseUrl, this.settings.llmApiKey);
        const analyzer = new LlmContradictionAnalyzer(client, this.settings.llmModel);
        const candidates = await analyzer.analyze(safeInput, { now: now });
        if (candidates.length === 0) {
          throw new Error('empty candidates');
        }
        if (this.settings.llmProvider === 'model' && this.spendStore !== null) {
          const outputChars = candidates.map((item) => item.gap.length + item.prompt.length)
            .reduce((sum: number, value: number) => sum + value, 0);
          await this.spendStore.record(estimateCostYuan(inputChars, outputChars), now);
        }
        await this.recordAudit(true, inputChars, false, meta);
        return {
          candidates: candidates,
          provider: this.settings.llmProvider,
          fellBack: false,
          message: this.settings.llmProvider === 'mock' ? '本地模拟 LLM' : '模型端点',
          dropped: dropped,
          audited: true
        };
      } catch (error) {
        await this.recordAudit(true, inputChars, true, meta);
        return {
          candidates: await this.template.analyze(input, { now: now }),
          provider: 'template',
          fellBack: true,
          message: '模型或预算不可用，已回退模板',
          dropped: dropped,
          audited: true
        };
      }
    });
  }

  /** Records what was sent without storing any material text. */
  private async recordAudit(confirmed: boolean, chars: number, fellBack: boolean,
    meta: AgentAuditMeta): Promise<void> {
    if (this.auditDao === null) {
      return;
    }
    this.seq += 1;
    const entry: RequestAudit = {
      id: `aud-${Date.now()}-${this.seq}`,
      provider: this.settings.llmProvider,
      host: this.settings.llmBaseUrl,
      materialIds: meta.materialIds,
      levels: meta.levels,
      chars: chars,
      confirmed: confirmed,
      fellBack: fellBack,
      removedCount: meta.removedCount,
      createdAt: Date.now()
    };
    try {
      await this.auditDao.insert(entry);
    } catch (error) {
    }
  }

  private static gate: Promise<void> = Promise.resolve();

  /** Serializes budget check, request and recording so concurrent runs cannot overspend. */
  private static async runExclusive(work: () => Promise<AgentOutcome>): Promise<AgentOutcome> {
    const previous = ReviewAgent.gate;
    let release: () => void = () => {
    };
    ReviewAgent.gate = new Promise<void>((resolve: () => void) => {
      release = resolve;
    });
    await previous;
    try {
      return await work();
    } finally {
      release();
    }
  }

  private inputChars(input: ContradictionInput): number {
    let chars = input.facts.length + input.interpretation.length + 200;
    for (const anchor of input.anchors) {
      chars += anchor.text.length;
    }
    return chars;
  }
}
