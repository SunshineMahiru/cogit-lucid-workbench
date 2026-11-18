import { AppTheme } from '../theme/AppTheme';

/** Main-tab title bar: title on the left, caller-provided actions on the right. */
@ComponentV2
export struct TabHeader {
  @Param title: string = '';
  @BuilderParam actions: () => void = this.emptyActions;

  @Builder
  emptyActions() {
  }

  build() {
    Row() {
      Text(this.title)
        .fontSize(AppTheme.font.headline)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.color.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Row({ space: AppTheme.spacing.s8 }) {
        this.actions()
      }
      .alignItems(VerticalAlign.Center)
      .flexShrink(0)
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({
      left: AppTheme.spacing.s20,
      right: AppTheme.spacing.s16,
      top: AppTheme.spacing.s12,
      bottom: AppTheme.spacing.s8
    })
    .alignItems(VerticalAlign.Center)
  }
}