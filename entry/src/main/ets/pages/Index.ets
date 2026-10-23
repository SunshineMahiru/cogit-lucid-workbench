@Entry
@Component
struct Index {
  build() {
    Column({ space: 12 }) {
      Text('此在')
        .fontSize(32)
        .fontWeight(FontWeight.Medium)
      Text('元认知外化工作台')
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
