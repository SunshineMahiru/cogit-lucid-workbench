import { NoteTemplate, NoteTemplateId, NOTE_TEMPLATES } from '../note';
import { AppTheme } from '../theme/AppTheme';

/** Horizontal template chips; the free-form chip stands for a null template. */
@ComponentV2
export struct NoteTemplatePicker {
  @Param selected: NoteTemplateId | null = null;
  @Event onSelect: (templateId: NoteTemplateId | null) => void = () => {};
  @Local activeId: NoteTemplateId | null = null;

  aboutToAppear(): void {
    this.activeId = this.selected;
  }

  @Monitor('selected')
  onSelectedChanged(): void {
    this.activeId = this.selected;
  }

  @Builder
  chip(label: string, templateId: NoteTemplateId | null) {
    Text(label)
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.activeId === templateId ? Color.White : AppTheme.color.textStrong)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor(this.activeId === templateId ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.activeId = templateId;
        this.onSelect(templateId);
      })
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        this.chip('自由', null)
        ForEach(NOTE_TEMPLATES, (template: NoteTemplate) => {
          this.chip(template.label, template.id)
        }, (template: NoteTemplate) => `${template.id}_${this.activeId === template.id ? 1 : 0}`)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}
