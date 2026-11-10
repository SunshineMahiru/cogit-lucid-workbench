import { AppTheme } from '../../theme/AppTheme';
import { SectionCard } from '../SectionCard';

/** Debug-only fault switches; the settings page decides when to show it. */
@ComponentV2
export struct DebugPanel {
  @Event onSimulateEncryption: () => void = () => {};
  @Event onSimulateRestore: () => void = () => {};
  @Event onClearFlags: () => void = () => {};

  build() {
    SectionCard() {
      Column({ space: 8 }) {
        Text('调试（仅 debug 构建）')
          .fontSize(AppTheme.font.subtitle)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text('故障开关用来验证失败分支，正式构建不读取这些标记。')
          .fontSize(AppTheme.font.body)
          .lineHeight(17)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        Row({ space: 8 }) {
          Text('模拟加密失败')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.danger)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(8)
            .onClick(() => {
              this.onSimulateEncryption();
            })
          Text('模拟恢复部分失败')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.danger)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(8)
            .onClick(() => {
              this.onSimulateRestore();
            })
          Text('清除调试标记')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(8)
            .onClick(() => {
              this.onClearFlags();
            })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
