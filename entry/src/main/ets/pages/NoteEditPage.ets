import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import {
  NoteDraft,
  NoteMaterialDraft,
  NoteDetail,
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
import { RelationListItem, RelationService } from '../relation';
import { PREVIEW_RELATION_ITEMS } from '../preview/PreviewData';
import { previewStore } from '../preview/PreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Quick capture editor: template picker, dynamic fields, tags and save. */
@ComponentV2
export struct NoteEditPage {
  @Local draft: NoteDraft = createFreeformNoteDraft();
  @Local errors: NoteValidationError[] = [];
  @Local isSaving: boolean = false;
  @Local isDirty: boolean = false;
  @Local service: QuickNoteService | null = null;
  @Local relations: RelationListItem[] = [];
  @Local isPreview: boolean = false;
  @Local noteId: string | null = null;
  @Local isEditing: boolean = false;
  /** Level from settings; the draft keeps its own level once the user picks one. */
  @Local defaultLevel: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Local materialScene: string = '';
  @Local materialFeeling: string = '';
  @Local materialBody: string = '';
  @Local materialAction: string = '';
  private navStack: NavPathStack | null = null;

  async aboutToAppear(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isPreview = true;
      this.relations = PREVIEW_RELATION_ITEMS.slice();
      return;
    }
    try {
      const settings = await SettingsStore.open(hostContext);
      const values = await settings.load();
      this.defaultLevel = values.defaultLevel;
      // A note opened for editing keeps the level stored with it, so the default must not overwrite it.
      if (!this.isEditing) {
        this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags, values.defaultLevel);
      }
      this.service = await QuickNoteService.open(hostContext);
      const relationService = await RelationService.open(hostContext);
      this.relations = await relationService.list(null);
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
      relatedRelationIds: this.draft.relatedRelationIds.slice(),
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

  private toggleRelation(relationId: string): void {
    const ids: string[] = this.draft.relatedRelationIds.slice();
    const next: string[] = [];
    let removed = false;
    for (const id of ids) {
      if (id === relationId) {
        removed = true;
      } else {
        next.push(id);
      }
    }
    if (!removed) {
      next.push(relationId);
    }
    this.draft = {
      templateId: this.draft.templateId,
      title: this.draft.title,
      content: this.draft.content,
      entries: this.draft.entries,
      tags: this.draft.tags,
      relatedRelationIds: next,
      level: this.draft.level,
      timestamp: this.draft.timestamp
    };
    this.isDirty = true;
  }


  /** Collects the optional typed materials the user filled in. */
  private collectMaterials(): NoteMaterialDraft[] {
    const items: NoteMaterialDraft[] = [];
    this.pushMaterial(items, 'scene', this.materialScene);
    this.pushMaterial(items, 'feeling', this.materialFeeling);
    this.pushMaterial(items, 'body', this.materialBody);
    this.pushMaterial(items, 'existing_action', this.materialAction);
    return items;
  }

  private pushMaterial(items: NoteMaterialDraft[], kind: string, value: string): void {
    const trimmed = value.trim();
    if (trimmed.length > 0) {
      items.push({ kind: kind, text: trimmed });
    }
  }

  private setMaterial(kind: string, value: string): void {
    if (kind === 'scene') {
      this.materialScene = value;
    } else if (kind === 'feeling') {
      this.materialFeeling = value;
    } else if (kind === 'body') {
      this.materialBody = value;
    } else if (kind === 'existing_action') {
      this.materialAction = value;
    }
    this.isDirty = true;
  }

  private setLevel(level: SecurityLevel): void {
    this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags, level);
    this.isDirty = true;
  }

  /** Says what the chosen level changes about this note leaving the device. */
  private levelImpact(): string {
    if (this.draft.level === SecurityLevel.ANALYZABLE) {
      return '切到模型档并逐次确认后，这条记录可进入模型请求。';
    }
    if (this.draft.level === SecurityLevel.SEALED) {
      return '不进入模型请求、汇总、导出与备份，只在本机详情页可见。';
    }
    return '不进入任何模型请求；导出时需要你单独勾选。';
  }

  @Builder
  levelChip(level: SecurityLevel) {
    Text(securityLevelText(level))
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.draft.level === level ? Color.White : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.draft.level === level ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.setLevel(level);
      })
  }

  @Builder
  materialRow(label: string, hint: string, value: string, kind: string) {
    Row({ space: AppTheme.spacing.s8 }) {
      Text(label)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textSecondary)
        .width(48)
      TextInput({ text: value, placeholder: hint })
        .id(`material_${kind}`)
        .fontSize(AppTheme.font.body)
        .height(40)
        .layoutWeight(1)
        .backgroundColor(AppTheme.color.surfaceTint)
        .borderRadius(AppTheme.radius.md)
        .onChange((next: string) => {
          this.setMaterial(kind, next);
        })
    }
    .width('100%')
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.service === null && !this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '数据库尚未就绪' });
      return;
    }
    this.draft.materials = this.collectMaterials();
    const validation = validateNoteDraft(this.draft);
    this.errors = validation.errors;
    if (!validation.valid) {
      this.getUIContext().getPromptAction().showToast({ message: validation.errors[0].message });
      return;
    }
    this.isSaving = true;
    try {
      if (this.isPreview) {
        if (this.noteId === null) {
          previewStore.addNote(this.draft);
        } else {
          previewStore.updateNote(this.noteId, this.draft);
        }
      } else if (this.service !== null) {
        if (this.noteId === null) {
          await this.service.save(this.draft);
        } else {
          await this.service.updateNote(this.noteId, this.draft);
        }
      }
      notifyHomeRefresh();
      this.isDirty = false;
      const message = this.noteId === null ?
        (this.draft.templateId === NoteTemplateId.DECISION ? '已保存，并生成决策记录' : '已保存') :
        '修改已保存';
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

  private async loadNote(noteId: string): Promise<void> {
    this.noteId = noteId;
    this.isEditing = true;
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isPreview = true;
      const detail = previewStore.findNote(noteId);
      if (detail !== null) {
        this.applyNoteDetail(detail);
      }
      return;
    }
    try {
      if (this.service === null) {
        this.service = await QuickNoteService.open(hostContext);
      }
      const detail = await this.service.findNote(noteId);
      if (detail !== null) {
        this.applyNoteDetail(detail);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '速记读取失败' });
    }
  }

  private applyNoteDetail(detail: NoteDetail): void {
    this.draft = {
      templateId: null,
      title: detail.title,
      content: detail.content,
      entries: [],
      tags: detail.tags.slice(),
      relatedRelationIds: detail.relatedRelationIds.slice(),
      level: detail.level,
      timestamp: detail.timestamp
    };
    this.isDirty = false;
  }

  @Builder
  saveMenu() {
    Row() {
      Text(this.isSaving ? '保存中' : '保存')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(this.isSaving ? AppTheme.color.textMuted : AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s16 })
        .onClick(() => {
          if (!this.isSaving) {
            this.save();
          }
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    AppDestination({
      route: 'note_edit',
      title: this.isEditing ? '编辑速记' : '速记',
      content: () => {
        this.noteEditBody();
      },
      menus: () => {
        this.saveMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param !== undefined) {
          const params = context.pathInfo.param as NoteEditParams;
          if (params.noteId !== undefined && params.noteId !== null && params.noteId.length > 0) {
            this.loadNote(params.noteId);
          } else {
            this.applyTemplate(params.templateId);
          }
        }
      },
      onDestinationBackPressed: () => {
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
      }
    })
  }

  @Builder
  noteEditBody() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 6 }) {
              Text('类别')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              NoteTemplatePicker({
                selected: this.draft.templateId,
                onSelect: (templateId: NoteTemplateId | null) => {
                  this.applyTemplate(templateId);
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Row({ space: 4 }) {
                Text(this.draft.templateId === null ? '正文 *' : '正文（可选）')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondaryStrong)
              }
              .width('100%')

              TextArea({ text: this.draft.content, placeholder: '先记一句…' })
                .fontSize(AppTheme.font.bodyStrong)
                .height(88)
                .padding(AppTheme.spacing.s10)
                .backgroundColor(AppTheme.color.surfaceTint)
                .borderRadius(AppTheme.radius.md)
                .border({ width: 0.5, color: this.errorFor(null).length > 0 ? AppTheme.color.danger : AppTheme.color.border })
                .onChange((value: string) => {
                  this.updateContent(value);
                })

              if (this.errorFor(null).length > 0) {
                Text(this.errorFor(null))
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.danger)
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

            Column({ space: 8 }) {
              Text('关联关系（可选）')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              if (this.relations.length === 0) {
                Text('关系层还没有记录，可先去载入示例关系')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              } else {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.relations, (relation: RelationListItem) => {
                    Text(relation.name)
                      .fontSize(AppTheme.font.body)
                      .fontColor(this.draft.relatedRelationIds.includes(relation.id) ? Color.White : AppTheme.color.textSecondaryStrong)
                      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                      .backgroundColor(this.draft.relatedRelationIds.includes(relation.id) ? AppTheme.color.primary : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.md)
                      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                      .onClick(() => {
                        this.toggleRelation(relation.id);
                      })
                  }, (relation: RelationListItem) => relation.id)
                }
                .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Text('分类补充（可选）')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textSecondaryStrong)
                .width('100%')
              Text('分开写现场、感受、身体和已经做过的事；不填也能保存，正文会作为未分类材料留档。')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
              this.materialRow('现场', '看到、听到、发生了什么', this.materialScene, 'scene')
              this.materialRow('感受', '当时的情绪', this.materialFeeling, 'feeling')
              this.materialRow('身体', '睡眠、疼痛、疲劳等', this.materialBody, 'body')
              this.materialRow('已做', '解释之前已经采取了什么行动', this.materialAction, 'existing_action')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              Row() {
                Text('密级')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                Blank()
                Text(this.draft.level === this.defaultLevel ? '跟随设置' : '本条第独立指定')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textMuted)
              }
              .width('100%')

              Flex({ wrap: FlexWrap.Wrap }) {
                this.levelChip(SecurityLevel.ANALYZABLE)
                this.levelChip(SecurityLevel.LOCAL_ONLY)
                this.levelChip(SecurityLevel.SEALED)
              }
              .width('100%')

              Text(this.levelImpact())
                .fontSize(AppTheme.font.caption)
                .lineHeight(15)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: AppTheme.spacing.s4 })
          }
          .width('100%')
          .padding(AppTheme.spacing.s16)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        Column() {
          NoteSaveBar({
            saving: this.isSaving,
            onSave: () => {
              this.save();
            }
          })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }
}
