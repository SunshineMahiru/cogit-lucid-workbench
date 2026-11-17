import { AppTheme } from '../theme/AppTheme';

/** A dashboard tile summarising one module with a live count. */
@ComponentV2
export struct ModuleCard {
  @Param icon: string = '';
  @Param title: string = '';
  @Param summary: string = '';
  @Event onTap: () => void = () => {};

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(this.icon)
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.primaryDeep)
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.sm)
        Text(this.title)
          .fontSize(AppTheme.font.subtitle)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(14)
          .fontColor([AppTheme.color.textMuted])
      }
      .width('100%')

      Text(this.summary)
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: 82 })
    .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.color.surfaceTint)
    .borderRadius(16)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityText(`${this.title}，${this.summary}`)
    .onClick(() => {
      this.onTap();
    })
  }
}
