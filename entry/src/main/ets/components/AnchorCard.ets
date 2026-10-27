import { Anchor } from '../model/Anchor';

/** One read-only anchor row with its display index. */
@ComponentV2
export struct AnchorCard {
  @Param anchor: Anchor = { id: '', text: '', source: '', order: 0 };
  @Param index: number = 1;

  build() {
    Row({ space: 12 }) {
      Text(this.index < 10 ? `0${this.index}` : `${this.index}`)
        .fontSize(12)
        .fontColor('#4A6FA5')
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .lineHeight(28)
        .backgroundColor('#E8EFF7')
        .borderRadius(14)

      Column({ space: 4 }) {
        Text(this.anchor.text)
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#1F2329')
          .width('100%')
        Text(this.anchor.source)
          .fontSize(11)
          .fontColor('#B0B4BE')
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }
}
