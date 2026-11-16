import { common } from '@kit.AbilityKit';
import { Anchor } from '../model/Anchor';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppTheme } from '../theme/AppTheme';
import { ContradictionCandidate, ContradictionInput } from '../analysis/contradiction/ContradictionAnalyzer';
import { AgentAuditMeta, AgentOutcome, ReviewAgent } from '../review';
import { buildAnalysisInput, filterConfirmedInput } from '../security/RequestBuilder';
import { AppSettings, defaultAppSettings } from '../settings/AppSettings';
import { SettingsStore } from '../settings/SettingsStore';
import { ConfirmSheetItem, RequestConfirmSheet } from './RequestConfirmSheet';

/** Strictness order: analyzable is loosest, sealed is strictest. */
function levelRank(level: SecurityLevel): number {
  if (level === SecurityLevel.ANALYZABLE) {
    return 0;
  }
  if (level === SecurityLevel.LOCAL_ONLY) {
    return 1;
  }
  return 2;
}

/** Self-contained agent panel: pass facts, interpretation and anchors, receive insert text. */
@ComponentV2
export struct ReviewAgentPanel {
  @Param facts: string = '';
  @Param interpretation: string = '';
  @Param anchors: Anchor[] = [];
  @Param factsLevel: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Param interpretationLevel: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Param relationForbidsAnalysis: boolean = false;
  @Param relationInvolvedByMaterial: boolean = false;
  @Param relationIdHint: string = '';
  @Param maxLevel: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Event onInsert: (text: string) => void = () => {};
  @Local factsLevelValue: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Local interpretationLevelValue: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Local candidates: ContradictionCandidate[] = [];
  @Local isLoading: boolean = false;
  @Local message: string = '';
  @Local errorText: string = '';
  @Local requested: boolean = false;
  @Local droppedCount: number = 0;
  @Local confirmVisible: boolean = false;
  @Local confirmItems: ConfirmSheetItem[] = [];
  @Local confirmDropped: number = 0;
  @Local confirmInitialCount: number = 0;
  @Local confirmProviderLabel: string = '';
  @Local confirmHost: string = '';
  @Local ignoredKeys: string[] = [];
  @Local relationInvolved: boolean = false;
  @Local relationIdText: string = '';
  @Local relationBoundaryText: string = '';
  @Local editingKey: string = '';
  @Local editText: string = '';

  private materialRelationInvolved(): boolean {
    return this.relationInvolved || this.relationInvolvedByMaterial;
  }

  private effectiveRelationId(): string {
    return this.relationInvolvedByMaterial ? this.relationIdHint.trim() : this.relationIdText.trim();
  }

  private effectiveLevel(level: SecurityLevel): SecurityLevel {
    return levelRank(level) < levelRank(this.maxLevel) ? this.maxLevel : level;
  }

  private canUseLevel(level: SecurityLevel): boolean {
    return levelRank(level) >= levelRank(this.maxLevel);
  }

