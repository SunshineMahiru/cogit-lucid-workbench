import { common } from '@kit.AbilityKit';
import { Anchor } from '../model/Anchor';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppTheme } from '../theme/AppTheme';
import { ContradictionCandidate, ContradictionInput } from '../analysis/contradiction/ContradictionAnalyzer';
import { AgentOutcome, ReviewAgent } from '../review';
import { buildAnalysisInput } from '../security/RequestBuilder';
import { AppSettings, defaultAppSettings } from '../settings/AppSettings';
import { SettingsStore } from '../settings/SettingsStore';
import { ConfirmSheetItem, RequestConfirmSheet } from './RequestConfirmSheet';

/** Self-contained agent panel: pass facts, interpretation and anchors, receive insert text. */
@ComponentV2
export struct ReviewAgentPanel {
  @Param facts: string = '';
  @Param interpretation: string = '';
  @Param anchors: Anchor[] = [];
  @Param factsLevel: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Param interpretationLevel: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Param relationForbidsAnalysis: boolean = false;
  @Event onInsert: (text: string) => void = () => {};
  @Local candidates: ContradictionCandidate[] = [];
  @Local isLoading: boolean = false;
  @Local message: string = '';
  @Local errorText: string = '';
  @Local requested: boolean = false;
  @Local droppedCount: number = 0;
  @Local confirmVisible: boolean = false;
  @Local confirmItems: ConfirmSheetItem[] = [];
  @Local confirmDropped: number = 0;
  @Local confirmProviderLabel: string = '';
  @Local confirmHost: string = '';

  private async generate(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (this.facts.trim().length === 0 || this.interpretation.trim().length === 0) {
      this.errorText = '先填写事实与解释，再生成提示';
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.errorText = '运行环境未就绪';
      return;
    }
    const settings = await this.readSettings(hostContext);
    if (settings.llmProvider === 'template') {
      await this.runAnalyze(hostContext, false);
      return;
    }
    const built = buildAnalysisInput(this.buildInput(), settings.llmProvider);
    const items = this.sheetItems(built.input);
    if (items.length === 0) {
      await this.runAnalyze(hostContext, true);
      return;
    }
    this.confirmItems = items;
    this.confirmDropped = built.dropped.length;
    this.confirmProviderLabel = settings.llmProvider === 'mock' ? '本地模拟' : '模型端点';
    this.confirmHost = settings.llmBaseUrl;
    this.confirmVisible = true;
  }

  private async readSettings(hostContext: common.Context): Promise<AppSettings> {
    try {
      const store = await SettingsStore.open(hostContext);
      return await store.load();
    } catch (error) {
      return defaultAppSettings();
    }
  }

  private buildInput(): ContradictionInput {
    return {
      facts: this.facts,
      interpretation: this.interpretation,
      anchors: this.anchors,
      factsLevel: this.factsLevel,
      interpretationLevel: this.interpretationLevel,
      relationForbidsAnalysis: this.relationForbidsAnalysis
    };
  }

  private sheetItems(input: ContradictionInput): ConfirmSheetItem[] {
    const items: ConfirmSheetItem[] = [];
    if (input.facts.length > 0) {
      items.push({ label: '事实', level: input.factsLevel, chars: input.facts.length });
    }
    if (input.interpretation.length > 0) {
      items.push({ label: '解释', level: input.interpretationLevel, chars: input.interpretation.length });
    }
    input.anchors.forEach((anchor: Anchor, index: number) => {
      const level: SecurityLevel = anchor.level ?? SecurityLevel.LOCAL_ONLY;
      items.push({ label: `锚点 ${index + 1}`, level: level, chars: anchor.text.length });
    });
    return items;
  }

  private confirmSend(): void {
    this.confirmVisible = false;
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.errorText = '运行环境未就绪';
      return;
    }
    this.runAnalyze(hostContext, true);
  }

  private cancelSend(): void {
    this.confirmVisible = false;
  }

  private async runAnalyze(hostContext: common.Context, confirmed: boolean): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorText = '';
    this.requested = true;
    try {
      const agent = await ReviewAgent.create(hostContext);
      const outcome: AgentOutcome = await agent.analyze(this.buildInput(), Date.now(), confirmed);
      this.candidates = outcome.candidates;
      this.droppedCount = outcome.dropped.length;
      this.message = outcome.fellBack ? `${outcome.message}（${outcome.provider}）` : outcome.message;
    } catch (error) {
      this.errorText = '生成失败，请检查设置或改用模板';
    } finally {
      this.isLoading = false;
    }
  }

  private insert(candidate: ContradictionCandidate): void {
    const text = `${candidate.gap}\n追问：${candidate.prompt}`;
    this.onInsert(text);
  }

  @Builder
  confirmSheet() {
    RequestConfirmSheet({
      visible: this.confirmVisible,
      providerLabel: this.confirmProviderLabel,
      host: this.confirmHost,
      items: this.confirmItems,
      droppedCount: this.confirmDropped,
      onConfirm: () => {
        this.confirmSend();
      },
      onCancel: () => {
        this.cancelSend();
      }
    })
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text('矛盾提示 Agent')
            .fontSize(AppTheme.font.bodyStrong)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text(this.message.length > 0 ? this.message : '离线模板 / 本地模拟 / 模型端点')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.isLoading ? '生成中…' : '生成提示')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.md)
          .onClick(() => {
            this.generate();
          })
      }
      .width('100%')

      if (this.droppedCount > 0) {
        Text(`已排除 ${this.droppedCount} 项不可发送内容`)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
      }

      if (this.isLoading) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(14)
            .height(14)
            .color(AppTheme.color.primary)
          Text('正在分析事实与解释…')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
        }
      } else if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.danger)
          .width('100%')
      } else if (this.requested && this.candidates.length === 0) {
        Text('没有生成候选，换一种说法再试')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
      } else {
        ForEach(this.candidates, (candidate: ContradictionCandidate, index: number) => {
          Column({ space: 4 }) {
            Text(candidate.gap)
              .fontSize(AppTheme.font.bodyStrong)
              .lineHeight(19)
              .fontColor(AppTheme.color.text)
              .width('100%')
            Row() {
              Text(candidate.prompt)
                .fontSize(AppTheme.font.body)
                .lineHeight(17)
                .fontColor(AppTheme.color.textSecondary)
                .layoutWeight(1)
              Text('填入')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.primary)
                .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                .backgroundColor(AppTheme.color.tint)
                .borderRadius(AppTheme.radius.sm)
                .onClick(() => {
                  this.insert(candidate);
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
        }, (candidate: ContradictionCandidate, index: number) => `${candidate.anchorId}_${index}`)
      }
    }
    .width('100%')
    .padding(AppTheme.spacing.s12)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
    .border({ width: 0.5, color: AppTheme.color.border })
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.confirmVisible, this.confirmSheet(), {
      height: 380,
      dragBar: false,
      backgroundColor: AppTheme.color.surface
    })
  }
}
