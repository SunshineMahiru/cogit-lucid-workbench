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

  private constructor(settings: AppSettings) {
    this.settings = settings;
  }

  /** Reads the current settings once per generation; falls back to defaults if storage is unavailable. */
  static async create(context: common.Context): Promise<ReviewAgent> {
    try {
      const store = await SettingsStore.open(context);
      return new ReviewAgent(await store.load());
    } catch (error) {
      return new ReviewAgent(defaultAppSettings());
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
      const client = this.settings.llmProvider === 'mock' ?
        new LocalMockLlmClient() :
        new OpenAiCompatibleClient(this.settings.llmBaseUrl, this.settings.llmApiKey);
      const analyzer = new LlmContradictionAnalyzer(client, this.settings.llmModel);
      const candidates = await analyzer.analyze(input, { now: now });
      if (candidates.length === 0) {
        throw new Error('empty candidates');
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
        message: '模型不可用，已回退模板'
      };
    }
  }
}
