import { PredictionListItem, predictionStatusLabel } from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { AppTheme } from '../theme/AppTheme';

/** Prediction row for the log list, covering both pending and settled states. */
@ComponentV2
export struct PredictionListCard {
  @Param item: PredictionListItem = {
    id: '',
    target: '',
    judgment: '',
    confidence: 0,
    settlementDate: '',
    status: PredictionStatus.PENDING,
    hit: null,
    actualResult: '',
    createdAt: 0
  };
  @Event onTap: () => void = () => {};

  private tagLabel(): string {
    return predictionStatusLabel(this.item);
  }

  private tagColor(): string {
    if (this.item.status === PredictionStatus.PENDING) {
      return AppTheme.color.warning;
    }
    return this.item.hit === true ? AppTheme.color.success : AppTheme.color.danger;
  }

  private tagBackground(): string {
    if (this.item.status === PredictionStatus.PENDING) {
      return AppTheme.color.warningSurface;
    }
    return this.item.hit === true ? AppTheme.color.successSurface : AppTheme.color.dangerSurface;
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(this.tagLabel())
          .fontSize(10)
          .fontColor(this.tagColor())
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.tagBackground())
          .borderRadius(8)
        Text(this.item.target)
          .fontSize(15)
          .fontColor(AppTheme.color.text)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.item.confidence}%`)
          .fontSize(14)
          .fontColor(AppTheme.color.primary)
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.item.judgment)
        .fontSize(12)
        .fontColor(AppTheme.color.textSecondaryStrong)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text(this.item.status === PredictionStatus.PENDING ?
          `结算日 ${this.item.settlementDate}` :
          `实际 ${this.item.actualResult.length > 0 ? this.item.actualResult : '—'}`)
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        Text(this.item.status === PredictionStatus.PENDING ? '置信度' : '已结算')
          .fontSize(11)
          .fontColor(AppTheme.color.textMuted)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => {
      this.onTap();
    })
  }
}
