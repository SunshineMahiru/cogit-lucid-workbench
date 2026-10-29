import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { PredictionDetail, PredictionService, todayDateString } from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { PredictionSettleParams } from '../navigation/RouteParams';
import { previewStore } from '../preview/PreviewStore';

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
  @Local hitChoice: string = '';
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
    if (this.hitChoice.length === 0) {
      this.errorText = '请选择命中或未命中';
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      const updated = previewStore.settlePrediction(this.predictionId, this.actualResult, this.hitChoice === 'hit');
      if (updated === null) {
        this.errorText = '结算失败：这条预测可能已经结算';
        return;
      }
      this.getUIContext().getPromptAction().showToast({
        message: updated.hit === true ? '演示模式：已结算命中' : '演示模式：已结算未命中'
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
      const updated = await service.settle(this.predictionId, this.actualResult, this.hitChoice === 'hit');
      if (updated === null) {
        this.missing = true;
        return;
      }
      this.getUIContext().getPromptAction().showToast({
        message: updated.hit === true ? '已结算：命中' : '已结算：未命中'
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
  hitChip(label: string, value: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.hitChoice === value ? Color.White : AppTheme.color.text)
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .backgroundColor(this.hitChoice === value ? AppTheme.color.primary : '#F1EFE8')
      .borderRadius(16)
      .onClick(() => {
        this.hitChoice = value;
        this.errorText = '';
      })
  }

  build() {
    NavDestination() {
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
        .backgroundColor(AppTheme.color.page)
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
        .backgroundColor(AppTheme.color.page)
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
        .backgroundColor(AppTheme.color.page)
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
        .backgroundColor(AppTheme.color.page)
      } else {
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              SectionCard() {
                Column({ space: 6 }) {
                  Text(this.detail.target)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text(this.detail.judgment)
                    .fontSize(13)
                    .lineHeight(21)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text(`置信度 ${this.detail.confidence}% · 结算日 ${this.detail.settlementDate}`)
                    .fontSize(10)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('实际结果')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  TextArea({ placeholder: '实际发生了什么？只写可核对的事实', text: this.actualResult })
                    .height(96)
                    .maxLength(200)
                    .backgroundColor('#F7F6F2')
                    .onChange((value: string) => {
                      this.actualResult = value;
                    })
                  Text('这条结果会与原始判断一起保留，用于命中率统计')
                    .fontSize(10)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('判定')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row({ space: 10 }) {
                    this.hitChip('命中', 'hit')
                    this.hitChip('未命中', 'miss')
                  }
                  if (this.errorText.length > 0) {
                    Text(this.errorText)
                      .fontSize(10)
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
    }
    .title('结算预测')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param === undefined) {
        this.isLoading = false;
        this.missing = true;
        return;
      }
      const params = context.pathInfo.param as PredictionSettleParams;
      this.load(params.predictionId);
    })
  }
}
