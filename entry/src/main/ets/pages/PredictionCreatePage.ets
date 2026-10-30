import { AppTheme } from '../theme/AppTheme';
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

const EMPTY_ERRORS: PredictionDraftErrors = {
  target: '',
  judgment: '',
  confidence: '',
  settlementDate: ''
};

/** Creates one prediction; nothing is persisted until the commit button is pressed. */
@ComponentV2
export struct PredictionCreatePage {
  @Local target: string = '';
  @Local judgment: string = '';
  @Local reason: string = '';
  @Local confidence: number = 70;
  @Local settlementDate: string = '';
  @Local errors: PredictionDraftErrors = EMPTY_ERRORS;
  @Local isSaving: boolean = false;
  @Local sourceId: string | null = null;
  @Local sourceVersion: number = 0;
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
    this.confidence = detail.confidence;
    this.reason = detail.reason;
    this.sourceVersion = detail.version;
  }

  private useDeadline(days: number): void {
    this.settlementDate = dateAfterDays(Date.now(), days);
    this.errors = { target: this.errors.target, judgment: this.errors.judgment,
      confidence: this.errors.confidence, settlementDate: '' };
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const draft: PredictionDraft = {
      target: this.target,
      judgment: this.judgment,
      confidence: this.confidence,
      reason: this.reason,
      settlementDate: this.settlementDate
    };
    const errors = validatePredictionDraft(draft);
    this.errors = errors;
    if (hasPredictionErrors(errors)) {
      return;
    }

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
        .fontSize(10)
        .fontColor(AppTheme.color.danger)
        .width('100%')
    }
  }

  @Builder
  deadlineChip(label: string, days: number) {
    Text(label)
      .fontSize(11)
      .fontColor(AppTheme.color.primaryDeep)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(AppTheme.color.tint)
      .borderRadius(12)
      .onClick(() => {
        this.useDeadline(days);
      })
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            SectionCard() {
              Column({ space: 6 }) {
                Text('预测对象')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextInput({ placeholder: '例如：本周作息', text: this.target })
                  .maxLength(MAX_TARGET_LENGTH)
                  .backgroundColor('#F7F6F2')
                  .onChange((value: string) => {
                    this.target = value;
                  })
                this.fieldError(this.errors.target)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text('判断')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextArea({ placeholder: '写成到期能判断真假的句子', text: this.judgment })
                  .height(84)
                  .maxLength(MAX_JUDGMENT_LENGTH)
                  .backgroundColor('#F7F6F2')
                  .onChange((value: string) => {
                    this.judgment = value;
                  })
                Text('需要同时包含数量与期限，结算时才有依据')
                  .fontSize(10)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                this.fieldError(this.errors.judgment)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Row() {
                  Text('置信度')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                  Blank()
                  Text(`${this.confidence}%`)
                    .fontSize(13)
                    .fontColor(AppTheme.color.primary)
                }
                .width('100%')

                Slider({ value: this.confidence, min: 1, max: 100, step: 1 })
                  .width('100%')
                  .selectedColor(AppTheme.color.primary)
                  .onChange((value: number) => {
                    this.confidence = Math.round(value);
                  })
                this.fieldError(this.errors.confidence)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 8 }) {
                Text('结算日')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Row({ space: 6 }) {
                  this.deadlineChip('7 天后', 7)
                  this.deadlineChip('14 天后', 14)
                  this.deadlineChip('30 天后', 30)
                }
                TextInput({ placeholder: 'YYYY-MM-DD', text: this.settlementDate })
                  .backgroundColor('#F7F6F2')
                  .onChange((value: string) => {
                    this.settlementDate = value;
                  })
                this.fieldError(this.errors.settlementDate)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text('理由（可选）')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextArea({ placeholder: '当时为什么这么判断？', text: this.reason })
                  .height(72)
                  .maxLength(MAX_REASON_LENGTH)
                  .backgroundColor('#F7F6F2')
                  .onChange((value: string) => {
                    this.reason = value;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            Text('提交后不可修改；到期后才能结算，结算日用于排序与提醒。')
              .fontSize(10)
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
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor(this.isSaving ? '#8FA6C4' : AppTheme.color.primary)
            .borderRadius(12)
            .onClick(() => {
              if (!this.isSaving) {
                this.save();
              }
            })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: 8, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title(this.sourceId === null ? '新建预测' : '修改预测')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param !== undefined) {
        const params = context.pathInfo.param as PredictionCreateParams;
        if (params.sourcePredictionId !== null) {
          this.loadSource(params.sourcePredictionId);
        }
      }
    })
  }
}
