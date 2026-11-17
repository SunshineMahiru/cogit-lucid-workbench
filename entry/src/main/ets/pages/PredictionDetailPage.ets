import {
  PredictionDetail,
  PredictionService,
  predictionHitText,
  predictionStatusText,
  todayDateString
} from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { outcomeFromLegacy, PredictionOutcome } from '../model/PredictionOutcome';
import { PredictionDetailParams, PredictionSettleParams, PredictionCreateParams, PlanAttachParams } from '../navigation/RouteParams';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { ROUTES } from '../navigation/Routes';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { previewStore } from '../preview/PreviewStore';

/** One label/value row; kept as a child component so async detail reloads re-render it. */
@ComponentV2
struct PredictionInfoRow {
  @Param label: string = '';
  @Param value: string = '';

  build() {
    Row({ space: 12 }) {
      Text(this.label)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
      Text(this.value)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.text)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
  }
}

/** Read-only view of one prediction, including its settlement result. */
@ComponentV2
export struct PredictionDetailPage {
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
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local isPreview: boolean = false;
  @Local versions: PredictionDetail[] = [];
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  private openSettle(): void {
    if (this.navStack === null) {
      return;
    }
    const params: PredictionSettleParams = { predictionId: this.detail.id };
    this.navStack.pushPathByName(ROUTES.PREDICTION_SETTLE, params);
  }

  private openRevise(): void {
    if (this.navStack === null || this.detail.id.length === 0) {
      return;
    }
    const params: PredictionCreateParams = { sourcePredictionId: this.detail.id };
    this.navStack.pushPathByName(ROUTES.PREDICTION_CREATE, params, () => {
      this.load(this.detail.id);
    });
  }

  private openAttach(): void {
    if (this.navStack === null || this.detail.id.length === 0) {
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.PREDICTION,
      targetId: this.detail.id,
      label: this.detail.target
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  @Builder
  reviseMenu() {
    Row() {
      Text('计划')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s6 })
        .onClick(() => {
          this.openAttach();
        })
      Text('修改')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s16 })
        .onClick(() => {
          this.openRevise();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  private async load(id: string): Promise<void> {
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
        try {
          this.versions = await service.versions(detail.id);
        } catch (error) {
          this.versions = [];
        }
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
    }
    this.isLoading = false;
  }

  private tagColor(): string {
    if (this.detail.status === PredictionStatus.PENDING) {
      return AppTheme.color.warning;
    }
    return this.detail.hit === true ? AppTheme.color.success : AppTheme.color.danger;
  }

  /** Stored outcome, or the hit flag for records settled before outcomes existed. */
  private settledOutcome(item: PredictionDetail): PredictionOutcome {
    const stored = item.outcome ?? '';
    return stored.length > 0 ? stored : outcomeFromLegacy(item.hit);
  }

  /** Settlement label for the status tag, covering pending rows and all five outcomes. */
  private resultText(item: PredictionDetail): string {
    return predictionStatusText(item.status, this.settledOutcome(item));
  }

  private confidenceText(item: PredictionDetail): string {
    return item.confidence === null ? '无法量化' : `${item.confidence}%`;
  }

  /** True when at least one model-card field carries text. */
  private hasModelCard(): boolean {
    return this.isFilled(this.detail.scope) || this.isFilled(this.detail.falsification) ||
      this.isFilled(this.detail.unknowns) || this.isFilled(this.detail.evidenceLevel) ||
      this.detail.version > 1 || this.detail.termOnly === true;
  }

  private isFilled(value: string | undefined): boolean {
    return value !== undefined && value.length > 0;
  }

  private tagBackground(): string {
    if (this.detail.status === PredictionStatus.PENDING) {
      return AppTheme.color.warningSurface;
    }
    return this.detail.hit === true ? AppTheme.color.successSurface : AppTheme.color.dangerSurface;
  }

  build() {
    AppDestination({
      route: 'prediction_detail',
      title: '预测详情',
      content: () => {
        this.predictionDetailBody();
      },
      menus: () => {
        this.reviseMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          this.missing = true;
          return;
        }
        const params = context.pathInfo.param as PredictionDetailParams;
        this.load(params.predictionId);
      },
      onDestinationShown: () => {
        if (this.hasShownOnce && this.detail.id.length > 0) {
          this.load(this.detail.id);
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }

  @Builder
  modelCardRow(label: string, value: string | undefined) {
    if (value !== undefined && value.length > 0) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
        Text(value)
          .fontSize(AppTheme.font.bodyStrong)
          .lineHeight(20)
          .fontColor(AppTheme.color.text)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  predictionDetailBody() {
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
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text(predictionStatusText(this.detail.status, this.settledOutcome(this.detail)))
                .fontSize(AppTheme.font.caption)
                .fontColor(this.tagColor())
                .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                .backgroundColor(this.tagBackground())
                .borderRadius(AppTheme.radius.sm)
              Text(this.confidenceText(this.detail))
                .fontSize(AppTheme.font.subtitle)
                .fontColor(AppTheme.color.primary)
              Blank()
              Text(`v${this.detail.version}`)
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.textMuted)
            }
            .width('100%')

            Text(this.detail.target)
              .fontSize(AppTheme.font.headline)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.color.text)
              .width('100%')

            Text(this.detail.judgment)
              .fontSize(AppTheme.font.subtitle)
              .lineHeight(24)
              .fontColor(AppTheme.color.text)
              .width('100%')

            if (this.hasModelCard()) {
              Column({ space: 8 }) {
                Text('假设卡')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                if (this.detail.termOnly === true) {
                  Text('仅术语增加，不计入重建：未说明新框架的额外解释力')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.warning)
                    .width('100%')
                }
                if (this.detail.version > 1 && (this.detail.preserved ?? '').trim().length === 0) {
                  Text('未填「旧框架在什么条件下仍然成立」')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.warning)
                    .width('100%')
                }
                this.modelCardRow('适用范围', this.detail.scope)
                this.modelCardRow('失效条件', this.detail.falsification)
                this.modelCardRow('未知项', this.detail.unknowns)
                this.modelCardRow('证据来源', this.detail.evidenceLevel)
                if (this.detail.version > 1) {
                  this.modelCardRow('修订原因', this.detail.revisionReason)
                  this.modelCardRow('取消', this.detail.invalidated)
                  this.modelCardRow('保存', this.detail.preserved)
                  this.modelCardRow('重新定位', this.detail.repositioned)
                  this.modelCardRow('失效来源', this.detail.missing)
                  this.modelCardRow('新增解释力', this.detail.explanatoryGain)
                }
              }
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(16)
              .border({ width: 0.5, color: AppTheme.color.border })
              .alignItems(HorizontalAlign.Start)
            }

            Column() {
              PredictionInfoRow({ label: '结算日', value: this.detail.settlementDate })
              PredictionInfoRow({
                label: '状态',
                value: this.resultText(this.detail)
              })
              if (this.detail.outcome !== undefined && this.detail.outcome.length > 0) {
                if (this.detail.evidenceLevel !== undefined && this.detail.evidenceLevel.length > 0) {
                  PredictionInfoRow({ label: '证据来源', value: this.detail.evidenceLevel })
                }
              } else {
                PredictionInfoRow({ label: '结算结果', value: predictionHitText(this.settledOutcome(this.detail)) })
              }
              PredictionInfoRow({
                label: '实际结果',
                value: this.detail.actualResult.length > 0 ? this.detail.actualResult : '—'
              })
              PredictionInfoRow({ label: '创建时间', value: this.detail.createdAtLabel })
            }
            .width('100%')
            .padding(AppTheme.spacing.s16)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.md)

