import { AppTheme } from '../theme/AppTheme';

/** First-run guide shown on the dashboard until dismissed. */
@ComponentV2
export struct WelcomeCard {
  @Event onStart: () => void = () => {};
  @Event onDismiss: () => void = () => {};

  @Builder
  step(index: string, title: string, detail: string) {
    Row({ space: 10 }) {
      Text(index)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.primaryDeep)
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.color.tint)
        .borderRadius(11)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Text(detail)
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('从一条记录开始')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Blank()
        Text('稍后')
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
          .onClick(() => {
            this.onDismiss();
          })
      }
      .width('100%')

      Text('先记下此刻，再决定下一步；预测和复盘会把这套循环接起来。')
        .fontSize(12)
        .lineHeight(19)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')

      this.step('1', '速记', '记一句今天发生的事，标签可留空。')
      this.step('2', '预测', '写下一个判断和结算日，到期再回来看。')
      this.step('3', '复盘', '对照事实、解释和锚点，形成下一步行动。')

      Row({ space: 10 }) {
        Text('开始速记')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor(AppTheme.color.primary)
          .borderRadius(10)
          .onClick(() => {
            this.onStart();
          })
        Text('先看看')
          .fontSize(12)
          .fontColor(AppTheme.color.primary)
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .onClick(() => {
            this.onDismiss();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.color.selectedSurface)
    .borderRadius(AppTheme.radius.card)
    .border({ width: 1, color: AppTheme.color.borderSelected })
    .alignItems(HorizontalAlign.Start)
    .accessibilityText('首次使用引导：先速记，再预测，最后复盘')
  }
}
