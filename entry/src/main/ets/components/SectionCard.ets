import { AppTheme } from '../theme/AppTheme';

/** White rounded container; keeps surface, padding and radius in one place. */
@ComponentV2
export struct SectionCard {
  @BuilderParam content: () => void = this.emptyContent;
  @Param contentPadding: number = AppTheme.spacing.card;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.contentPadding)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.card)
  }
}
