import { AppTheme } from '../theme/AppTheme';

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
          .fontColor(AppTheme.color.textSecondary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.Transparent)
    }
    .title(this.title)
    .backgroundColor(Color.Transparent)
  }
}