            if (this.detail.reason.length > 0) {
              Column({ space: 6 }) {
                Text('理由')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Text(this.detail.reason)
                  .fontSize(AppTheme.font.bodyStrong)
                  .lineHeight(22)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
              }
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.md)
              .alignItems(HorizontalAlign.Start)
            }

if (this.versions.length > 0) {
              Column({ space: 8 }) {
                Text('版本时间线')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                ForEach(this.versions, (item: PredictionDetail) => {
                  Column({ space: 4 }) {
                    Row({ space: 8 }) {
                      Text(`v${item.version}`)
                        .fontSize(AppTheme.font.caption)
                        .fontColor(AppTheme.color.primaryDeep)
                        .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                        .backgroundColor(AppTheme.color.tint)
                        .borderRadius(AppTheme.radius.sm)
                      Text(item.createdAtLabel)
                        .fontSize(AppTheme.font.caption)
                        .fontColor(AppTheme.color.textMuted)
                      Blank()
                      Text(this.resultText(item))
                        .fontSize(AppTheme.font.caption)
                        .fontColor(AppTheme.color.textSecondary)
                    }
                    .width('100%')

                    Text(item.judgment)
                      .fontSize(AppTheme.font.bodyStrong)
                      .lineHeight(20)
                      .fontColor(AppTheme.color.text)
                      .width('100%')
                    Text(`置信度 ${this.confidenceText(item)}`)
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')

                    if (item.revisionReason !== undefined && item.revisionReason.length > 0) {
                      Column({ space: 3 }) {
                        Text(`修订原因：${item.revisionReason}`)
                          .fontSize(AppTheme.font.caption)
                          .lineHeight(17)
                          .fontColor(AppTheme.color.textSecondary)
                          .width('100%')
                        if (item.invalidated !== undefined && item.invalidated.length > 0) {
                          Text(`取消什么：${item.invalidated}`)
                            .fontSize(AppTheme.font.caption)
                            .lineHeight(17)
                            .fontColor(AppTheme.color.textMuted)
                            .width('100%')
                        }
                        if (item.preserved !== undefined && item.preserved.length > 0) {
                          Text(`保存什么：${item.preserved}`)
                            .fontSize(AppTheme.font.caption)
                            .lineHeight(17)
                            .fontColor(AppTheme.color.textMuted)
                            .width('100%')
                        }
                        if (item.repositioned !== undefined && item.repositioned.length > 0) {
                          Text(`重新定位：${item.repositioned}`)
                            .fontSize(AppTheme.font.caption)
                            .lineHeight(17)
                            .fontColor(AppTheme.color.textMuted)
                            .width('100%')
                        }
                      }
                      .width('100%')
                      .padding({ top: AppTheme.spacing.s4 })
                      .alignItems(HorizontalAlign.Start)
                    }
                  }
                  .width('100%')
                  .padding(AppTheme.spacing.s12)
                  .backgroundColor(AppTheme.color.surfaceAlt)
                  .borderRadius(AppTheme.radius.sm)
                  .alignItems(HorizontalAlign.Start)
                }, (item: PredictionDetail) => item.id)
              }
              .id('prediction_timeline')
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.md)
              .alignItems(HorizontalAlign.Start)
            }

            if (this.detail.status === PredictionStatus.PENDING) {
              if (todayDateString() >= this.detail.settlementDate) {
                Text('结算这条预测')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.primary)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
                  .backgroundColor(AppTheme.color.tint)
                  .borderRadius(AppTheme.radius.md)
                  .onClick(() => {
                    this.openSettle();
                  })
              } else {
                Text(`到期后可结算 · ${this.detail.settlementDate}`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }
            } else {
              Text('已结算，结果不可修改')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.s16)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(Color.Transparent)
      }
  }
}
