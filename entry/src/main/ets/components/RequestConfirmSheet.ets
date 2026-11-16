import { AppTheme } from '../theme/AppTheme';

/** One material line shown before an outbound request; carries counts and ids only, never text. */
export interface ConfirmSheetItem {
  id: string;
  label: string;
  level: string;
  chars: number;
}

/** Bottom sheet that asks the user to confirm which material may leave the device. */
@ComponentV2
export struct RequestConfirmSheet {
  @Param visible: boolean = false;
  @Param providerLabel: string = '';
  @Param host: string = '';
  @Param items: ConfirmSheetItem[] = [];
  @Param droppedCount: number = 0;
  @Event onConfirm: () => void = () => {};
  @Event onCancel: () => void = () => {};
  @Event onRemove: (id: string) => void = () => {};

  build() {
    if (this.visible) {
      Column({ space: AppTheme.spacing.s8 }) {
        Text('确认发送范围')
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Text('只发送下列可分析内容；本地与封存内容不会离开本机')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
        Text('点「移除」可以不发送某一条；清单为空时不能发送')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
        Text(`${this.providerLabel} · ${this.host}`)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)

        Column({ space: AppTheme.spacing.s6 }) {
          ForEach(this.items, (item: ConfirmSheetItem, index: number) => {
            Row({ space: AppTheme.spacing.s8 }) {
              Column({ space: 2 }) {
                Text(item.label)
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
                Text(`编号 ${item.id}`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Text(item.level)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
              Text(`${item.chars} 字`)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textSecondary)
              Text('移除')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.danger)
                .onClick(() => {
                  this.onRemove(item.id);
                })
            }
            .width('100%')
          }, (item: ConfirmSheetItem, index: number) => `${item.id}_${index}`)
        }
        .width('100%')
        .padding(AppTheme.spacing.s10)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(AppTheme.radius.sm)
        .alignItems(HorizontalAlign.Start)

        if (this.droppedCount > 0) {
          Text(`另有 ${this.droppedCount} 项未纳入发送`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
        }

        Row({ space: AppTheme.spacing.s8 }) {
          Text('取消')
            .id('request_confirm_cancel')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
            .backgroundColor(AppTheme.color.surfaceAlt)
            .borderRadius(AppTheme.radius.sm)
            .onClick(() => {
              this.onCancel();
            })
          Text('确认发送')
            .id('request_confirm_send')
            .fontSize(AppTheme.font.body)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
            .backgroundColor(AppTheme.color.primary)
            .borderRadius(AppTheme.radius.sm)
            .onClick(() => {
              this.onConfirm();
            })
        }
        .width('100%')
        .margin({ top: AppTheme.spacing.s4 })
      }
      .id('request_confirm_sheet')
      .width('100%')
      .padding(AppTheme.spacing.s16)
      .alignItems(HorizontalAlign.Start)
    }
  }
}