import { AppTheme } from '../theme/AppTheme';

/** Overlay scrim; it is a translucent layer rather than a palette colour, like PageBackground's scrim. */
const SCRIM: string = '#66000000';

/**
 * Bottom panel opened by the single button in the workbench header. It covers only the content
 * area, rises from the bottom at roughly a fifth of its height and holds exactly two entries:
 * reorder the blocks, or open settings. Tapping the scrim closes it.
 */
@ComponentV2
export struct HomeQuickMenuPanel {
  @Param visible: boolean = false;
  @Event onClose: () => void = () => {
  };
  @Event onCustomize: () => void = () => {
  };
  @Event onSettings: () => void = () => {
  };

  private pick(action: string): void {
    if (action === 'customize') {
      this.onCustomize();
      return;
    }
    this.onSettings();
  }

  @Builder
  menuRow(rowId: string, label: string, hint: string, action: string) {
    Row({ space: AppTheme.spacing.s12 }) {
      Column({ space: AppTheme.spacing.s2 }) {
        Text(label)
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text(hint)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(16)
        .fontColor([AppTheme.color.textSecondary])
    }
    .id(rowId)
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20 })
    .alignItems(VerticalAlign.Center)
    .accessibilityText(label)
    .onClick(() => {
      this.pick(action);
    })
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(SCRIM)
          .accessibilityText('关闭面板')
          .onClick(() => {
            this.onClose();
          })

        Column() {
          Row() {
            Column()
              .width(36)
              .height(4)
              .backgroundColor(AppTheme.color.borderStrong)
              .borderRadius(AppTheme.radius.xs)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s4 })

          this.menuRow('home_menu_customize', '自定义顺序', '长按并拖动区块，调整首页先后', 'customize')
          this.menuRow('home_menu_settings', '设置', '模型、密级与数据导出', 'settings')
        }
        .width('100%')
        .height('22%')
        .constraintSize({ minHeight: 132 })
        .backgroundColor(AppTheme.color.surface)
        .borderRadius({ topLeft: AppTheme.radius.lg, topRight: AppTheme.radius.lg })
        .border({ width: { top: 0.5 }, color: AppTheme.color.border })
        .transition(TransitionEffect.translate({ y: 60 }).combine(TransitionEffect.OPACITY))
      }
      .width('100%')
      .height('100%')
    }
  }
}