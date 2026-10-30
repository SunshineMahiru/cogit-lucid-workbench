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
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.primaryDeep)
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.tag)
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Blank()
        Text('›')
          .fontSize(14)
          .fontColor(AppTheme.color.textMuted)
      }
      .width('100%')

      Text(this.summary)
        .fontSize(11)
        .fontColor(AppTheme.color.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height(82)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.color.surfaceTint)
    .borderRadius(AppTheme.radius.card)
    .accessibilityText(`${this.title}，${this.summary}`)
    .onClick(() => {
      this.onTap();
    })
  }
}
