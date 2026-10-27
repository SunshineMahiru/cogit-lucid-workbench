/** Stand-in destination used until a module page is implemented. */
@ComponentV2
export struct PlaceholderPage {
  @Param title: string = '';
  @Param hint: string = '';

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        Text(this.hint)
          .fontSize(14)
          .fontColor('#8A8F99')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F5F6F8')
    }
    .title(this.title)
  }
}
