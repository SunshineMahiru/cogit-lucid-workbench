import { AppTheme } from '../theme/AppTheme';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppDestination } from '../components/AppDestination';
import {
  NoteDepth,
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
  formatNoteTime,
  mergeDraftEntries,
  securityLevelText,
  validateNoteDraft
} from '../note';
import { NoteEditorDraft, NoteEditorMeta, NoteEditorStore } from '../note/NoteEditorStore';
import { DELETED_NOTE_TITLE } from '../note/NoteListMapper';
import { SecurityLevel } from '../model/SecurityLevel';
import { ExperienceMaterial, InteractionSource, MaterialForm, MaterialSource, MaterialStance } from '../model/ExperienceMaterial';
import { NoteEditParams, PredictionCreateParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { SettingsStore } from '../settings';
import { NoteFieldEditor } from '../components/NoteFieldEditor';
import { NoteSaveBar } from '../components/NoteSaveBar';
import { NoteTagEditor } from '../components/NoteTagEditor';
import { NoteTemplatePicker } from '../components/NoteTemplatePicker';
import { RelationListItem, RelationService } from '../relation';
import { PREVIEW_RELATION_ITEMS } from '../preview/PreviewData';
import { previewStore } from '../preview/PreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Pause after the last edit before the unsaved draft is written. */
const DRAFT_SAVE_DELAY_MS = 300;

const DOMAIN = 0x0000;
const TAG = 'CogitLucidNoteEdit';

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
  /** Set when the opened record has been deleted; the page then shows only its tombstone. */
  @Local isDeleted: boolean = false;
  @Local deletedAt: number = 0;
  /** Level from settings; the draft keeps its own level once the user picks one. */
  @Local defaultLevel: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Local materialScene: string = '';
  @Local materialFeeling: string = '';
  @Local materialBody: string = '';
  @Local materialAction: string = '';
  @Local materialInterpretation: string = '';
  @Local showInterpretation: boolean = false;
  /** Source, form and level chosen per material kind */
  @Local metas: MaterialMeta[] = defaultMaterialMetas();
  /** Kind chosen by the single quick chip; empty means unclassified */
  @Local quickKind: string = '';
  /** Source and form of the quick material; folded away behind one summary row */
  @Local quickSource: MaterialSource = 'direct';
  @Local quickForm: MaterialForm = 'first_person';
  @Local quickMetaOpen: boolean = false;
  @Local quickClaimEvidence: string = '';
  @Local quickFeeling: string = '';
  @Local quickInterpretation: string = '';
  @Local quickInterpOpen: boolean = false;
  /** True once a reopened note filled the quick source and form from its material */
  private quickMetaRestored: boolean = false;
  /** Interpersonal source chosen for this draft; empty means unmarked */
  @Local interactionSource: InteractionSource = '';
  /** Unsaved state found on entry; shown as a resume prompt until handled */
  @Local pendingDraft: NoteEditorDraft | null = null;
  @Local recentTags: string[] = [];
  private navStack: NavPathStack | null = null;
  private editorStore: NoteEditorStore | null = null;
  /** False once the author abandoned this note, so nothing is written back */
  private keepDraft: boolean = true;
  /** Pending throttled draft write; -1 means nothing is scheduled */
  private draftTimer: number = -1;

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
      const editorStore = await NoteEditorStore.open(hostContext);
      this.editorStore = editorStore;
      this.recentTags = await editorStore.loadRecentTags();
      const storedDepth = await editorStore.loadDepth();
      await this.applyStoredEditorState(editorStore, values.defaultLevel, storedDepth);
      this.service = await QuickNoteService.open(hostContext);
      const relationService = await RelationService.open(hostContext);
      this.relations = await relationService.list(null);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '初始化失败，请重试' });
    }
  }

  /**
   * Restores the depth and the stored draft of a new note. A note opened for editing keeps the
   * level stored with it, and a draft the author has not answered yet keeps its own level, so the
   * settings default is applied only when there is nothing to restore.
   */
  private async applyStoredEditorState(store: NoteEditorStore, defaultLevel: SecurityLevel,
    depth: NoteDepth): Promise<void> {
    if (this.isEditing || this.noteId !== null) {
      return;
    }
    const stored = await store.loadDraft();
    // The note may have been opened for editing while the draft was being read.
    if (this.isEditing || this.noteId !== null) {
      return;
    }
    if (stored !== null) {
      this.pendingDraft = stored;
      this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags,
        this.draft.level, depth);
      return;
    }
    this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags,
      defaultLevel, depth);
  }

  private rebuild(content: string, entries: NoteEntry[], tags: string[], level: SecurityLevel,
    depth: NoteDepth): NoteDraft {
    return {
      templateId: this.draft.templateId,
      title: this.draft.title,
      content: content,
      entries: entries,
      tags: tags,
      relatedRelationIds: this.draft.relatedRelationIds.slice(),
      level: level,
      depth: depth,
      timestamp: this.draft.timestamp
    };
  }

  private applyTemplate(templateId: NoteTemplateId | null): void {
    const depth = this.currentDepth();
    this.draft = mergeDraftEntries(this.draft, templateId);
    this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags,
      this.draft.level, depth);
    this.errors = [];
  }

  /** Depth selected in the editor; a fresh capture starts at the quick tier. */
  private currentDepth(): NoteDepth {
    return this.draft.depth ?? NoteDepth.QUICK;
  }

  /** Stored depth text mapped back to the editor scale; absent reads as quick. */
  private depthFromText(text: string | undefined): NoteDepth {
    if (text === NoteDepth.QUICK || text === undefined) {
      return NoteDepth.QUICK;
    }
    if (text === NoteDepth.DEEP) {
      return NoteDepth.DEEP;
    }
    return NoteDepth.NORMAL;
  }

  private isQuick(): boolean {
    return this.currentDepth() === NoteDepth.QUICK;
  }

  private isDeep(): boolean {
    return this.currentDepth() === NoteDepth.DEEP;
  }

  /** True for the material kinds the quick row writes. */
  private isQuickKind(kind: string): boolean {
    return QUICK_KIND_VALUES.indexOf(kind) >= 0;
  }

  /** True when this note records an interpersonal event, or already carries a restored source. */
  private showsInteractionSource(): boolean {
    return this.draft.templateId === NoteTemplateId.INTERPERSONAL || this.interactionSource.length > 0;
  }

  private setInteractionSource(source: InteractionSource): void {
    this.interactionSource = source;
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private setDepth(depth: NoteDepth): void {
    this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags,
      this.draft.level, depth);
    this.scheduleDraftSave();
    if (this.editorStore !== null) {
      this.editorStore.saveDepth(depth).catch(() => {
      });
    }
  }

  private setQuickKind(kind: string): void {
    this.quickKind = kind;
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private setQuickSource(source: MaterialSource): void {
    this.quickSource = source;
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private setQuickForm(form: MaterialForm): void {
    this.quickForm = form;
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private toggleQuickMeta(): void {
    this.quickMetaOpen = !this.quickMetaOpen;
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
    this.draft = this.rebuild(value, this.draft.entries, this.draft.tags, this.draft.level, this.currentDepth());
    this.isDirty = true;
    this.clearError(null);
    this.scheduleDraftSave();
  }

  private updateEntry(key: NoteFieldKey, value: string): void {
    const entries: NoteEntry[] = [];
    for (const entry of this.draft.entries) {
      entries.push({ key: entry.key, value: entry.key === key ? value : entry.value });
    }
    this.draft = this.rebuild(this.draft.content, entries, this.draft.tags, this.draft.level, this.currentDepth());
    this.isDirty = true;
    this.clearError(key);
    this.scheduleDraftSave();
  }

  private addTag(tag: string): void {
    const tags: string[] = this.draft.tags.slice();
    if (!tags.includes(tag)) {
      tags.push(tag);
    }
    this.draft = this.rebuild(this.draft.content, this.draft.entries, tags, this.draft.level, this.currentDepth());
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private removeTag(tag: string): void {
    const tags: string[] = [];
    for (const item of this.draft.tags) {
      if (item !== tag) {
        tags.push(item);
      }
    }
    this.draft = this.rebuild(this.draft.content, this.draft.entries, tags, this.draft.level, this.currentDepth());
    this.isDirty = true;
    this.scheduleDraftSave();
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
      depth: this.currentDepth(),
      timestamp: this.draft.timestamp
    };
    this.isDirty = true;
    this.scheduleDraftSave();
  }


  /** Collects the optional typed materials the user filled in; quick capture adds its kind row. */
  private collectMaterials(): NoteMaterialDraft[] {
    const items: NoteMaterialDraft[] = [];
    this.pushMaterial(items, 'scene', this.materialScene);
    this.pushMaterial(items, 'feeling', this.materialFeeling);
    this.pushMaterial(items, 'body', this.materialBody);
    this.pushMaterial(items, 'existing_action', this.materialAction);
    this.pushMaterial(items, 'interpretation', this.materialInterpretation);
    if (this.isQuick()) {
      this.pushQuickMaterial(items);
    }
    this.applyInteractionSource(items);
    return items;
  }

  /** Tags this session's interpersonal materials; a scene row stands in when none is marked. */
  private applyInteractionSource(items: NoteMaterialDraft[]): void {
    if (this.interactionSource.length === 0) {
      return;
    }
    let tagged = false;
    for (const item of items) {
      if (item.source === 'interaction') {
        item.interactionSource = this.interactionSource;
        tagged = true;
      }
    }
    if (tagged) {
      return;
    }
    for (const item of items) {
      if (item.kind === 'scene') {
        item.source = 'interaction';
        item.interactionSource = this.interactionSource;
        return;
      }
    }
  }

  /** Quick capture writes scene always, feeling and interpretation only when filled. */
  private pushQuickMaterial(items: NoteMaterialDraft[]): void {
    const text = this.draft.content.trim();
    if (text.length === 0) {
      return;
    }
    items.push({
      kind: 'scene',
      text: text,
      source: this.quickSource,
      form: this.quickForm,
      claimEvidence: this.quickForm === 'public_claim' ? this.quickClaimEvidence : ''
    });
    if (this.quickFeeling.trim().length > 0) {
      items.push({ kind: 'feeling', text: this.quickFeeling.trim(), source: this.quickSource, form: 'first_person' });
    }
    if (this.quickInterpOpen && this.quickInterpretation.trim().length > 0) {
      items.push({ kind: 'interpretation', text: this.quickInterpretation.trim(), source: this.quickSource, form: this.quickForm });
    }
  }

  private pushMaterial(items: NoteMaterialDraft[], kind: string, value: string): void {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return;
    }
    const meta = this.metaFor(kind);
    const item: NoteMaterialDraft = {
      kind: kind,
      text: trimmed,
      source: meta.source,
      form: meta.form
    };
    if (meta.level !== null) {
      item.level = meta.level;
    }
    if (meta.source === 'reading' && meta.stance.length > 0) {
      item.stance = meta.stance;
    }
    items.push(item);
  }

  /** Returns the source, form and level chosen for one material kind. */
  private metaFor(kind: string): MaterialMeta {
    for (const meta of this.metas) {
      if (meta.kind === kind) {
        return meta;
      }
    }
    return { kind: kind, source: 'direct', form: '', level: null, stance: '' };
  }

  private setSource(kind: string, source: MaterialSource): void {
    this.metas = this.metas.map((meta: MaterialMeta) => meta.kind === kind ?
      { kind: kind, source: source, form: meta.form, level: meta.level, stance: meta.stance } : meta);
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private setForm(kind: string, form: MaterialForm): void {
    this.metas = this.metas.map((meta: MaterialMeta) => meta.kind === kind ?
      { kind: kind, source: meta.source, form: form, level: meta.level, stance: meta.stance } : meta);
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private setMaterialLevel(kind: string, level: SecurityLevel | null): void {
    this.metas = this.metas.map((meta: MaterialMeta) => meta.kind === kind ?
      { kind: kind, source: meta.source, form: meta.form, level: level, stance: meta.stance } : meta);
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private setStance(kind: string, stance: MaterialStance): void {
    this.metas = this.metas.map((meta: MaterialMeta) => meta.kind === kind ?
      { kind: kind, source: meta.source, form: meta.form, level: meta.level, stance: stance } : meta);
    this.isDirty = true;
    this.scheduleDraftSave();
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
    } else if (kind === 'interpretation') {
      this.materialInterpretation = value;
    }
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  private setLevel(level: SecurityLevel): void {
    this.draft = this.rebuild(this.draft.content, this.draft.entries, this.draft.tags, level, this.currentDepth());
    this.metas = this.clampMetas(this.metas, level);
    this.isDirty = true;
    this.scheduleDraftSave();
  }

  /** Opens the prediction form on top of this note, so the two stay linked in the flow. */
  private openPrediction(): void {
    if (this.navStack === null) {
      return;
    }
    const params: PredictionCreateParams = { sourcePredictionId: null };
    this.navStack.pushPathByName(ROUTES.PREDICTION_CREATE, params);
  }

  /** Drops any per-material level wider than the new record level, so it follows the record. */
  private clampMetas(metas: MaterialMeta[], recordLevel: SecurityLevel): MaterialMeta[] {
    const next: MaterialMeta[] = [];
    for (const meta of metas) {
      const kept: SecurityLevel | null = meta.level !== null &&
        this.levelRank(meta.level) >= this.levelRank(recordLevel) ? meta.level : null;
      next.push({ kind: meta.kind, source: meta.source, form: meta.form, level: kept, stance: meta.stance });
    }
    return next;
  }

  /** Larger rank means a stricter level: sealed over local-only over analyzable. */
  private levelRank(level: SecurityLevel): number {
    if (level === SecurityLevel.SEALED) {
      return 2;
    }
    if (level === SecurityLevel.LOCAL_ONLY) {
      return 1;
    }
    return 0;
  }

  /** Level chips allowed for one material under the current record level. */
  private materialLevelOptions(): LevelOption[] {
    const options: LevelOption[] = [];
    for (const option of LEVEL_OPTIONS) {
      if (option.level === null || this.levelRank(option.level) >= this.levelRank(this.draft.level)) {
        options.push(option);
      }
    }
    return options;
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
      .fontColor(this.draft.level === level ? AppTheme.color.primaryDeep : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.draft.level === level ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .id(recordLevelChipId(level))
      .onClick(() => {
        this.setLevel(level);
      })
  }

  @Builder
  depthChip(depth: NoteDepth, id: string, label: string) {
    Text(label)
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.currentDepth() === depth ? AppTheme.color.primaryDeep : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.currentDepth() === depth ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .id(id)
      .onClick(() => {
        this.setDepth(depth);
      })
  }

  @Builder
  quickKindChip(kind: string, label: string, id: string) {
    Text(label)
      .fontSize(AppTheme.font.body)
      .fontColor(this.quickKind === kind ? AppTheme.color.primaryDeep : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.quickKind === kind ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.md)
      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .id(id)
      .onClick(() => {
        this.setQuickKind(kind);
      })
  }

  @Builder
  quickSourceChip(option: MetaOption) {
    Text(option.label)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.quickSource === option.value ? AppTheme.color.primaryDeep : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: 2, bottom: 2 })
      .backgroundColor(this.quickSource === option.value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .margin({ right: AppTheme.spacing.s4, bottom: AppTheme.spacing.s2 })
      .id(`quick_source_${option.value}`)
      .onClick(() => {
        this.setQuickSource(option.value as MaterialSource);
      })
  }

  @Builder
  quickFormChip(option: MetaOption) {
    Text(option.label)
      .fontSize(AppTheme.font.caption)
      .fontColor(this.quickForm === option.value ? AppTheme.color.primaryDeep : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: 2, bottom: 2 })
      .backgroundColor(this.quickForm === option.value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
      .margin({ right: AppTheme.spacing.s4, bottom: AppTheme.spacing.s2 })
      .id(`quick_form_${formKey(option.value)}`)
      .onClick(() => {
        this.setQuickForm(option.value as MaterialForm);
      })
  }

  @Builder
  materialRow(label: string, hint: string, value: string, kind: string) {
    Column({ space: 4 }) {
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

      if (value.trim().length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(SOURCE_OPTIONS, (option: MetaOption) => {
            Text(option.label)
              .fontSize(AppTheme.font.caption)
              .fontColor(this.metaFor(kind).source === option.value ?
                AppTheme.color.primaryDeep : AppTheme.color.text)
              .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: 2, bottom: 2 })
              .backgroundColor(this.metaFor(kind).source === option.value ?
                AppTheme.color.tint : AppTheme.color.chip)
              .borderRadius(AppTheme.radius.sm)
              .margin({ right: AppTheme.spacing.s4, bottom: AppTheme.spacing.s2 })
              .id(`material_source_${kind}_${option.value}`)
              .onClick(() => {
                this.setSource(kind, option.value as MaterialSource);
              })
          }, (option: MetaOption) => option.value)
        }
        .width('100%')

        if (this.metaFor(kind).source === 'reading') {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(STANCE_OPTIONS, (option: MetaOption) => {
              Text(option.label)
                .fontSize(AppTheme.font.caption)
                .fontColor(this.metaFor(kind).stance === option.value ?
                  AppTheme.color.primaryDeep : AppTheme.color.text)
                .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: 2, bottom: 2 })
                .backgroundColor(this.metaFor(kind).stance === option.value ?
                  AppTheme.color.tint : AppTheme.color.chip)
                .borderRadius(AppTheme.radius.sm)
                .margin({ right: AppTheme.spacing.s4, bottom: AppTheme.spacing.s2 })
                .id(`material_stance_${kind}_${option.value}`)
                .onClick(() => {
                  this.setStance(kind, option.value as MaterialStance);
                })
            }, (option: MetaOption) => option.value)
          }
          .width('100%')
        }

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(FORM_OPTIONS, (option: MetaOption) => {
            Text(option.label)
              .fontSize(AppTheme.font.caption)
              .fontColor(this.metaFor(kind).form === option.value ?
                AppTheme.color.primaryDeep : AppTheme.color.text)
              .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: 2, bottom: 2 })
              .backgroundColor(this.metaFor(kind).form === option.value ?
                AppTheme.color.tint : AppTheme.color.chip)
              .borderRadius(AppTheme.radius.sm)
              .margin({ right: AppTheme.spacing.s4, bottom: AppTheme.spacing.s2 })
              .id(`material_form_${kind}_${formKey(option.value)}`)
              .onClick(() => {
                this.setForm(kind, option.value as MaterialForm);
              })
          }, (option: MetaOption) => formKey(option.value))
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.materialLevelOptions(), (option: LevelOption) => {
            Text(option.label)
              .fontSize(AppTheme.font.caption)
              .fontColor(this.levelPicked(kind, option.level) ?
                AppTheme.color.primaryDeep : AppTheme.color.text)
              .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: 2, bottom: 2 })
              .backgroundColor(this.levelPicked(kind, option.level) ?
                AppTheme.color.tint : AppTheme.color.chip)
              .borderRadius(AppTheme.radius.sm)
              .margin({ right: AppTheme.spacing.s4, bottom: AppTheme.spacing.s2 })
              .id(`material_level_${kind}_${levelKey(option.level)}`)
              .onClick(() => {
                this.setMaterialLevel(kind, option.level);
              })
          }, (option: LevelOption) => levelKey(option.level))
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** True when this level option matches the material's own level (inherit matches none). */
  private levelPicked(kind: string, level: SecurityLevel | null): boolean {
    return this.metaFor(kind).level === level;
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.service === null && !this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '数据库尚未就绪' });
      return;
    }
    if (!this.validateBeforeSave()) {
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
      this.rememberTags();
      // Only a new note consumes the stored draft; editing an existing note leaves it alone.
      if (this.isEditing) {
        this.cancelDraftTimer();
      } else {
        this.clearStoredDraft();
      }
      const message = this.noteId === null ?
        (!this.isQuick() && this.draft.templateId === NoteTemplateId.DECISION ?
          '已保存，并生成决策记录' : '已保存') :
        '修改已保存';
      this.getUIContext().getPromptAction().showToast({ message: message });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'save failed: noteId=%{public}s editing=%{public}s error=%{private}s',
        this.noteId ?? 'new', this.isEditing ? 'true' : 'false', (error as Error).message);
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请稍后重试' });
    } finally {
      this.isSaving = false;
    }
  }

  /** Stores the draft as a new revision of the open note, leaving the earlier rows untouched. */
  private async saveAsNewVersion(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.noteId === null) {
      return;
    }
    const noteId = this.noteId;
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '演示模式下不能另存新版本' });
      return;
    }
    if (this.service === null) {
      this.getUIContext().getPromptAction().showToast({ message: '数据库尚未就绪' });
      return;
    }
    if (!this.validateBeforeSave()) {
      return;
    }
    this.isSaving = true;
    try {
      const saved = await this.service.saveRevision(noteId, this.draft);
      notifyHomeRefresh();
      this.isDirty = false;
      this.rememberTags();
      this.cancelDraftTimer();
      this.getUIContext().getPromptAction().showToast({ message: `已保存为 v${saved.version}` });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'save revision failed: noteId=%{public}s editing=%{public}s error=%{private}s',
        noteId, this.isEditing ? 'true' : 'false', (error as Error).message);
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请稍后重试' });
    } finally {
      this.isSaving = false;
    }
  }

  /** Collects materials and validates; false means the first error was already shown. */
  private validateBeforeSave(): boolean {
    this.draft.materials = this.collectMaterials();
    const validation = validateNoteDraft(this.draft);
    this.errors = validation.errors;
    if (!validation.valid) {
      this.getUIContext().getPromptAction().showToast({ message: validation.errors[0].message });
      return false;
    }
    return true;
  }

  private async loadNote(noteId: string): Promise<void> {
    this.noteId = noteId;
    this.isEditing = true;
    this.pendingDraft = null;
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
        this.isDeleted = await this.service.isDeleted(noteId);
        if (this.isDeleted) {
          this.deletedAt = detail.timestamp;
        } else {
          this.applyNoteDetail(detail);
        }
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
      depth: this.depthFromText(detail.depth),
      timestamp: detail.timestamp
    };
    this.quickKind = '';
    this.quickSource = 'direct';
    this.quickForm = 'first_person';
    this.quickMetaOpen = false;
    this.quickClaimEvidence = '';
    this.quickFeeling = '';
    this.quickInterpretation = '';
    this.quickInterpOpen = false;
    this.quickMetaRestored = false;
    this.materialScene = '';
    this.materialFeeling = '';
    this.materialBody = '';
    this.materialAction = '';
    this.materialInterpretation = '';
    this.showInterpretation = false;
    this.interactionSource = '';
    this.metas = defaultMaterialMetas();
    for (const material of detail.materials ?? []) {
      this.restoreMaterial(material);
    }
    this.isDirty = false;
  }

  /** Copies one stored material back into its kind row and chip meta. */
  private restoreMaterial(material: ExperienceMaterial): void {
    if (material.kind === 'scene') {
      this.materialScene = material.text;
    } else if (material.kind === 'feeling') {
      this.materialFeeling = material.text;
      this.quickFeeling = material.text;
    } else if (material.kind === 'body') {
      this.materialBody = material.text;
    } else if (material.kind === 'existing_action') {
      this.materialAction = material.text;
    } else if (material.kind === 'interpretation') {
      this.materialInterpretation = material.text;
      this.showInterpretation = true;
      this.quickInterpretation = material.text;
      this.quickInterpOpen = true;
    } else {
      return;
    }
    // The first material carrying a source fills the chip row when the note is reopened.
    if (this.interactionSource.length === 0 && (material.interactionSource ?? '').length > 0) {
      this.interactionSource = material.interactionSource ?? '';
    }
    // A material written by the quick row carries the source and form it was saved with.
    if (!this.quickMetaRestored && this.isQuickKind(material.kind)) {
      this.quickSource = material.source;
      this.quickForm = material.form;
      this.quickClaimEvidence = material.claimEvidence ?? '';
      this.quickMetaRestored = true;
    }
    // Stored rows may predate the record being narrowed, so apply the same rule as clampMetas:
    // a material wider than its record falls back to following the record.
    this.metas = this.clampMetas(this.metas.map((meta: MaterialMeta) => meta.kind === material.kind ?
      { kind: material.kind, source: material.source, form: material.form, level: material.level,
        stance: material.sourceStance } : meta),
      this.draft.level);
  }

  aboutToDisappear(): void {
    this.cancelDraftTimer();
    if (!this.isDirty || !this.canWriteDraft()) {
      return;
    }
    this.writeDraftNow();
  }

  /** A new note owns the draft slot; editing or an unanswered draft leaves the stored one intact. */
  private canWriteDraft(): boolean {
    if (this.editorStore === null || !this.keepDraft) {
      return false;
    }
    if (this.isEditing || this.noteId !== null || this.isDraftPending()) {
      return false;
    }
    return true;
  }

  /** Writes the editor state after the author pauses, so a crash keeps the latest typing. */
  private scheduleDraftSave(): void {
    if (this.editorStore === null || !this.canWriteDraft()) {
      return;
    }
    this.cancelDraftTimer();
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      this.writeDraftNow();
    }, DRAFT_SAVE_DELAY_MS);
  }

  private cancelDraftTimer(): void {
    if (this.draftTimer !== -1) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
  }

  private writeDraftNow(): void {
    if (!this.canWriteDraft()) {
      return;
    }
    const store = this.editorStore;
    if (store === null) {
      return;
    }
    store.saveDraft(this.snapshotDraft()).catch(() => {
    });
  }

  /** Editor state as the store keeps it, used for the unsaved draft. */
  private snapshotDraft(): NoteEditorDraft {
    const metas: NoteEditorMeta[] = [];
    for (const meta of this.metas) {
      metas.push({ kind: meta.kind, source: meta.source, form: meta.form, level: meta.level, stance: meta.stance });
    }
    return {
      content: this.draft.content,
      materials: {
        scene: this.materialScene,
        feeling: this.materialFeeling,
        body: this.materialBody,
        existingAction: this.materialAction,
        interpretation: this.materialInterpretation
      },
      metas: metas,
      tags: this.draft.tags.slice(),
      relatedRelationIds: this.draft.relatedRelationIds.slice(),
      level: this.draft.level,
      depth: this.currentDepth(),
      quickKind: this.quickKind,
      interactionSource: this.interactionSource,
      templateId: this.draft.templateId,
      entries: this.copyEntries(this.draft.entries),
      timestamp: this.draft.timestamp
    };
  }

  /** True while a stored draft of a new note waits for the author's choice. */
  private isDraftPending(): boolean {
    return this.pendingDraft !== null && !this.isEditing && this.noteId === null;
  }

  private copyEntries(entries: NoteEntry[]): NoteEntry[] {
    const copied: NoteEntry[] = [];
    for (const entry of entries) {
      copied.push({ key: entry.key, value: entry.value });
    }
    return copied;
  }

  private resumeDraft(snapshot: NoteEditorDraft): void {
    this.materialScene = snapshot.materials.scene;
    this.materialFeeling = snapshot.materials.feeling;
    this.materialBody = snapshot.materials.body;
    this.materialAction = snapshot.materials.existingAction;
    this.materialInterpretation = snapshot.materials.interpretation;
    this.showInterpretation = snapshot.materials.interpretation.trim().length > 0;
    this.metas = this.clampMetas(this.metasFromSnapshot(snapshot.metas), snapshot.level);
    this.quickKind = snapshot.quickKind;
    this.interactionSource = snapshot.interactionSource;
    this.draft = {
      templateId: snapshot.templateId,
      title: this.draft.title,
      content: snapshot.content,
      entries: this.copyEntries(snapshot.entries),
      tags: snapshot.tags.slice(),
      relatedRelationIds: snapshot.relatedRelationIds.slice(),
      level: snapshot.level,
      depth: snapshot.depth,
      timestamp: snapshot.timestamp
    };
    this.pendingDraft = null;
    this.isDirty = true;
  }

  private metasFromSnapshot(metas: NoteEditorMeta[]): MaterialMeta[] {
    const items: MaterialMeta[] = [];
    for (const meta of metas) {
      items.push({ kind: meta.kind, source: meta.source, form: meta.form, level: meta.level, stance: meta.stance });
    }
    return items;
  }

  private discardDraft(): void {
    this.pendingDraft = null;
    this.keepDraft = true;
    if (this.editorStore !== null) {
      this.editorStore.clearDraft().catch(() => {
      });
    }
  }

  /** Adds this note's tags to the recent list; failures only skip the shortcut. */
  private rememberTags(): void {
    if (this.editorStore === null) {
      return;
    }
    this.editorStore.mergeRecentTags(this.draft.tags)
      .then((tags: string[]) => {
        this.recentTags = tags;
      })
      .catch(() => {
      });
  }

  private clearStoredDraft(): void {
    this.cancelDraftTimer();
    this.pendingDraft = null;
    this.keepDraft = false;
    if (this.editorStore !== null) {
      this.editorStore.clearDraft().catch(() => {
      });
    }
  }

  @Builder
  saveMenu() {
    Row({ space: 4 }) {
      Text(this.isSaving ? '保存中' : (this.isEditing ? '保存更正' : '保存'))
        .fontSize(AppTheme.font.subtitle)
        .fontColor(this.isSaving ? AppTheme.color.textMuted : AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8 })
        .onClick(() => {
          if (!this.isSaving) {
            this.save();
          }
        })
      if (this.isEditing && this.noteId !== null) {
        Text('另存新版本')
          .fontSize(AppTheme.font.subtitle)
          .fontColor(this.isSaving ? AppTheme.color.textMuted : AppTheme.color.primary)
          .padding({ left: AppTheme.spacing.s4, right: AppTheme.spacing.s16 })
          .accessibilityText('另存新版本')
          .onClick(() => {
            if (!this.isSaving) {
              this.saveAsNewVersion();
            }
          })
      }
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    AppDestination({
      route: 'note_edit',
      title: this.isDeleted ? '速记详情' : (this.isEditing ? '编辑速记' : '速记'),
      content: () => {
        this.noteEditBody();
      },
      menus: () => {
        if (!this.isDeleted && !this.isDraftPending()) {
          this.saveMenu();
        }
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
        if (this.isDeleted) {
          return false;
        }
        // The stored draft waits for the author's choice; leaving it alone keeps that choice open.
        if (this.isDraftPending()) {
          return false;
        }
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
              this.keepDraft = false;
              this.cancelDraftTimer();
              // Only this round of typing goes away; a draft the author has not opened yet stays.
              if (this.editorStore !== null && !this.isDraftPending()) {
                this.editorStore.clearDraft().catch(() => {
                });
              }
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
        if (this.isDeleted) {
          Column({ space: 12 }) {
            Text(DELETED_NOTE_TITLE)
              .fontSize(AppTheme.font.headline)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.color.text)
              .width('100%')
            Text(formatNoteTime(this.deletedAt))
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          }
          .width('100%')
          .height('100%')
          .padding(AppTheme.spacing.s20)
          .alignItems(HorizontalAlign.Start)
        } else if (this.isDraftPending() && this.pendingDraft !== null) {
          this.draftResumePanel();
        } else {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 8 }) {
              Text('记录深度')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              Row({ space: AppTheme.spacing.s6 }) {
                this.depthChip(NoteDepth.QUICK, 'note_depth_quick', '快速')
                this.depthChip(NoteDepth.NORMAL, 'note_depth_normal', '普通')
                this.depthChip(NoteDepth.DEEP, 'note_depth_deep', '深入')
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            if (!this.isQuick()) {
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
            }

            Column({ space: 6 }) {
              Row({ space: 4 }) {
                Text(this.isQuick() ? '现场 *' : (!this.isQuick() && this.draft.templateId !== null ? '正文（可选）' : '正文 *'))
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondaryStrong)
              }
              .width('100%')

              TextArea({ text: this.draft.content, placeholder: this.isQuick() ? '此刻发生了什么' : '先记一句…' })
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

if (this.isQuick()) {
              Column({ space: 6 }) {
                Text('感受（可选）')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextArea({ text: this.quickFeeling, placeholder: '当时的情绪与体验（可空）' })
                  .id('note_quick_feeling')
                  .fontSize(AppTheme.font.bodyStrong)
                  .height(56)
                  .padding(AppTheme.spacing.s10)
                  .backgroundColor(AppTheme.color.surfaceTint)
                  .borderRadius(AppTheme.radius.md)
                  .border({ width: 0.5, color: AppTheme.color.border })
                  .onChange((value: string) => {
                    this.quickFeeling = value;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              Column({ space: 6 }) {
                Row() {
                  Text(this.quickInterpOpen ? '解释（收起）' : '解释（可选，展开）')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.primary)
                    .layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_down'))
                    .fontSize(14)
                    .fontColor([AppTheme.color.primary])
                    .rotate({ angle: this.quickInterpOpen ? 180 : 0 })
                }
                .id('note_quick_interp_toggle')
                .width('100%')
                .height(40)
                .onClick(() => {
                  this.quickInterpOpen = !this.quickInterpOpen;
                })
                if (this.quickInterpOpen) {
                  TextArea({ text: this.quickInterpretation, placeholder: '我怎样理解这件事（可空）' })
                    .id('note_quick_interpretation')
                    .fontSize(AppTheme.font.bodyStrong)
                    .height(56)
                    .padding(AppTheme.spacing.s10)
                    .backgroundColor(AppTheme.color.surfaceTint)
                    .borderRadius(AppTheme.radius.md)
                    .border({ width: 0.5, color: AppTheme.color.border })
                    .onChange((value: string) => {
                      this.quickInterpretation = value;
                    })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.isQuick()) {
              Column({ space: 6 }) {
                Text(`${quickSourceLabel(this.quickSource)} · ${quickFormLabel(this.quickForm)} · 改`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.primaryDeep)
                  .width('100%')
                  .id('quick_meta_summary')
                  .onClick(() => {
                    this.toggleQuickMeta();
                  })
                if (this.quickMetaOpen) {
                  Text('来源')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(QUICK_SOURCE_OPTIONS, (option: MetaOption) => {
                      this.quickSourceChip(option)
                    }, (option: MetaOption) => option.value)
                  }
                  .width('100%')
                  Text('文体')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(QUICK_FORM_OPTIONS, (option: MetaOption) => {
                      this.quickFormChip(option)
                    }, (option: MetaOption) => formKey(option.value))
                  }
                  .width('100%')
                  if (this.quickForm === 'public_claim') {
                    Text('公共主张需要超出私人经验的资料；可留空，不阻塞保存')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.warning)
                      .width('100%')
                    TextInput({ text: this.quickClaimEvidence, placeholder: '支撑这条主张的资料或证据（可空）' })
                      .id('note_claim_evidence')
                      .fontSize(AppTheme.font.bodyStrong)
                      .padding(AppTheme.spacing.s10)
                      .backgroundColor(AppTheme.color.surface)
                      .borderRadius(AppTheme.radius.sm)
                      .border({ width: 0.5, color: AppTheme.color.border })
                      .onChange((value: string) => {
                        this.quickClaimEvidence = value;
                      })
                  }
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (!this.isQuick() && this.draft.templateId !== null) {
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

            if (!this.isQuick() && this.showsInteractionSource()) {
              Column({ space: 4 }) {
                Text('互动来源（可选）')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(INTERACTION_SOURCE_OPTIONS, (option: MetaOption) => {
                    Text(option.label)
                      .fontSize(AppTheme.font.body)
                      .fontColor(this.interactionSource === option.value ?
                        AppTheme.color.primaryDeep : AppTheme.color.text)
                      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                      .backgroundColor(this.interactionSource === option.value ?
                        AppTheme.color.tint : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.md)
                      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                      .id(`interaction_source_${option.value}`)
                      .onClick(() => {
                        this.setInteractionSource(option.value as InteractionSource);
                      })
                  }, (option: MetaOption) => option.value)
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (!this.isQuick()) {
              NoteTagEditor({
                tags: this.draft.tags,
                recentTags: this.recentTags,
                onAdd: (tag: string) => {
                  this.addTag(tag);
                },
                onRemove: (tag: string) => {
                  this.removeTag(tag);
                },
                onPickRecent: (tag: string) => {
                  this.addTag(tag);
                }
              })
            }

            if (this.isDeep()) {
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
                        .fontColor(this.draft.relatedRelationIds.includes(relation.id) ? AppTheme.color.primaryDeep : AppTheme.color.text)
                        .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                        .backgroundColor(this.draft.relatedRelationIds.includes(relation.id) ? AppTheme.color.tint : AppTheme.color.chip)
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
            }

            if (this.isDeep()) {
              Text('新建一条可检验预测')
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.primary)
                .width('100%')
                .id('note_prediction_create')
                .onClick(() => {
                  this.openPrediction();
                })
            }

            if (!this.isQuick()) {
              Column({ space: 6 }) {
                Text('分类补充（可选）')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondaryStrong)
                  .width('100%')
                Text('分开写现场、感受、身体、已经做过的事和当时的解释；不填也能保存，正文会作为未分类材料留档。')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                this.materialRow('现场', '看到、听到、发生了什么', this.materialScene, 'scene')
                this.materialRow('感受', '当时的情绪', this.materialFeeling, 'feeling')
                this.materialRow('身体', '睡眠、疼痛、疲劳等', this.materialBody, 'body')
                this.materialRow('已做', '解释之前已经采取了什么行动', this.materialAction, 'existing_action')
                if (this.isDeep() || this.showInterpretation) {
                  this.materialRow('解释', '我当时的解释是什么？（可留空）', this.materialInterpretation, 'interpretation')
                } else {
                  Text('写解释（可留空）')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.primary)
                    .id('material_interpretation_toggle')
                    .onClick(() => {
                      this.showInterpretation = true;
                    })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (!this.isQuick()) {
              Column({ space: 8 }) {
                Row() {
                  Text('密级')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.textSecondary)
                  Blank()
                  Text(this.draft.level === this.defaultLevel ? '跟随设置' : '本条独立指定')
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }

  /** The only thing a note with an unanswered stored draft shows until the author chooses. */
  @Builder
  draftResumePanel() {
    Column({ space: 6 }) {
      Text('上次没写完的草稿还在')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondaryStrong)
        .width('100%')
      Row({ space: AppTheme.spacing.s8 }) {
        Text('继续上次草稿')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primaryDeep)
          .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
          .backgroundColor(AppTheme.color.tint)
          .borderRadius(AppTheme.radius.sm)
          .id('note_draft_resume')
          .onClick(() => {
            const pending = this.pendingDraft;
            if (pending !== null) {
              this.resumeDraft(pending);
            }
          })
        Text('重新开始')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.text)
          .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
          .backgroundColor(AppTheme.color.chip)
          .borderRadius(AppTheme.radius.sm)
          .id('note_draft_discard')
          .onClick(() => {
            this.discardDraft();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .alignItems(HorizontalAlign.Start)
  }
}

/** One chip option shared by the source and form rows. */
interface MetaOption {
  value: string;
  label: string;
}

/** One chip option of the per-material level row; a null level follows the record. */
interface LevelOption {
  level: SecurityLevel | null;
  label: string;
}

/** Source, form, level and reading stance kept for one material kind. */
interface MaterialMeta {
  kind: string;
  source: MaterialSource;
  form: MaterialForm;
  level: SecurityLevel | null;
  stance: MaterialStance;
}

const SOURCE_OPTIONS: MetaOption[] = [
  { value: 'direct', label: '直接经历' },
  { value: 'reading', label: '阅读' },
  { value: 'exercise', label: '练习' },
  { value: 'interaction', label: '互动' },
  { value: 'reflection', label: '反思' },
  { value: 'external', label: '外部资料' }
];

/** Material kinds the quick row writes. */
const QUICK_KIND_VALUES: string[] = ['scene', 'feeling', 'body', 'existing_action', 'interpretation'];

const QUICK_SOURCE_OPTIONS: MetaOption[] = [
  { value: 'direct', label: '亲身' },
  { value: 'reading', label: '阅读' },
  { value: 'exercise', label: '运动' },
  { value: 'interaction', label: '互动' },
  { value: 'reflection', label: '反思' },
  { value: 'external', label: '外部资料' }
];

const QUICK_FORM_OPTIONS: MetaOption[] = [
  { value: 'first_person', label: '第一人称现场' },
  { value: 'dialogue', label: '对话' },
  { value: 'third_person', label: '第三人称' },
  { value: 'poem', label: '诗歌' },
  { value: 'reading_note', label: '阅读笔记' },
  { value: 'public_claim', label: '公共主张' }
];

/** Label of a quick source value; an unknown value shows as itself. */
function quickSourceLabel(source: MaterialSource): string {
  for (const option of QUICK_SOURCE_OPTIONS) {
    if (option.value === source) {
      return option.label;
    }
  }
  return source;
}

/** Label of a quick form value; an unknown value shows as itself. */
function quickFormLabel(form: MaterialForm): string {
  for (const option of QUICK_FORM_OPTIONS) {
    if (option.value === form) {
      return option.label;
    }
  }
  return form;
}

const INTERACTION_SOURCE_OPTIONS: MetaOption[] = [
  { value: 'observed', label: '我的观察' },
  { value: 'stated', label: '对方明确说过' },
  { value: 'shared_activity', label: '一起做过' },
  { value: 'inferred', label: '我的推测' }
];

const STANCE_OPTIONS: MetaOption[] = [
  { value: 'support', label: '支持当前立场' },
  { value: 'challenge', label: '挑战当前立场' },
  { value: 'undecided', label: '尚未判断' }
];

const FORM_OPTIONS: MetaOption[] = [
  { value: '', label: '未标注' },
  { value: 'first_person', label: '第一人称' },
  { value: 'dialogue', label: '对话' },
  { value: 'third_person', label: '第三人称' },
  { value: 'poem', label: '诗' },
  { value: 'reading_note', label: '读书笔记' },
  { value: 'public_claim', label: '公开说法' }
];

const LEVEL_OPTIONS: LevelOption[] = [
  { level: null, label: '跟随记录' },
  { level: SecurityLevel.ANALYZABLE, label: '可分析' },
  { level: SecurityLevel.LOCAL_ONLY, label: '仅本地' },
  { level: SecurityLevel.SEALED, label: '已封存' }
];

/** Stable ForEach key for a form value; the unlabelled option has no value. */
function formKey(value: string): string {
  return value.length > 0 ? value : 'unlabelled';
}

/** Stable ForEach key and chip id for a material level; null means follow the record. */
function levelKey(level: SecurityLevel | null): string {
  return level === null ? 'inherit' : level;
}

/** Stable chip id for a record level, used by device checks. */
function recordLevelChipId(level: SecurityLevel): string {
  if (level === SecurityLevel.ANALYZABLE) {
    return 'note_level_analyzable';
  }
  if (level === SecurityLevel.LOCAL_ONLY) {
    return 'note_level_local';
  }
  return 'note_level_sealed';
}

/** Builds the default meta for every material kind supported by the editor. */
function defaultMaterialMetas(): MaterialMeta[] {
  const kinds: string[] = ['scene', 'feeling', 'body', 'existing_action', 'interpretation'];
  const metas: MaterialMeta[] = [];
  for (const kind of kinds) {
    metas.push({ kind: kind, source: 'direct', form: '', level: null, stance: '' });
  }
  return metas;
}
