import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';
import { QuickNoteService } from '../note/QuickNoteService';
import { NoteDepth, NoteDraft } from '../note/NoteDraft';
import { SecurityLevel } from '../model/SecurityLevel';
import { previewStore } from '../preview/PreviewStore';

/**
 * One-line capture shared by the workbench and the logs tab. The draft is saved through the
 * existing QuickNoteService; the input clears and the host is notified only after a successful
 * save. In the Previewer, where there is no database, the note goes to the in-session store.
 */
@ComponentV2
export struct QuickCaptureBar {
  @Param placeholder: string = '此刻发生了什么';
  @Param hint: string = '';
  /** Element ids; hosts sharing the screen pass distinct values. */
  @Param inputId: string = 'quick_capture_input';
  @Param saveId: string = 'quick_capture_save';
  @Event onSaved: () => void = () => {
  };
  @Local captureText: string = '';
  @Local saving: boolean = false;

  private draft(text: string): NoteDraft {
    return {
      templateId: null,
      title: '',
      content: text,
      entries: [],
      tags: [],
      relatedRelationIds: [],
      level: SecurityLevel.LOCAL_ONLY,
      materials: [{ kind: 'scene', text: text }],
      depth: NoteDepth.QUICK,
      timestamp: Date.now()
    };
  }

  private async save(): Promise<void> {
    const text = this.captureText.trim();
    if (text.length === 0 || this.saving) {
      return;
    }
    this.saving = true;
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        previewStore.addNote(this.draft(text));
      } else {
        const service = await QuickNoteService.open(context);
        await service.save(this.draft(text));
      }
      this.captureText = '';
      this.onSaved();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.saving = false;
    }
  }

  build() {
    SectionCard({ contentPadding: AppTheme.spacing.s12 }) {
      Column({ space: AppTheme.spacing.s6 }) {
        TextInput({ text: this.captureText, placeholder: this.placeholder })
          .id(this.inputId)
          .fontSize(AppTheme.font.bodyStrong)
          .height(44)
          .backgroundColor(Color.Transparent)
          .accessibilityText('快速速记输入框')
          .onChange((value: string) => {
            this.captureText = value;
          })

        Row({ space: AppTheme.spacing.s8 }) {
          Text(this.hint)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.saving ? '保存中' : '保存')
            .id(this.saveId)
            .fontSize(AppTheme.font.body)
            .fontColor(Color.White)
            .padding({
              left: AppTheme.spacing.s12,
              right: AppTheme.spacing.s12,
              top: AppTheme.spacing.s6,
              bottom: AppTheme.spacing.s6
            })
            .backgroundColor(this.captureText.trim().length > 0 && !this.saving ?
              AppTheme.color.primary : AppTheme.color.primaryDisabled)
            .borderRadius(AppTheme.radius.sm)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
            .accessibilityText('保存这条速记')
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}