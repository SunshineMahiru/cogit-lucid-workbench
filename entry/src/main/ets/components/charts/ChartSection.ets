import { AppTheme } from '../../theme/AppTheme';
import { SectionCard } from '../SectionCard';

/** Title, hint and chart content in one card. */
@ComponentV2
export struct ChartSection {
  @Param title: string = '';
  @Param hint: string = '';
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    SectionCard() {
      Column({ space: 6 }) {
        Text(this.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text(this.hint)
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
        this.content()
      }
      .width('100%')
    }
  }
}
