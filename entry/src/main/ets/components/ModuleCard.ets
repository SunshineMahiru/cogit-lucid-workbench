/** A dashboard tile summarising one module with a live count. */
@ComponentV2
export struct ModuleCard {
  @Param icon: string = '';
  @Param title: string = '';
  @Param summary: string = '';
  @Event onTap: () => void = () => {};

  build() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(this.icon)
          .fontSize(16)
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2329')
        Blank()
        Text('›')
          .fontSize(14)
          .fontColor('#B0B4BE')
      }
      .width('100%')

      Text(this.summary)
        .fontSize(11)
        .fontColor('#8A8F99')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height(82)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F7F9FC')
    .borderRadius(12)
    .onClick(() => {
      this.onTap();
    })
  }
}
