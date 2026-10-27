import { PredictionItem } from '../model/HomeModel';

/**
 * 待结算预测卡片。
 * 数据由父组件通过 @Param 传入，组件自身不持有可变状态，便于在列表里反复复用。
 */
@ComponentV2
export struct PredictionCard {
  @Param item: PredictionItem = { id: '', title: '', confidence: 0, dueDate: '' };

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('待结算')
          .fontSize(10)
          .fontColor('#E8A93C')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#FFF4E0')
          .borderRadius(8)
          .margin({ right: 6 })
        Text(this.item.title)
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

      Row() {
        Text('置信度')
          .fontSize(12)
          .fontColor('#8A8F99')
        Blank()
        Text(this.item.dueDate)
          .fontSize(12)
          .fontColor('#8A8F99')
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }
}
