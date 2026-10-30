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
        .fontSize(12)
        .fontColor(AppTheme.color.textSecondaryStrong)
        .width('100%')

      if (this.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tags, (tag: string) => {
            Text(`${tag} ×`)
              .fontSize(11)
              .fontColor(AppTheme.color.primaryDeep)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(AppTheme.color.tint)
              .borderRadius(10)
              .margin({ right: 6, bottom: 4 })
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
          .fontSize(13)
          .padding({ left: 10, right: 10 })
          .backgroundColor(AppTheme.color.surfaceTint)
          .borderRadius(AppTheme.radius.tag)
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
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canSubmit() ? Color.White : AppTheme.color.textMuted)
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .backgroundColor(this.canSubmit() ? AppTheme.color.primary : AppTheme.color.chip)
          .borderRadius(AppTheme.radius.tag)
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
