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
import { AppSettings, LlmProvider, defaultAppSettings } from '../settings/AppSettings';
import { estimateCostYuan } from '../settings/LlmBudget';
import { LlmSpendStore } from '../settings/LlmSpendStore';
import { SettingsStore } from '../settings/SettingsStore';

/** Candidates plus which provider actually answered. */
export interface AgentOutcome {
  candidates: ContradictionCandidate[];
  provider: LlmProvider;
  fellBack: boolean;
  message: string;
}

/** Chooses template, local mock or OpenAI-compatible client from settings. */
export class ReviewAgent {
  private settings: AppSettings;
  private template: TemplateContradictionAnalyzer = new TemplateContradictionAnalyzer();
  private spendStore: LlmSpendStore | null = null;

  private constructor(settings: AppSettings, spendStore: LlmSpendStore | null) {
    this.settings = settings;
    this.spendStore = spendStore;
  }

  /** Reads the current settings once per generation; falls back to defaults if storage is unavailable. */
  static async create(context: common.Context): Promise<ReviewAgent> {
    try {
      const store = await SettingsStore.open(context);
      const settings = await store.load();
      let spendStore: LlmSpendStore | null = null;
      try {
        spendStore = await LlmSpendStore.open(context);
      } catch (error) {
        spendStore = null;
      }
      return new ReviewAgent(settings, spendStore);
    } catch (error) {
      return new ReviewAgent(defaultAppSettings(), null);
    }
  }

  async analyze(input: ContradictionInput, now: number = Date.now()): Promise<AgentOutcome> {
    if (this.settings.llmProvider === 'template') {
      return {
        candidates: await this.template.analyze(input, { now: now }),
        provider: 'template',
        fellBack: false,
        message: '离线模板'
      };
    }

    try {
      if (this.settings.llmMonthlyBudget <= 0) {
        throw new Error('budget is zero');
      }
      const inputChars = this.settings.llmProvider === 'mock' ? 0 : this.inputChars(input);
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
      const candidates = await analyzer.analyze(input, { now: now });
      if (candidates.length === 0) {
        throw new Error('empty candidates');
      }
      if (this.settings.llmProvider === 'model' && this.spendStore !== null) {
        const outputChars = candidates.map((item) => item.gap.length + item.prompt.length)
          .reduce((sum: number, value: number) => sum + value, 0);
        await this.spendStore.record(estimateCostYuan(inputChars, outputChars), now);
      }
      return {
        candidates: candidates,
        provider: this.settings.llmProvider,
        fellBack: false,
        message: this.settings.llmProvider === 'mock' ? '本地模拟 LLM' : '模型端点'
      };
    } catch (error) {
      return {
        candidates: await this.template.analyze(input, { now: now }),
        provider: 'template',
        fellBack: true,
        message: '模型或预算不可用，已回退模板'
      };
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
