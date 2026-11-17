import { AppTheme } from '../theme/AppTheme';
import { curves } from '@kit.ArkUI';

/** Rounded container; keeps surface, padding, radius and entrance motion in one place. */
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
    .borderRadius(16)
    .border({ width: 0.5, color: AppTheme.color.border })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
      .animation({ curve: curves.springMotion(0.35, 0.9) }))
  }
}
