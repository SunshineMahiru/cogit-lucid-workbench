import { AppTheme } from '../theme/AppTheme';

/** Tag chips with a separate input row for adding a custom tag. */
@ComponentV2
export struct NoteTagEditor {
  @Param tags: string[] = [];
  @Event onAdd: (tag: string) => void = () => {};
  @Event onRemove: (tag: string) => void = () => {};
  @Local draftTag: string = '';

  private submit(): void {
    const value = this.draftTag.trim();
    if (value.length === 0) {
      return;
    }
    this.onAdd(value);
    this.draftTag = '';
  }

  private canSubmit(): boolean {
    return this.draftTag.trim().length > 0;
  }

  build() {
    Column({ space: 8 }) {
      Text('添加标签')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondaryStrong)
        .width('100%')

      if (this.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tags, (tag: string) => {
            Text(`${tag} ×`)
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.primaryDeep)
              .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
              .backgroundColor(AppTheme.color.tint)
              .borderRadius(AppTheme.radius.md)
              .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
              .onClick(() => {
                this.onRemove(tag);
              })
          }, (tag: string) => tag)
        }
        .width('100%')
      }

      Row({ space: 8 }) {
        TextInput({ text: this.draftTag, placeholder: '输入标签，回车添加' })
          .layoutWeight(1)
          .height(36)
          .fontSize(AppTheme.font.bodyStrong)
          .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10 })
          .backgroundColor(AppTheme.color.surfaceTint)
          .borderRadius(AppTheme.radius.sm)
          .border({ width: 0.5, color: AppTheme.color.border })
          .maxLength(12)
          .accessibilityText('输入新标签')
          .onChange((value: string) => {
            this.draftTag = value;
          })
          .onSubmit(() => {
            this.submit();
          })
        Text('添加')
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canSubmit() ? Color.White : AppTheme.color.textMuted)
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(this.canSubmit() ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .accessibilityText('添加标签')
          .onClick(() => {
            this.submit();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
