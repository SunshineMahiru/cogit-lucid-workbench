import {
  PredictionDetail,
  PredictionService,
  predictionHitText,
  predictionStatusText,
  todayDateString
} from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
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
              Text(predictionStatusText(this.detail.status, this.detail.hit))
                .fontSize(AppTheme.font.caption)
                .fontColor(this.tagColor())
                .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                .backgroundColor(this.tagBackground())
                .borderRadius(AppTheme.radius.sm)
              Text(`${this.detail.confidence}%`)
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

            Column() {
              PredictionInfoRow({ label: '结算日', value: this.detail.settlementDate })
              PredictionInfoRow({
                label: '状态',
                value: predictionStatusText(this.detail.status, this.detail.hit)
              })
              PredictionInfoRow({ label: '命中', value: predictionHitText(this.detail.hit) })
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
