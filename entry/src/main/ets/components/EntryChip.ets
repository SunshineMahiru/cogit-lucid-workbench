/** A tappable chip for the quick-entry section of the dashboard. */
@ComponentV2
export struct EntryChip {
  @Param label: string = '';
  @Event onTap: () => void = () => {};

  build() {
    Text(this.label)
      .fontSize(13)
      .fontColor('#1F2329')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(Color.White)
      .borderRadius(16)
      .onClick(() => {
        this.onTap();
      })
  }
}