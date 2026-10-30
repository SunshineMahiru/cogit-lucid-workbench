import { NoteTemplate, NoteTemplateId, NOTE_TEMPLATES } from '../note';
import { AppTheme } from '../theme/AppTheme';

/** Horizontal template chips; the free-form chip stands for a null template. */
@ComponentV2
export struct NoteTemplatePicker {
  @Param selected: NoteTemplateId | null = null;
  @Event onSelect: (templateId: NoteTemplateId | null) => void = () => {};

  @Builder
  chip(label: string, active: boolean, templateId: NoteTemplateId | null) {
    Text(label)
      .fontSize(13)
      .fontColor(active ? Color.White : AppTheme.color.textStrong)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor(active ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(16)
      .onClick(() => {
        this.onSelect(templateId);
      })
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        this.chip('自由', this.selected === null, null)
        ForEach(NOTE_TEMPLATES, (template: NoteTemplate) => {
          this.chip(template.label, this.selected === template.id, template.id)
        }, (template: NoteTemplate) => template.id)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}
