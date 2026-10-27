import { PredictionListItem } from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';

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
    if (this.item.status === PredictionStatus.PENDING) {
      return '待结算';
    }
    return this.item.hit === true ? '命中' : '未命中';
  }

  private tagColor(): string {
    if (this.item.status === PredictionStatus.PENDING) {
      return '#B0761E';
    }
    return this.item.hit === true ? '#2E7D32' : '#A32D2D';
  }

  private tagBackground(): string {
    if (this.item.status === PredictionStatus.PENDING) {
      return '#FFF4E0';
    }
    return this.item.hit === true ? '#E8F5E9' : '#FCEBEB';
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
          .fontColor('#1F2329')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.item.confidence}%`)
          .fontSize(14)
          .fontColor('#4A6FA5')
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.item.judgment)
        .fontSize(12)
        .fontColor('#5F5E5A')
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text(this.item.status === PredictionStatus.PENDING ?
          `结算日 ${this.item.settlementDate}` :
          `实际 ${this.item.actualResult.length > 0 ? this.item.actualResult : '—'}`)
          .fontSize(11)
          .fontColor('#8A8F99')
        Blank()
        Text(this.item.status === PredictionStatus.PENDING ? '置信度' : '已结算')
          .fontSize(11)
          .fontColor('#B0B4BE')
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
