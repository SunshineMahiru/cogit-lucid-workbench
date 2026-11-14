import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { PredictionDetail, PredictionService, todayDateString } from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { outcomeLabel, PredictionOutcome } from '../model/PredictionOutcome';
import { PredictionSettleParams } from '../navigation/RouteParams';
import { previewStore } from '../preview/PreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Settles one pending prediction; the result and hit flag are written once. */
@ComponentV2
export struct PredictionSettlePage {
  @Local detail: PredictionDetail = {
    id: '',
    target: '',
    judgment: '',
    confidence: 0,
    reason: '',
    settlementDate: '',
    status: PredictionStatus.PENDING,
    actualResult: '',
    hit: null,
    version: 1,
    createdAtLabel: ''
  };
  @Local actualResult: string = '';
  @Local outcomeChoice: string = '';
  /** Evidence source recorded beside the result; optional. */
  @Local evidenceChoice: string = '';
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local alreadySettled: boolean = false;
  @Local isDue: boolean = true;
  @Local isSaving: boolean = false;
  @Local errorText: string = '';
  @Local isPreview: boolean = false;
  private predictionId: string = '';
  private navStack: NavPathStack | null = null;

  private async load(id: string): Promise<void> {
    this.predictionId = id;
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview(id);
      return;
    }
    try {
      const service = await PredictionService.open(hostContext);
      const detail = await service.find(id);
      if (detail === null) {
        this.missing = true;
      } else {
        this.detail = detail;
        this.alreadySettled = detail.status !== PredictionStatus.PENDING;
        this.isDue = todayDateString() >= detail.settlementDate;
      }
    } catch (error) {
      this.loadPreview(id);
    } finally {
      this.isLoading = false;
    }
  }

  private loadPreview(id: string): void {
    this.isPreview = true;
    const detail = previewStore.findPrediction(id);
    if (detail === null) {
      this.missing = true;
    } else {
      this.detail = detail;
      this.alreadySettled = detail.status !== PredictionStatus.PENDING;
      this.isDue = todayDateString() >= detail.settlementDate;
    }
    this.isLoading = false;
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.actualResult.trim().length === 0) {
      this.errorText = '请填写实际结果';
      return;
    }
    if (this.outcomeChoice.length === 0) {
      this.errorText = '请选择一种判定';
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      const binary = this.outcomeChoice === 'hold' || this.outcomeChoice === 'fail';
      if (!binary) {
        this.errorText = '演示模式只支持成立与未成立';
        return;
      }
      const updated = previewStore.settlePrediction(this.predictionId, this.actualResult, this.outcomeChoice === 'hold');
      if (updated === null) {
        this.errorText = '结算失败：这条预测可能已经结算';
        return;
      }
      notifyHomeRefresh();
      this.getUIContext().getPromptAction().showToast({
        message: updated.hit === true ? '演示模式：已结算成立' : '演示模式：已结算未成立'
      });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
      return;
    }
    this.errorText = '';
    this.isSaving = true;
    try {
      const service = await PredictionService.open(hostContext);
      const updated = await service.settle(this.predictionId, this.actualResult,
        this.outcomeChoice as PredictionOutcome, this.evidenceChoice);
      if (updated === null) {
        this.missing = true;
        return;
      }
      notifyHomeRefresh();
      this.getUIContext().getPromptAction().showToast({
        message: `已结算：${outcomeLabel(this.outcomeChoice)}`
      });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.errorText = '结算失败：这条预测可能已经结算';
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  evidenceChip(label: string, value: string) {
    Text(label)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.evidenceChoice === value ? Color.White : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.evidenceChoice === value ? AppTheme.color.primaryDeep : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.evidenceChoice = this.evidenceChoice === value ? '' : value;
      })
  }

  @Builder
  outcomeChip(label: string, value: string) {
    Text(label)
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.outcomeChoice === value ? Color.White : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
      .backgroundColor(this.outcomeChoice === value ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.outcomeChoice = value;
        this.errorText = '';
      })
  }

  build() {
    AppDestination({
      route: 'prediction_settle',
      title: '结算预测',
      content: () => {
        this.predictionSettleBody();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          this.missing = true;
          return;
        }
        const params = context.pathInfo.param as PredictionSettleParams;
        this.load(params.predictionId);
      }
    })
  }

  @Builder
  predictionSettleBody() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppTheme.color.primary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      } else if (this.missing) {
        Column() {
          NoteEmptyState({
            title: '预测不存在',
            hint: '可能已经被删除',
            actionLabel: '返回',
            onAction: () => {
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      } else if (this.alreadySettled) {
        Column() {
          NoteEmptyState({
            title: '这条预测已结算',
            hint: '结算结果不可修改',
            actionLabel: '返回',
            onAction: () => {
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      } else if (!this.isDue) {
        Column() {
          NoteEmptyState({
            title: '还没到结算日',
            hint: `到期日 ${this.detail.settlementDate}，到期后再结算`,
            actionLabel: '返回',
            onAction: () => {
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      } else {
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              SectionCard() {
                Column({ space: 6 }) {
                  Text(this.detail.target)
                    .fontSize(AppTheme.font.title)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text(this.detail.judgment)
                    .fontSize(AppTheme.font.bodyStrong)
                    .lineHeight(21)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text(`置信度 ${this.detail.confidence}% · 结算日 ${this.detail.settlementDate}`)
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('实际结果')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  TextArea({ placeholder: '实际发生了什么？只写可核对的事实', text: this.actualResult })
                    .height(96)
                    .maxLength(200)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .onChange((value: string) => {
                      this.actualResult = value;
                    })
                  Text('这条结果会与原始判断一起保留，用于命中率统计')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('判定')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row({ space: 8 }) {
                    this.outcomeChip('成立', 'hold')
                    this.outcomeChip('未成立', 'fail')
                    this.outcomeChip('部分成立', 'partial')
                  }
                  Row({ space: 8 }) {
                    this.outcomeChip('证据不足', 'insufficient')
                    this.outcomeChip('无法判断', 'undecidable')
                  }
                  Text('成立与未成立进入命中率；其余三种单列，不参与分母。')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                  Text('证据来源（可选）')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row({ space: 8 }) {
                    this.evidenceChip('现场记录', 'practice')
                    this.evidenceChip('对方陈述', 'other')
                    this.evidenceChip('共同实践', 'joint')
                  }
                  Row({ space: 8 }) {
                    this.evidenceChip('身体反馈', 'body')
                    this.evidenceChip('时间经历', 'time')
                    this.evidenceChip('公共资料', 'public')
                  }
                  if (this.errorText.length > 0) {
                    Text(this.errorText)
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.danger)
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)

          Column() {
            Text(this.isSaving ? '结算中…' : '确认结算')
              .fontSize(AppTheme.font.subtitle)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
              .borderRadius(AppTheme.radius.md)
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
}
