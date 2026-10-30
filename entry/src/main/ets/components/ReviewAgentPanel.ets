import { Anchor } from '../model/Anchor';
import { AppTheme } from '../theme/AppTheme';
import { ContradictionCandidate } from '../analysis/contradiction/ContradictionAnalyzer';
import { AgentOutcome, ReviewAgent } from '../review';

/** Self-contained agent panel: pass facts, interpretation and anchors, receive insert text. */
@ComponentV2
export struct ReviewAgentPanel {
  @Param facts: string = '';
  @Param interpretation: string = '';
  @Param anchors: Anchor[] = [];
  @Event onInsert: (text: string) => void = () => {};
  @Local candidates: ContradictionCandidate[] = [];
  @Local isLoading: boolean = false;
  @Local message: string = '';
  @Local errorText: string = '';
  @Local requested: boolean = false;

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
    this.isLoading = true;
    this.errorText = '';
    this.requested = true;
    try {
      const agent = await ReviewAgent.create(hostContext);
      const outcome: AgentOutcome = await agent.analyze({
        facts: this.facts,
        interpretation: this.interpretation,
        anchors: this.anchors
      });
      this.candidates = outcome.candidates;
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

  build() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text('矛盾提示 Agent')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text(this.message.length > 0 ? this.message : '离线模板 / 本地模拟 / 模型端点')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.isLoading ? '生成中…' : '生成提示')
          .fontSize(11)
          .fontColor(AppTheme.color.primary)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(10)
          .onClick(() => {
            this.generate();
          })
      }
      .width('100%')

      if (this.isLoading) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(14)
            .height(14)
            .color(AppTheme.color.primary)
          Text('正在分析事实与解释…')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
      } else if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(10)
          .fontColor(AppTheme.color.danger)
          .width('100%')
      } else if (this.requested && this.candidates.length === 0) {
        Text('没有生成候选，换一种说法再试')
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
      } else {
        ForEach(this.candidates, (candidate: ContradictionCandidate, index: number) => {
          Column({ space: 4 }) {
            Text(candidate.gap)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(AppTheme.color.text)
              .width('100%')
            Row() {
              Text(candidate.prompt)
                .fontSize(11)
                .lineHeight(17)
                .fontColor(AppTheme.color.textSecondary)
                .layoutWeight(1)
              Text('填入')
                .fontSize(10)
                .fontColor(AppTheme.color.primary)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(AppTheme.color.tint)
                .borderRadius(8)
                .onClick(() => {
                  this.insert(candidate);
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(10)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(8)
        }, (candidate: ContradictionCandidate, index: number) => `${candidate.anchorId}_${index}`)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(12)
    .border({ width: 0.5, color: AppTheme.color.border })
    .alignItems(HorizontalAlign.Start)
  }
}
