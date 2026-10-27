import {
  NoteDraft,
  NoteEntry,
  NoteFieldKey,
  NoteTemplateField,
  NoteTemplateId,
  NoteValidationError,
  QuickNoteService,
  createFreeformNoteDraft,
  findNoteTemplate,
  mergeDraftEntries,
  securityLevelText,
  validateNoteDraft
} from '../note';
import { SecurityLevel } from '../model/SecurityLevel';
import { NoteEditParams } from '../navigation/RouteParams';
import { SettingsStore } from '../settings';
import { NoteFieldEditor } from '../components/NoteFieldEditor';
import { NoteSaveBar } from '../components/NoteSaveBar';
import { NoteTagEditor } from '../components/NoteTagEditor';
import { NoteTemplatePicker } from '../components/NoteTemplatePicker';

/** Quick capture editor: template picker, dynamic fields, tags and save. */
@ComponentV2
export struct NoteEditPage {
  @Local draft: NoteDraft = createFreeformNoteDraft();
  @Local errors: NoteValidationError[] = [];
  @Local isSaving: boolean = false;
  @Local isDirty: boolean = false;
  @Local service: QuickNoteService | null = null;
  private navStack: NavPathStack | null = null;

  async aboutToAppear(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return;
    }
    try {
      const settings = await SettingsStore.open(hostContext);
      const values = await settings.load();
      this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags, values.defaultLevel);
      this.service = await QuickNoteService.open(hostContext);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '初始化失败，请重试' });
    }
  }

  private rebuild(content: string, entries: NoteEntry[], tags: string[], level: SecurityLevel): NoteDraft {
    return {
      templateId: this.draft.templateId,
      title: this.draft.title,
      content: content,
      entries: entries,
      tags: tags,
      level: level,
      timestamp: this.draft.timestamp
    };
  }

  private applyTemplate(templateId: NoteTemplateId | null): void {
    this.draft = mergeDraftEntries(this.draft, templateId);
    this.errors = [];
  }

  private fieldFor(key: NoteFieldKey): NoteTemplateField {
    if (this.draft.templateId !== null) {
      for (const field of findNoteTemplate(this.draft.templateId).fields) {
        if (field.key === key) {
          return field;
        }
      }
    }
    return { key: key, label: '', placeholder: '', required: false, multiline: true };
  }

  private errorFor(key: NoteFieldKey | null): string {
    for (const error of this.errors) {
      if (error.key === key) {
        return error.message;
      }
    }
    return '';
  }

  private clearError(key: NoteFieldKey | null): void {
    if (this.errors.length === 0) {
      return;
    }
    const remaining: NoteValidationError[] = [];
    for (const error of this.errors) {
      if (error.key !== key) {
        remaining.push(error);
      }
    }
    if (remaining.length !== this.errors.length) {
      this.errors = remaining;
    }
  }

  private updateContent(value: string): void {
    this.draft = this.rebuild(value, this.draft.entries, this.draft.tags, this.draft.level);
    this.isDirty = true;
    this.clearError(null);
  }

  private updateEntry(key: NoteFieldKey, value: string): void {
    const entries: NoteEntry[] = [];
    for (const entry of this.draft.entries) {
      entries.push({ key: entry.key, value: entry.key === key ? value : entry.value });
    }
    this.draft = this.rebuild(this.draft.content, entries, this.draft.tags, this.draft.level);
    this.isDirty = true;
    this.clearError(key);
  }

  private addTag(tag: string): void {
    const tags: string[] = this.draft.tags.slice();
    if (!tags.includes(tag)) {
      tags.push(tag);
    }
    this.draft = this.rebuild(this.draft.content, this.draft.entries, tags, this.draft.level);
    this.isDirty = true;
  }

  private removeTag(tag: string): void {
    const tags: string[] = [];
    for (const item of this.draft.tags) {
      if (item !== tag) {
        tags.push(item);
      }
    }
    this.draft = this.rebuild(this.draft.content, this.draft.entries, tags, this.draft.level);
    this.isDirty = true;
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.service === null) {
      this.getUIContext().getPromptAction().showToast({ message: '数据库尚未就绪' });
      return;
    }
    const validation = validateNoteDraft(this.draft);
    this.errors = validation.errors;
    if (!validation.valid) {
      this.getUIContext().getPromptAction().showToast({ message: validation.errors[0].message });
      return;
    }
    this.isSaving = true;
    try {
      await this.service.save(this.draft);
      this.isDirty = false;
      const message = this.draft.templateId === NoteTemplateId.DECISION ? '已保存，并生成决策记录' : '已保存';
      this.getUIContext().getPromptAction().showToast({ message: message });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请稍后重试' });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            NoteTemplatePicker({
              selected: this.draft.templateId,
              onSelect: (templateId: NoteTemplateId | null) => {
                this.applyTemplate(templateId);
              }
            })

            Column({ space: 6 }) {
              Row({ space: 4 }) {
                Text(this.draft.templateId === null ? '正文 *' : '正文（可选）')
                  .fontSize(12)
                  .fontColor('#5F5E5A')
              }
              .width('100%')

              TextArea({ text: this.draft.content, placeholder: '先记一句…' })
                .fontSize(13)
                .height(88)
                .padding(10)
                .backgroundColor('#F7F9FC')
                .borderRadius(10)
                .border({ width: 0.5, color: this.errorFor(null).length > 0 ? '#A32D2D' : '#E0E0E0' })
                .onChange((value: string) => {
                  this.updateContent(value);
                })

              if (this.errorFor(null).length > 0) {
                Text(this.errorFor(null))
                  .fontSize(11)
                  .fontColor('#A32D2D')
                  .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            if (this.draft.templateId !== null) {
              ForEach(this.draft.entries, (entry: NoteEntry) => {
                NoteFieldEditor({
                  field: this.fieldFor(entry.key),
                  value: entry.value,
                  error: this.errorFor(entry.key),
                  onValueChange: (value: string) => {
                    this.updateEntry(entry.key, value);
                  }
                })
              }, (entry: NoteEntry) => entry.key)
            }

            NoteTagEditor({
              tags: this.draft.tags,
              onAdd: (tag: string) => {
                this.addTag(tag);
              },
              onRemove: (tag: string) => {
                this.removeTag(tag);
              }
            })

            Row() {
              Text('密级')
                .fontSize(12)
                .fontColor('#8A8F99')
              Text(securityLevelText(this.draft.level))
                .fontSize(12)
                .fontColor('#5F5E5A')
                .margin({ left: 12 })
              Blank()
              Text('跟随设置')
                .fontSize(11)
                .fontColor('#B0B4BE')
            }
            .width('100%')
            .padding({ top: 4 })
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Column() {
          NoteSaveBar({
            saving: this.isSaving,
            onSave: () => {
              this.save();
            }
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F6F8')
    }
    .title('速记')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param !== undefined) {
        const params = context.pathInfo.param as NoteEditParams;
        this.applyTemplate(params.templateId);
      }
    })
    .onBackPressed(() => {
      if (!this.isDirty) {
        return false;
      }
      this.getUIContext().showAlertDialog({
        title: '放弃这条速记？',
        message: '已填写的内容不会保存。',
        primaryButton: {
          value: '继续编辑',
          action: () => {
          }
        },
        secondaryButton: {
          value: '放弃',
          action: () => {
            this.isDirty = false;
            if (this.navStack !== null) {
              this.navStack.pop();
            }
          }
        }
      });
      return true;
    })
  }
}
