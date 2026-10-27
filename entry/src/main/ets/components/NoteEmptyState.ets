/** Shared empty state for filtered or empty note lists. */
@ComponentV2
export struct NoteEmptyState {
  @Param title: string = '';
  @Param hint: string = '';
  @Param actionLabel: string = '';
  @Param dashed: boolean = false;
  @Event onAction: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(14)
        .fontColor('#8A8F99')
      Text(this.hint)
        .fontSize(12)
        .fontColor('#B0B4BE')
      if (this.actionLabel.length > 0) {
        Text(this.actionLabel)
          .fontSize(13)
          .fontColor('#4A6FA5')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#E8EFF7')
          .borderRadius(16)
          .margin({ top: 4 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
    .border(this.dashed ? { width: 1, color: '#D3D1C7', style: BorderStyle.Dashed } : { width: 0 })
    .borderRadius(this.dashed ? 12 : 0)
  }
}
