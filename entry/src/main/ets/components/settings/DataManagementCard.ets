import { AppTheme } from '../../theme/AppTheme';
import { SectionCard } from '../SectionCard';

/** Backup, restore, wipe and refresh actions; the page owns the busy and confirmation state. */
@ComponentV2
export struct DataManagementCard {
  @Param dataBusy: boolean = false;
  @Param clearArmed: boolean = false;
  @Param encryptionFallback: boolean = false;
  @Event onBackup: () => void = () => {};
  @Event onRestore: () => void = () => {};
  @Event onClear: () => void = () => {};
  @Event onRetryEncryption: () => void = () => {};
  @Event onRefreshHome: () => void = () => {};

  build() {
    SectionCard() {
      Column({ space: 8 }) {
        Text('数据管理')
          .fontSize(AppTheme.font.subtitle)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
          .width('100%')
        Text('备份包含记录、身份、设置与本地图片；恢复需选择 .cogitbackup 文件。')
          .fontSize(AppTheme.font.body)
          .lineHeight(17)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        Row({ space: 8 }) {
          Text(this.dataBusy ? '处理中…' : '备份并另存')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(8)
            .accessibilityText('备份本地数据并另存')
            .onClick(() => {
              this.onBackup();
            })
          Text('恢复备份')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(8)
            .accessibilityText('从备份文件恢复数据')
            .onClick(() => {
              this.onRestore();
            })
          Text(this.clearArmed ? '确认清空' : '清空全部数据')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.danger)
            .padding({ left: 8, right: 8, top: 7, bottom: 7 })
            .accessibilityText(this.clearArmed ? '确认清空全部数据' : '清空全部数据，需要二次确认')
            .onClick(() => {
              this.onClear();
            })
        }
        .width('100%')

        if (this.encryptionFallback) {
          Row({ space: 8 }) {
            Text('重新尝试加密')
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.danger)
              .padding({ left: 10, right: 10, top: 7, bottom: 7 })
              .backgroundColor(AppTheme.color.tint)
              .borderRadius(8)
              .accessibilityText('清除加密失败标记，重启应用后再次尝试加密')
              .onClick(() => {
                this.onRetryEncryption();
              })
          }
          .width('100%')
        }

        Row({ space: 8 }) {
          Text('刷新首页数据')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(8)
            .accessibilityText('重新读取本地记录并刷新首页摘要')
            .onClick(() => {
              this.onRefreshHome();
            })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
