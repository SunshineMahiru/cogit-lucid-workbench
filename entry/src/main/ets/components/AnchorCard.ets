import { Anchor } from '../model/Anchor';
import { AppTheme } from '../theme/AppTheme';

/** One anchor row: version tag, plan shortcut and revision actions. */
@ComponentV2
export struct AnchorCard {
  @Param anchor: Anchor = { id: '', text: '', source: '', order: 0 };
  @Param index: number = 1;
  @Param showVersionsEntry: boolean = true;
  @Event onAttachPlan: () => void = () => {};
  @Event onRevise: () => void = () => {};
  @Event onRetire: () => void = () => {};
  @Event onVersions: () => void = () => {};

  build() {
    Column({ space: AppTheme.spacing.s8 }) {
      Row({ space: 12 }) {
        Text(this.index < 10 ? `0${this.index}` : `${this.index}`)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.primary)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .lineHeight(28)
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.lg)

        Column({ space: 4 }) {
          Text(this.anchor.text)
            .fontSize(AppTheme.font.subtitle)
            .lineHeight(22)
            .fontColor(AppTheme.color.text)
            .width('100%')
          Text(this.anchor.source)
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text(`v${this.anchor.version ?? 1}`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
            .backgroundColor(AppTheme.color.surfaceAlt)
            .borderRadius(AppTheme.radius.sm)
          if (this.anchor.synthetic === true) {
            Text('示例')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.warning)
              .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
              .backgroundColor(AppTheme.color.warningSurface)
              .borderRadius(AppTheme.radius.sm)
          }
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Row({ space: AppTheme.spacing.s12 }) {
        Text('关联计划')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.onAttachPlan();
          })
        Blank()
        Text('修订')
          .id(`anchor_revise_${this.anchor.id}`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.onRevise();
          })
        Text('停用')
          .id(`anchor_retire_${this.anchor.id}`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.danger)
          .onClick(() => {
            this.onRetire();
          })
        if (this.showVersionsEntry) {
          Text('查看版本')
            .id(`anchor_versions_${this.anchor.id}`)
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.onVersions();
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
  }
}