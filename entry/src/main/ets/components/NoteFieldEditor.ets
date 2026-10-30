import { NoteFieldKey, NoteTemplateField } from '../note';
import { AppTheme } from '../theme/AppTheme';

/** One labelled template field with inline validation feedback. */
@ComponentV2
export struct NoteFieldEditor {
  @Param field: NoteTemplateField = {
    key: NoteFieldKey.BACKGROUND,
    label: '',
    placeholder: '',
    required: false,
    multiline: true
  };
  @Param value: string = '';
  @Param error: string = '';
  @Event onValueChange: (value: string) => void = () => {};

  build() {
    Column({ space: 6 }) {
      Row({ space: 4 }) {
        Text(this.field.label)
          .fontSize(12)
          .fontColor(AppTheme.color.textSecondaryStrong)
        if (this.field.required) {
          Text('*')
            .fontSize(12)
            .fontColor(AppTheme.color.danger)
        }
      }
      .width('100%')

      if (this.field.multiline) {
        TextArea({ text: this.value, placeholder: this.field.placeholder })
          .fontSize(13)
          .height(72)
          .padding(10)
          .backgroundColor(AppTheme.color.surfaceTint)
          .borderRadius(10)
          .border({ width: 0.5, color: this.error.length > 0 ? AppTheme.color.danger : AppTheme.color.border })
          .onChange((value: string) => {
            this.onValueChange(value);
          })
      } else {
        TextInput({ text: this.value, placeholder: this.field.placeholder })
          .fontSize(13)
          .height(40)
          .padding({ left: 10, right: 10 })
          .backgroundColor(AppTheme.color.surfaceTint)
          .borderRadius(10)
          .border({ width: 0.5, color: this.error.length > 0 ? AppTheme.color.danger : AppTheme.color.border })
          .onChange((value: string) => {
            this.onValueChange(value);
          })
      }

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(11)
          .fontColor(AppTheme.color.danger)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
