import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';

/** A compact status card in the home module rail. */
@ComponentV2
export struct ModuleCard {
  @Param icon: Resource = $r('sys.symbol.house');
  @Param title: string = '';
  /** Headline count, already formatted */
  @Param value: string = '';
  @Param caption: string = '';
  @Param tone: string = AppTheme.color.primary;
  @Event onTap: () => void = () => {
  };

  build() {
    Column() {
      SectionCard({ contentPadding: AppTheme.spacing.s12 }) {
        Column({ space: AppTheme.spacing.s4 }) {
          Row({ space: AppTheme.spacing.s6 }) {
            SymbolGlyph(this.icon)
              .fontSize(16)
              .fontColor([this.tone])
            Text(this.title)
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.textSecondary)
          }
          .width('100%')

          Text(this.value)
            .fontSize(AppTheme.font.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tone)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.caption)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ minHeight: 76 })
      }
    }
    .width('100%')
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityText(`${this.title}，${this.value}，${this.caption}`)
    .onClick(() => {
      this.onTap();
    })
  }
}