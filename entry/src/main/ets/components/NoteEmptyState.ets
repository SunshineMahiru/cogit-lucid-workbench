import { AppTheme } from '../theme/AppTheme';
import { setPageEmpty } from '../settings/PageBackgroundBus';

/** Shared empty state for filtered or empty note lists. */
@ComponentV2
export struct NoteEmptyState {
  @Param title: string = '';
  @Param hint: string = '';
  @Param actionLabel: string = '';
  @Param dashed: boolean = false;
  @Event onAction: () => void = () => {};

  aboutToAppear(): void {
    setPageEmpty(true);
  }

  aboutToDisappear(): void {
    setPageEmpty(false);
  }

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.textSecondary)
      Text(this.hint)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textMuted)
      if (this.actionLabel.length > 0) {
        Text(this.actionLabel)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.primary)
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.lg)
          .margin({ top: AppTheme.spacing.s4 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding(AppTheme.spacing.s24)
    .justifyContent(FlexAlign.Center)
    .border(this.dashed ? { width: 1, color: AppTheme.color.borderStrong, style: BorderStyle.Dashed } : { width: 0 })
    .borderRadius(this.dashed ? AppTheme.radius.md : 0)
  }
}
