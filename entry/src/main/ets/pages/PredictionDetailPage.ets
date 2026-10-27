import {
  PredictionDetail,
  PredictionService,
  predictionHitText,
  predictionStatusText
} from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { PredictionDetailParams, PredictionSettleParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { AppTheme } from '../theme/AppTheme';

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
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  private openSettle(): void {
    if (this.navStack === null) {
      return;
    }
    const params: PredictionSettleParams = { predictionId: this.detail.id };
    this.navStack.pushPathByName(ROUTES.PREDICTION_SETTLE, params);
  }

  private async load(id: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isLoading = false;
      this.missing = true;
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
      this.missing = true;
    } finally {
      this.isLoading = false;
    }
  }

  private tagColor(): string {
    if (this.detail.status === PredictionStatus.PENDING) {
      return '#B0761E';
    }
    return this.detail.hit === true ? '#2E7D32' : '#A32D2D';
  }

  private tagBackground(): string {
    if (this.detail.status === PredictionStatus.PENDING) {
      return '#FFF4E0';
    }
    return this.detail.hit === true ? '#E8F5E9' : '#FCEBEB';
  }

  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(12)
        .fontColor('#8A8F99')
      Text(value)
        .fontSize(12)
        .fontColor('#1F2329')
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  build() {
    NavDestination() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color('#4A6FA5')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F5F6F8')
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
        .backgroundColor('#F5F6F8')
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text(predictionStatusText(this.detail.status, this.detail.hit))
                .fontSize(10)
                .fontColor(this.tagColor())
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.tagBackground())
                .borderRadius(8)
              Text(`${this.detail.confidence}%`)
                .fontSize(14)
                .fontColor('#4A6FA5')
              Blank()
              Text(`v${this.detail.version}`)
                .fontSize(11)
                .fontColor('#B0B4BE')
            }
            .width('100%')

            Text(this.detail.target)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F2329')
              .width('100%')

            Text(this.detail.judgment)
              .fontSize(14)
              .lineHeight(24)
              .fontColor('#1F2329')
              .width('100%')

            Column() {
              this.infoRow('结算日', this.detail.settlementDate)
              this.infoRow('状态', predictionStatusText(this.detail.status, this.detail.hit))
              this.infoRow('命中', predictionHitText(this.detail.hit))
              this.infoRow('实际结果', this.detail.actualResult.length > 0 ? this.detail.actualResult : '—')
              this.infoRow('创建时间', this.detail.createdAtLabel)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)

            if (this.detail.reason.length > 0) {
              Column({ space: 6 }) {
                Text('理由')
                  .fontSize(12)
                  .fontColor('#8A8F99')
                  .width('100%')
                Text(this.detail.reason)
                  .fontSize(13)
                  .lineHeight(22)
                  .fontColor('#1F2329')
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }

            if (this.detail.status === PredictionStatus.PENDING) {
              Text('结算这条预测')
                .fontSize(13)
                .fontColor(AppTheme.color.primary)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 10, bottom: 10 })
                .backgroundColor(AppTheme.color.tint)
                .borderRadius(10)
                .onClick(() => {
                  this.openSettle();
                })
            } else {
              Text('已结算，结果不可修改')
                .fontSize(10)
                .fontColor('#B0B4BE')
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor('#F5F6F8')
      }
    }
    .title('预测详情')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param === undefined) {
        this.isLoading = false;
        this.missing = true;
        return;
      }
      const params = context.pathInfo.param as PredictionDetailParams;
      this.load(params.predictionId);
    })
    .onShown(() => {
      if (this.hasShownOnce && this.detail.id.length > 0) {
        this.load(this.detail.id);
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
