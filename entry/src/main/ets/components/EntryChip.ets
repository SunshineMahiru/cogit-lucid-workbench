import { AppTheme } from '../theme/AppTheme';

/** A tappable chip for the quick-entry section of the dashboard. */
@ComponentV2
export struct EntryChip {
  @Param label: string = '';
  @Event onTap: () => void = () => {};

  private iconForLabel(label: string): string {
    const icons: Record<string, string> = {
      '速记': '📝',
      '预测': '🔮',
      '复盘': '🔄',
      '锚点': '⭐',
      '状态': '📊',
      '关系': '🔗'
    };
    return icons[label] ?? '📌';
  }

  build() {
    Row({ space: 4 }) {
      Text(this.iconForLabel(this.label))
        .fontSize(AppTheme.font.subtitle)
      Text(this.label)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.text)
    }
    .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.lg)
    .onClick(() => {
      this.onTap();
    })
  }
}