  private async generate(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (this.facts.trim().length === 0 || this.interpretation.trim().length === 0) {
      this.errorText = '先填写事实与解释，再生成提示';
      return;
    }
    if (this.materialRelationInvolved() &&
      (this.effectiveRelationId().length === 0 || this.relationBoundaryText.trim().length === 0)) {
      this.errorText = '涉及他人时，先写关系与分析边界，再生成提示';
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
    this.confirmInitialCount = items.length;
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

  aboutToAppear(): void {
    this.factsLevelValue = this.factsLevel;
    this.interpretationLevelValue = this.interpretationLevel;
  }

  private buildInput(): ContradictionInput {
    return {
      facts: this.facts,
      interpretation: this.interpretation,
      anchors: this.anchors,
      factsLevel: this.effectiveLevel(this.factsLevelValue),
      interpretationLevel: this.effectiveLevel(this.interpretationLevelValue),
      relationForbidsAnalysis: this.relationForbidsAnalysis,
      relationInvolved: this.materialRelationInvolved(),
      relationId: this.effectiveRelationId(),
      relationBoundary: this.relationBoundaryText.trim()
    };
  }

  private sheetItems(input: ContradictionInput): ConfirmSheetItem[] {
    const items: ConfirmSheetItem[] = [];
    if (input.facts.length > 0) {
      items.push({ id: 'facts', label: '事实', level: input.factsLevel, chars: input.facts.length });
    }
    if (input.interpretation.length > 0) {
      items.push({ id: 'interpretation', label: '解释', level: input.interpretationLevel, chars: input.interpretation.length });
    }
    input.anchors.forEach((anchor: Anchor, index: number) => {
      const level: SecurityLevel = anchor.level ?? SecurityLevel.LOCAL_ONLY;
      items.push({ id: `anchor:${anchor.id}`, label: `锚点 ${index + 1}`, level: level, chars: anchor.text.length });
    });
    if (input.relationInvolved === true) {
      items.push({
        id: 'relation',
        label: `关系绑定 · ${input.relationId ?? ''}`,
        level: '已绑定',
        chars: (input.relationBoundary ?? '').length
      });
    }
    return items;
  }

  private confirmSend(): void {
    this.confirmVisible = false;
    if (this.confirmItems.length === 0) {
      this.errorText = '至少保留一项再发送';
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.errorText = '运行环境未就绪';
      return;
    }
    const keepIds = this.confirmItems.map((item: ConfirmSheetItem) => item.id);
    const meta: AgentAuditMeta = {
      materialIds: this.confirmItems.map((item: ConfirmSheetItem) => item.id),
      levels: this.confirmItems.map((item: ConfirmSheetItem) => item.level),
      removedCount: Math.max(0, this.confirmInitialCount - this.confirmItems.length)
    };
    this.runAnalyze(hostContext, true, filterConfirmedInput(this.buildInput(), keepIds), meta);
  }

  private cancelSend(): void {
    this.confirmVisible = false;
  }

  private async runAnalyze(hostContext: common.Context, confirmed: boolean,
    input?: ContradictionInput,
    meta?: AgentAuditMeta): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorText = '';
    this.requested = true;
    try {
      const agent = await ReviewAgent.create(hostContext);
      const outcome: AgentOutcome = await agent.analyze(input ?? this.buildInput(), Date.now(), confirmed, meta);
      this.candidates = outcome.candidates;
      this.ignoredKeys = [];
      this.droppedCount = outcome.dropped.length;
      this.message = outcome.fellBack ? `${outcome.message}（${outcome.provider}）` : outcome.message;
    } catch (error) {
      this.errorText = '生成失败，请检查设置或改用模板';
    } finally {
      this.isLoading = false;
    }
  }

  private composeCandidate(candidate: ContradictionCandidate): string {
    const parts: string[] = [candidate.gap];
    if ((candidate.basis ?? '').trim().length > 0) {
      parts.push(`依据：${(candidate.basis as string).trim()}`);
    }
    if ((candidate.unknowns ?? '').trim().length > 0) {
      parts.push(`未知：${(candidate.unknowns as string).trim()}`);
    }
    parts.push(`追问：${candidate.prompt}`);
    return parts.join('\n');
  }

  private insert(candidate: ContradictionCandidate): void {
    this.onInsert(this.composeCandidate(candidate));
  }

  private startEdit(candidate: ContradictionCandidate): void {
    this.editingKey = this.candidateKey(candidate);
    this.editText = this.composeCandidate(candidate);
  }

  private candidateKey(candidate: ContradictionCandidate): string {
    return `${candidate.gap}|${candidate.prompt}`;
  }

  private isIgnored(candidate: ContradictionCandidate): boolean {
    return this.ignoredKeys.includes(this.candidateKey(candidate));
  }

  private visibleCandidates(): ContradictionCandidate[] {
    return this.candidates.filter((candidate: ContradictionCandidate) => !this.isIgnored(candidate));
  }

  private toggleIgnore(candidate: ContradictionCandidate): void {
    const key = this.candidateKey(candidate);
    if (this.ignoredKeys.includes(key)) {
      this.ignoredKeys = this.ignoredKeys.filter((item: string) => item !== key);
    } else {
      this.ignoredKeys = this.ignoredKeys.concat([key]);
    }
  }

  private uncertaintyText(value: string | undefined): string {
    if (value === 'low') {
      return '低';
    }
    if (value === 'medium') {
      return '中';
    }
    if (value === 'high') {
      return '高';
    }
    return '';
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
      },
      onRemove: (id: string) => {
        this.confirmItems = this.confirmItems.filter((item: ConfirmSheetItem) => item.id !== id);
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

      Row({ space: 6 }) {
        Text('事实密级')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)
          .width(64)
        Text('可分析')
          .fontSize(AppTheme.font.caption)
          .fontColor(this.factsLevelValue === SecurityLevel.ANALYZABLE ? Color.White : AppTheme.color.text)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(this.factsLevelValue === SecurityLevel.ANALYZABLE ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id('agent_level_facts_analyzable')
          .enabled(this.canUseLevel(SecurityLevel.ANALYZABLE))
          .opacity(this.canUseLevel(SecurityLevel.ANALYZABLE) ? 1 : 0.45)
          .onClick(() => {
            if (this.canUseLevel(SecurityLevel.ANALYZABLE)) {
              this.factsLevelValue = SecurityLevel.ANALYZABLE;
            }
          })
        Text('仅本地')
          .fontSize(AppTheme.font.caption)
          .fontColor(this.factsLevelValue === SecurityLevel.LOCAL_ONLY ? Color.White : AppTheme.color.text)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(this.factsLevelValue === SecurityLevel.LOCAL_ONLY ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id('agent_level_facts_local')
          .onClick(() => {
            this.factsLevelValue = SecurityLevel.LOCAL_ONLY;
          })
        Text('已封存')
          .fontSize(AppTheme.font.caption)
          .fontColor(this.factsLevelValue === SecurityLevel.SEALED ? Color.White : AppTheme.color.text)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(this.factsLevelValue === SecurityLevel.SEALED ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id('agent_level_facts_sealed')
          .onClick(() => {
            this.factsLevelValue = SecurityLevel.SEALED;
          })
      }
      .width('100%')

      Row({ space: 6 }) {
        Text('解释密级')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)
          .width(64)
        Text('可分析')
          .fontSize(AppTheme.font.caption)
          .fontColor(this.interpretationLevelValue === SecurityLevel.ANALYZABLE ? Color.White : AppTheme.color.text)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(this.interpretationLevelValue === SecurityLevel.ANALYZABLE ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id('agent_level_interpretation_analyzable')
          .enabled(this.canUseLevel(SecurityLevel.ANALYZABLE))
          .opacity(this.canUseLevel(SecurityLevel.ANALYZABLE) ? 1 : 0.45)
          .onClick(() => {
            if (this.canUseLevel(SecurityLevel.ANALYZABLE)) {
              this.interpretationLevelValue = SecurityLevel.ANALYZABLE;
            }
          })
        Text('仅本地')
          .fontSize(AppTheme.font.caption)
          .fontColor(this.interpretationLevelValue === SecurityLevel.LOCAL_ONLY ? Color.White : AppTheme.color.text)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(this.interpretationLevelValue === SecurityLevel.LOCAL_ONLY ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id('agent_level_interpretation_local')
          .onClick(() => {
            this.interpretationLevelValue = SecurityLevel.LOCAL_ONLY;
          })
        Text('已封存')
          .fontSize(AppTheme.font.caption)
          .fontColor(this.interpretationLevelValue === SecurityLevel.SEALED ? Color.White : AppTheme.color.text)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(this.interpretationLevelValue === SecurityLevel.SEALED ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id('agent_level_interpretation_sealed')
          .onClick(() => {
            this.interpretationLevelValue = SecurityLevel.SEALED;
          })
      }
      .width('100%')

      Column({ space: 6 }) {
        Row() {
          Text('涉及他人')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
          Blank()
          if (this.relationInvolvedByMaterial) {
            Text('由引用关系材料带入')
              .id('agent_relation_forced')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.primaryDeep)
          } else {
            Text(this.relationInvolved ? '已开启' : '未开启')
              .id('agent_relation_toggle')
              .fontSize(AppTheme.font.caption)
              .fontColor(this.relationInvolved ? Color.White : AppTheme.color.text)
              .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
              .backgroundColor(this.relationInvolved ? AppTheme.color.primary : AppTheme.color.chip)
              .borderRadius(AppTheme.radius.sm)
              .onClick(() => {
                this.relationInvolved = !this.relationInvolved;
              })
          }
        }
        .width('100%')

        if (this.materialRelationInvolved()) {
          if (this.relationInvolvedByMaterial) {
            Text(`关系：${this.relationIdHint}`)
              .id('agent_relation_id_fixed')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.text)
              .width('100%')
          } else {
            TextInput({ text: this.relationIdText, placeholder: '关系别名或编号（必填）' })
              .id('agent_relation_id')
              .fontSize(AppTheme.font.caption)
              .backgroundColor(AppTheme.color.surfaceAlt)
              .onChange((value: string) => {
                this.relationIdText = value;
              })
          }
          TextInput({ text: this.relationBoundaryText, placeholder: '可以分析什么、不能分析什么（必填）' })
            .id('agent_relation_boundary')
            .fontSize(AppTheme.font.caption)
            .backgroundColor(AppTheme.color.surfaceAlt)
            .onChange((value: string) => {
              this.relationBoundaryText = value;
            })
          Text('未绑定关系或未写分析边界时，不会调用模型。')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.danger)
            .width('100%')
        }
      }
      .width('100%')

      Text('只有「可分析」的文字会进入请求清单；仅本地与已封存会留在本机。')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
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
        if (this.ignoredKeys.length > 0) {
          Row({ space: 6 }) {
            Text(`已忽略 ${this.ignoredKeys.length} 条`)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .layoutWeight(1)
            Text('全部恢复')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.primary)
              .onClick(() => {
                this.ignoredKeys = [];
              })
          }
          .width('100%')
        }

        ForEach(this.visibleCandidates(), (candidate: ContradictionCandidate) => {
          Column({ space: 4 }) {
            Text(candidate.gap)
              .fontSize(AppTheme.font.bodyStrong)
              .lineHeight(19)
              .fontColor(AppTheme.color.text)
              .width('100%')
            if ((candidate.basis ?? '').trim().length > 0) {
              Text(`依据：${(candidate.basis as string).trim()}`)
                .fontSize(AppTheme.font.caption)
                .lineHeight(16)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            }
            if ((candidate.unknowns ?? '').trim().length > 0) {
              Text(`未知：${(candidate.unknowns as string).trim()}`)
                .fontSize(AppTheme.font.caption)
                .lineHeight(16)
                .fontColor(AppTheme.color.warning)
                .width('100%')
            }
            Text(candidate.prompt)
              .fontSize(AppTheme.font.body)
              .lineHeight(17)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            Row({ space: 6 }) {
              if (this.uncertaintyText(candidate.uncertainty).length > 0) {
                Text(`不确定度 ${this.uncertaintyText(candidate.uncertainty)}`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textSecondary)
                  .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                  .backgroundColor(AppTheme.color.chip)
                  .borderRadius(AppTheme.radius.sm)
              }
              Blank()
              Text('忽略')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textSecondary)
                .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                .backgroundColor(AppTheme.color.surface)
                .borderRadius(AppTheme.radius.sm)
                .onClick(() => {
                  this.toggleIgnore(candidate);
                })
              Text('改写')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textSecondary)
                .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                .backgroundColor(AppTheme.color.surface)
                .borderRadius(AppTheme.radius.sm)
                .onClick(() => {
                  this.startEdit(candidate);
                })
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

            if (this.editingKey === this.candidateKey(candidate)) {
              TextArea({ text: this.editText })
                .id('agent_candidate_edit')
                .fontSize(AppTheme.font.body)
                .height(120)
                .padding(AppTheme.spacing.s8)
                .backgroundColor(AppTheme.color.surface)
                .borderRadius(AppTheme.radius.sm)
                .onChange((value: string) => {
                  this.editText = value;
                })
              Row({ space: AppTheme.spacing.s8 }) {
                Text('取消改写')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textSecondary)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                  .backgroundColor(AppTheme.color.surface)
                  .borderRadius(AppTheme.radius.sm)
                  .onClick(() => {
                    this.editingKey = '';
                    this.editText = '';
                  })
                Text('填入改写')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(Color.White)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                  .backgroundColor(AppTheme.color.primary)
                  .borderRadius(AppTheme.radius.sm)
                  .onClick(() => {
                    this.onInsert(this.editText);
                    this.editingKey = '';
                    this.editText = '';
                  })
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
        }, (candidate: ContradictionCandidate) => this.candidateKey(candidate))
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
