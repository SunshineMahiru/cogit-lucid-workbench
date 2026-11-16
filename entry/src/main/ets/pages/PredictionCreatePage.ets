import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import {
  MAX_JUDGMENT_LENGTH,
  MAX_REASON_LENGTH,
  MAX_TARGET_LENGTH,
  PredictionDetail,
  PredictionDraft,
  PredictionDraftErrors,
  PredictionService,
  dateAfterDays,
  hasPredictionErrors,
  validatePredictionDraft
} from '../prediction';
import { PredictionCreateParams } from '../navigation/RouteParams';
import { previewStore } from '../preview/PreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Creates one prediction; nothing is persisted until the commit button is pressed. */
@ComponentV2
export struct PredictionCreatePage {
  @Local target: string = '';
  @Local judgment: string = '';
  @Local reason: string = '';
  @Local confidence: number = 70;
  @Local confidenceUnknown: boolean = false;
  @Local scope: string = '';
  @Local falsification: string = '';
  @Local unknowns: string = '';
  @Local evidenceLevel: string = '';
  @Local settlementDate: string = '';
  @Local errors: PredictionDraftErrors = {
    target: '',
    judgment: '',
    confidence: '',
    settlementDate: ''
  };
  @Local isSaving: boolean = false;
  @Local isDirty: boolean = false;
  @Local sourceId: string | null = null;
  @Local sourceVersion: number = 0;
  @Local revisionReason: string = '';
  @Local invalidated: string = '';
  @Local preserved: string = '';
  @Local repositioned: string = '';
  @Local revisionError: string = '';
  @Local falsificationError: string = '';
  private navStack: NavPathStack | null = null;

  aboutToAppear(): void {
    this.settlementDate = dateAfterDays(Date.now(), 7);
  }

