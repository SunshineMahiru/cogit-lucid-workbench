import { AppTheme } from '../theme/AppTheme';

/** Single pill tag shared by every module; tone/surface come from the caller. */
@ComponentV2
export struct TagChip {
  @Param label: string = '';
  @Param tone: string = AppTheme.color.primary;
  @Param surface: string = AppTheme.color.evPracticeSurface;
  @Param selected: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Text(this.label)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.selected ? this.tone : AppTheme.color.textSecondary)
      .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Regular)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
      .backgroundColor(this.selected ? this.surface : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .border({ width: this.selected ? 1 : 0, color: this.tone })
      .onClick(() => {
        this.onTap();
      })
  }
}