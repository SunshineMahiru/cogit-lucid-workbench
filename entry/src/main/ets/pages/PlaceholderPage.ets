import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';

/** Stand-in destination used until a module page is implemented. */
@ComponentV2
export struct PlaceholderPage {
  @Param title: string = '';
  @Param hint: string = '';

  build() {
    AppDestination({
      route: 'placeholder',
      title: this.title,
      content: () => {
        this.placeholderBody();
      }
    })
  }

  @Builder
  placeholderBody() {
      Column({ space: 8 }) {
        Text(this.hint)
          .fontSize(AppTheme.font.subtitle)
          .fontColor(AppTheme.color.textSecondary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.Transparent)
  }
}
