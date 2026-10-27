/** Primary save action that reports its own progress state. */
@ComponentV2
export struct NoteSaveBar {
  @Param saving: boolean = false;
  @Event onSave: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      if (this.saving) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(Color.White)
        Text('保存中')
          .fontSize(14)
          .fontColor(Color.White)
      } else {
        Text('保存')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.saving ? '#8FA6C4' : '#4A6FA5')
    .borderRadius(12)
    .onClick(() => {
      if (!this.saving) {
        this.onSave();
      }
    })
  }
}