  private async loadSource(id: string): Promise<void> {
    this.sourceId = id;
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      const detail = previewStore.findPrediction(id);
      if (detail !== null) {
        this.applySource(detail);
      }
      return;
    }
    try {
      const service = await PredictionService.open(hostContext);
      const detail = await service.find(id);
      if (detail !== null) {
        this.applySource(detail);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '原预测读取失败' });
    }
  }

  private applySource(detail: PredictionDetail): void {
    this.target = detail.target;
    this.judgment = detail.judgment;
    if (detail.confidence !== null) {
      this.confidence = detail.confidence;
    }
    this.confidenceUnknown = detail.confidence === null;
    this.scope = detail.scope ?? '';
    this.falsification = detail.falsification ?? '';
    this.unknowns = detail.unknowns ?? '';
    this.evidenceLevel = detail.evidenceLevel ?? '';
    this.reason = detail.reason;
    this.sourceVersion = detail.version;
  }

  private useDeadline(days: number): void {
    this.settlementDate = dateAfterDays(Date.now(), days);
    this.isDirty = true;
    this.errors = { target: this.errors.target, judgment: this.errors.judgment,
      confidence: this.errors.confidence, settlementDate: '' };
  }

  /** Toggles the unquantified state; the numeric value stays so switching back restores it. */
  private setConfidenceUnknown(unknown: boolean): void {
    this.confidenceUnknown = unknown;
    this.isDirty = true;
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const draft: PredictionDraft = {
      target: this.target,
      judgment: this.judgment,
      confidence: this.confidenceUnknown ? null : this.confidence,
      reason: this.reason,
      settlementDate: this.settlementDate,
      scope: this.scope,
      falsification: this.falsification,
      unknowns: this.unknowns,
      evidenceLevel: this.evidenceLevel
    };
    if (this.sourceId !== null) {
      draft.revisionReason = this.revisionReason;
      draft.invalidated = this.invalidated;
      draft.preserved = this.preserved;
      draft.repositioned = this.repositioned;
    }
    const errors = validatePredictionDraft(draft);
    this.errors = errors;
    if (hasPredictionErrors(errors)) {
      const first = errors.target.length > 0 ? errors.target :
        (errors.judgment.length > 0 ? errors.judgment :
          (errors.confidence.length > 0 ? errors.confidence : errors.settlementDate));
      this.getUIContext().getPromptAction().showToast({ message: first });
      return;
    }
    if (this.sourceId !== null && this.revisionReason.trim().length === 0) {
      this.revisionError = '写一句这次修订的原因';
      return;
    }
    if (this.falsification.trim().length === 0) {
      this.falsificationError = '请填写失效条件：出现什么情况就说明这条预测不成立';
      return;
    }
    this.falsificationError = '';
    if (this.sourceId !== null) {
      if (this.invalidated.trim().length === 0) {
        this.revisionError = '写清这一版不再成立的内容';
        return;
      }
      if (this.preserved.trim().length === 0) {
        this.revisionError = '写清仍然成立、要保留的内容';
        return;
      }
      if (this.repositioned.trim().length === 0) {
        this.revisionError = '写清这一版放在什么位置、针对什么范围';
        return;
      }
    }
    this.revisionError = '';

    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      const saved = this.sourceId === null ? previewStore.createPrediction(draft) :
        previewStore.revisePrediction(this.sourceId, draft);
      if (saved === null) {
        this.getUIContext().getPromptAction().showToast({ message: '原预测不存在' });
        return;
      }
      notifyHomeRefresh();
      this.getUIContext().getPromptAction().showToast({
        message: this.sourceId === null ? '演示模式：预测已保存在当前会话' : `演示模式：已生成第 ${saved.version} 版`
      });
      this.isDirty = false;
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
      return;
    }
    this.isSaving = true;
    try {
      const service = await PredictionService.open(hostContext);
      const saved = this.sourceId === null ? await service.create(draft) : await service.revise(this.sourceId, draft);
      notifyHomeRefresh();
      this.getUIContext().getPromptAction().showToast({
        message: this.sourceId === null ? '预测已保存，不能修改' : `已生成第 ${saved.version} 版预测`
      });
      this.isDirty = false;
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  fieldError(message: string) {
    if (message.length > 0) {
      Text(message)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.danger)
        .width('100%')
    }
  }

  @Builder
  deadlineChip(label: string, days: number) {
    Text(label)
      .fontSize(AppTheme.font.body)
      .fontColor(AppTheme.color.primaryDeep)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(AppTheme.color.tint)
      .borderRadius(AppTheme.radius.md)
      .onClick(() => {
        this.useDeadline(days);
      })
  }

  @Builder
  confidenceChip(label: string, id: string) {
    Text(label)
      .id(id)
      .fontSize(AppTheme.font.body)
      .fontColor(this.confidenceUnknown ? AppTheme.color.primaryDeep : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.confidenceUnknown ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.setConfidenceUnknown(!this.confidenceUnknown);
      })
  }

  build() {
    AppDestination({
      route: 'prediction_create',
      title: this.sourceId === null ? '新建预测' : '修改预测',
      content: () => {
        this.predictionCreateBody();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param !== undefined) {
          const params = context.pathInfo.param as PredictionCreateParams;
          if (params.sourcePredictionId !== null) {
            this.loadSource(params.sourcePredictionId);
          }
        }
      },
      onDestinationBackPressed: () => {
        if (!this.isDirty) {
          return false;
        }
        this.getUIContext().showAlertDialog({
          title: '放弃这条预测？',
          message: '已填写的内容不会保存。',
          primaryButton: {
            value: '继续编辑',
            action: () => {
            }
          },
          secondaryButton: {
            value: '放弃',
            action: () => {
              this.isDirty = false;
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          }
        });
        return true;
      }
    })
  }

  @Builder
  predictionCreateBody() {
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            SectionCard() {
              Column({ space: 6 }) {
                Text('预测对象')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextInput({ placeholder: '例如：本周作息', text: this.target })
                  .id('prediction_target')
                  .maxLength(MAX_TARGET_LENGTH)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.target = value;
                    this.isDirty = true;
                  })
                this.fieldError(this.errors.target)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text('判断')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextArea({ placeholder: '写成到期能判断真假的句子', text: this.judgment })
                  .id('prediction_judgment')
                  .height(84)
                  .maxLength(MAX_JUDGMENT_LENGTH)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.judgment = value;
                    this.isDirty = true;
                  })
                Text('需要同时包含数量与期限，结算时才有依据')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                this.fieldError(this.errors.judgment)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text('模型卡（可选）')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Text('适用范围')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                TextArea({ placeholder: '这条预测在什么时间、场景或人群内成立', text: this.scope })
                  .id('prediction_scope')
                  .height(56)
                  .maxLength(MAX_REASON_LENGTH)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.scope = value;
                    this.isDirty = true;
                  })
                Text('失效条件（必填）')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                TextArea({ placeholder: '出现什么情况就说明这条预测不成立', text: this.falsification })
                  .id('prediction_falsification')
                  .height(56)
                  .maxLength(MAX_REASON_LENGTH)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.falsification = value;
                    this.falsificationError = '';
                    this.isDirty = true;
                  })
                this.fieldError(this.falsificationError)
                Text('未知项')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                TextArea({ placeholder: '现在还拿不准、可能影响判断的因素', text: this.unknowns })
                  .id('prediction_unknowns')
                  .height(56)
                  .maxLength(MAX_REASON_LENGTH)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.unknowns = value;
                    this.isDirty = true;
                  })
                Text('证据来源')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                TextArea({ placeholder: '这条判断依据什么材料或经验', text: this.evidenceLevel })
                  .id('prediction_evidence_level')
                  .height(56)
                  .maxLength(MAX_REASON_LENGTH)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.evidenceLevel = value;
                    this.isDirty = true;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 8 }) {
                Row() {
                  Text('置信度')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                  Blank()
                  Text(this.confidenceUnknown ? '无法量化' : `${this.confidence}%`)
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.primary)
                }
                .width('100%')

                if (!this.confidenceUnknown) {
                  Slider({ value: this.confidence, min: 0, max: 100, step: 1 })
                    .width('100%')
                    .selectedColor(AppTheme.color.primary)
                    .onChange((value: number) => {
                      this.confidence = Math.round(value);
                      this.isDirty = true;
                    })
                }
                Row({ space: 6 }) {
                  this.confidenceChip('无法量化', 'confidence_unknown')
                }
                this.fieldError(this.errors.confidence)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 8 }) {
                Text('结算日（可选）')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Row({ space: 6 }) {
                  this.deadlineChip('今天', 0)
                  this.deadlineChip('7 天后', 7)
                  this.deadlineChip('14 天后', 14)
                  this.deadlineChip('30 天后', 30)
                }
                TextInput({ placeholder: 'YYYY-MM-DD（留空表示不设期限）', text: this.settlementDate })
                  .id('prediction_date')
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.settlementDate = value;
                    this.isDirty = true;
                  })
                Text('没有期限的预测可以随时结算；结算时把当天记为结算日。')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                this.fieldError(this.errors.settlementDate)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text('理由（可选）')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextArea({ placeholder: '当时为什么这么判断？', text: this.reason })
                  .id('prediction_reason')
                  .height(72)
                  .maxLength(MAX_REASON_LENGTH)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .onChange((value: string) => {
                    this.reason = value;
                    this.isDirty = true;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.sourceId !== null) {
              SectionCard() {
                Column({ space: 6 }) {
                  Text('修订原因（必填）')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  TextArea({ placeholder: '这一版为什么改？', text: this.revisionReason })
                    .height(64)
                    .maxLength(MAX_REASON_LENGTH)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .onChange((value: string) => {
                      this.revisionReason = value;
                      this.revisionError = '';
                      this.isDirty = true;
                    })
                  this.fieldError(this.revisionError)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('取消什么')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  TextArea({ placeholder: '这一版不再成立的内容', text: this.invalidated })
                    .height(56)
                    .maxLength(MAX_REASON_LENGTH)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .onChange((value: string) => {
                      this.invalidated = value;
                      this.revisionError = '';
                      this.isDirty = true;
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('保存什么')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  TextArea({ placeholder: '仍然成立、要保留的内容', text: this.preserved })
                    .height(56)
                    .maxLength(MAX_REASON_LENGTH)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .onChange((value: string) => {
                      this.preserved = value;
                      this.revisionError = '';
                      this.isDirty = true;
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('重新定位')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  TextArea({ placeholder: '这一版放在什么位置、针对什么范围', text: this.repositioned })
                    .height(56)
                    .maxLength(MAX_REASON_LENGTH)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .onChange((value: string) => {
                      this.repositioned = value;
                      this.revisionError = '';
                      this.isDirty = true;
                    })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }

            Text('提交后不可修改；结算日不能早于今天，当天到期的预测当天即可结算。')
              .fontSize(AppTheme.font.caption)
              .lineHeight(17)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          }
          .width('100%')
          .padding(AppTheme.spacing.page)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Column() {
          Text(this.isSaving ? '保存中…' : (this.sourceId === null ? '保存这条预测' : '生成新版本'))
            .id('prediction_save')
            .fontSize(AppTheme.font.subtitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
            .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
            .borderRadius(AppTheme.radius.md)
            .accessibilityText(this.isSaving ? '正在保存预测' : (this.sourceId === null ? '保存预测' : '生成新版本预测'))
            .onClick(() => {
              if (!this.isSaving) {
                this.save();
              }
            })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }
}
