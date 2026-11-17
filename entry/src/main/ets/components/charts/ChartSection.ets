import { AppTheme } from '../../theme/AppTheme';
import { SectionCard } from '../SectionCard';

/** Title, judgement question, chart, verdict and footnote in one card. */
@ComponentV2
export struct ChartSection {
  @Param title: string = '';
  @Param hint: string = '';
  @Param verdict: string = '';
  @Param footer: string = '';
  @Param demoTag: boolean = false;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    SectionCard() {
      Column({ space: 6 }) {
        if (this.demoTag) {
          Text('演示数据·非真实记录')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.warning)
            .width('100%')
        }
        Text(this.title)
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text(this.hint)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
        this.content()
        if (this.verdict.length > 0) {
          Text(this.verdict)
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.text)
            .width('100%')
        }
        if (this.footer.length > 0) {
          Text(this.footer)
            .fontSize(AppTheme.font.caption)
            .lineHeight(16)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
      }
      .width('100%')
    }
  }
}