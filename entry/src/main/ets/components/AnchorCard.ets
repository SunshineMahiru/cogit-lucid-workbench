import { Anchor } from '../model/Anchor';
import { AppTheme } from '../theme/AppTheme';

/** One read-only anchor row with its display index and a plan shortcut. */
@ComponentV2
export struct AnchorCard {
  @Param anchor: Anchor = { id: '', text: '', source: '', order: 0 };
  @Param index: number = 1;
  @Event onAttachPlan: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.index < 10 ? `0${this.index}` : `${this.index}`)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.primary)
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .lineHeight(28)
        .backgroundColor(AppTheme.color.tint)
        .borderRadius(14)

      Column({ space: 4 }) {
        Text(this.anchor.text)
          .fontSize(AppTheme.font.subtitle)
          .lineHeight(22)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text(this.anchor.source)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('关联计划')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.primary)
        .padding({ left: 6 })
        .onClick(() => {
          this.onAttachPlan();
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(12)
  }
}
