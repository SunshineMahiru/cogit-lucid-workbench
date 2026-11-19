import { AppTheme } from '../../theme/AppTheme';
import { SectionCard } from '../SectionCard';

/**
* Title, chart, judgement question, verdict and footnote in one card. With `collapsible` the card
 * keeps only the title and the chart visible and hides the hint, verdict and footnote behind a
 * notes toggle; without it the layout is exactly the historical one.
 */
@ComponentV2
export struct ChartSection {
  @Param title: string = '';
  @Param hint: string = '';
  @Param verdict: string = '';
  @Param footer: string = '';
  @Param demoTag: boolean = false;
  /** Hides the explanation, verdict and footnote of each card behind its notes toggle. */
  @Param collapsible: boolean = false;
  @Param initiallyExpanded: boolean = false;
  /** Stable suffix for the notes toggle id; several cards share one screen. */
  @Param sectionId: string = 'default';
  @BuilderParam content: () => void = this.emptyContent;
  @Local expanded: boolean = false;

  aboutToAppear(): void {
    this.expanded = this.initiallyExpanded;
  }

  @Builder
  emptyContent() {
  }

  @Builder
  explanations() {
    Column({ space: 6 }) {
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
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

        if (this.collapsible) {
          this.content()
          Row() {
            Blank()
            Text(this.expanded ? '收起' : '说明')
              .id(`chart_section_toggle_${this.sectionId}`)
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.primary)
              .padding({ left: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
              .accessibilityText(this.expanded ? '收起说明与口径' : '展开说明与口径')
              .onClick(() => {
                this.expanded = !this.expanded;
              })
          }
          .width('100%')

          if (this.expanded) {
            this.explanations()
          }
        } else {
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
      }
      .width('100%')
    }
  }
}