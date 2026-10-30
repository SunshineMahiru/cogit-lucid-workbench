import { AppTheme } from '../theme/AppTheme';
import { BackgroundImageSource } from '../settings/PageBackgroundService';

/** Bottom sheet listing the three places a background picture can come from. */
@ComponentV2
export struct ImageSourceSheet {
  @Event onPick: (source: BackgroundImageSource) => void = () => {
  };

  @Builder
  option(title: string, hint: string, source: BackgroundImageSource) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(13)
        .fontColor(AppTheme.color.text)
      Text(hint)
        .fontSize(11)
        .fontColor(AppTheme.color.textMuted)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(AppTheme.color.surfaceAlt)
    .borderRadius(10)
    .accessibilityText(title)
    .onClick(() => {
      this.onPick(source);
    })
  }

  build() {
    Column({ space: 10 }) {
      Text('图片从哪来')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .width('100%')
        .padding({ left: 4 })
      this.option('从相册选择', '挑一张已经存好的照片', BackgroundImageSource.GALLERY)
      this.option('拍一张', '打开系统相机，按快门后回到这里', BackgroundImageSource.CAMERA)
      this.option('选择文件', '从文件管理里挑 PNG、JPG、WEBP 或 HEIF', BackgroundImageSource.FILES)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }
}
