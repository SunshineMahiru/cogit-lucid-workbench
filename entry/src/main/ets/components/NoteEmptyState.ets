import { AppTheme } from '../theme/AppTheme';

/** Shared empty state for filtered or empty note lists. */
@ComponentV2
export struct NoteEmptyState {
  @Param title: string = '';
  @Param hint: string = '';
  @Param actionLabel: string = '';
  @Param dashed: boolean = false;
  @Event onAction: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(14)
        .fontColor(AppTheme.color.textSecondary)
      Text(this.hint)
        .fontSize(12)
        .fontColor(AppTheme.color.textMuted)
      if (this.actionLabel.length > 0) {
        Text(this.actionLabel)
          .fontSize(13)
          .fontColor(AppTheme.color.primary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(16)
          .margin({ top: 4 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
    .border(this.dashed ? { width: 1, color: AppTheme.color.borderStrong, style: BorderStyle.Dashed } : { width: 0 })
    .borderRadius(this.dashed ? 12 : 0)
  }
}
