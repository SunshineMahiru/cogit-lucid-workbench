import { AppTheme } from '../theme/AppTheme';

/** First-run method guide rendered as a full page; the host decides visibility. */
@ComponentV2
export struct WelcomeCard {
  @Event onStart: () => void = () => {};
  @Event onDismiss: () => void = () => {};
  @Event onPrivacy: () => void = () => {};

  @Builder
  step(stepId: string, index: string, title: string, detail: string) {
    Row({ space: 10 }) {
      Text(index)
        .fontSize(AppTheme.font.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.primaryDeep)
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.color.tint)
        .borderRadius(AppTheme.radius.md)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Text(detail)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .id(stepId)
  }

  build() {
    Column() {
      Row() {
        Text('先看这五件事')
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Blank()
        Text('稍后')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .id('welcome_dismiss')
          .accessibilityText('跳过首次使用说明')
          .onClick(() => {
            this.onDismiss();
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: AppTheme.spacing.s10 }) {
          Text('一页说明，可以随时跳过。五件事构成同一个循环，不需要每天打卡。')
            .fontSize(AppTheme.font.bodyStrong)
            .lineHeight(19)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
          this.step('welcome_step_1', '1', '保存经验', '记下现场、感受和已经做过的事。')
          this.step('welcome_step_2', '2', '形成模型', '写清当时的判断和结算日期。')
          this.step('welcome_step_3', '3', '进入实践', '按计划推进，留下真实行动。')
          this.step('welcome_step_4', '4', '接受校正', '到期回看事实，修正判断与解释。')
          this.step('welcome_step_5', '5', '允许暂停', '状态不好可以停下，暂停不算失败。')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Column({ space: AppTheme.spacing.s10 }) {
        Row({ space: 10 }) {
          Text('记录保存在本机；只有你确认后，内容才会离开设备。')
            .fontSize(AppTheme.font.body)
            .lineHeight(18)
            .fontColor(AppTheme.color.textMuted)
            .layoutWeight(1)
            .id('welcome_privacy_sentence')
          Text('数据与隐私')
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.primary)
            .id('welcome_privacy_entry')
            .onClick(() => {
              this.onPrivacy();
            })
        }
        .width('100%')

        Row({ space: 10 }) {
          Text('开始速记')
            .fontSize(AppTheme.font.bodyStrong)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .backgroundColor(AppTheme.color.primary)
            .borderRadius(AppTheme.radius.md)
            .id('welcome_start')
            .onClick(() => {
              this.onStart();
            })
          Text('先看看')
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.primary)
            .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
            .id('welcome_secondary')
            .onClick(() => {
              this.onDismiss();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(AppTheme.spacing.s16)
      .backgroundColor(AppTheme.color.surface)
      .borderRadius(AppTheme.radius.lg)
      .alignItems(HorizontalAlign.Start)
      .margin({ top: AppTheme.spacing.s12 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s16, bottom: AppTheme.spacing.s12 })
    .alignItems(HorizontalAlign.Start)
    .id('welcome_panel')
    .accessibilityText('首次使用说明：保存经验、形成模型、进入实践、接受校正、允许暂停')
  }
}