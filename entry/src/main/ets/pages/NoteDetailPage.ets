import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import {
  NoteDetail,
  NoteListItem,
  QuickNoteService,
  materialFormText,
  materialKindText,
  materialSourceText,
  securityLevelText
} from '../note';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { DELETED_NOTE_TITLE } from '../note/NoteListMapper';
import { NoteDetailParams, NoteEditParams, PlanAttachParams } from '../navigation/RouteParams';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { ROUTES } from '../navigation/Routes';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { previewStore } from '../preview/PreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';
import { DELETE_UNDO_WINDOW_MS } from '../note/QuickNoteService';

/** Read-only view of one stored note. */
@ComponentV2
export struct NoteDetailPage {
  @Local detail: NoteDetail | null = null;
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local isDeleted: boolean = false;
  @Local isPreview: boolean = false;
  @Local revisions: NoteListItem[] = [];
  @Local showRevisions: boolean = false;
  @Local pendingUndoId: string = '';
  private navStack: NavPathStack | null = null;
  private undoTimer: number = -1;
  private undoing: boolean = false;

  aboutToDisappear(): void {
    // Back navigation leaves the delete in place; only the pending pop must not fire later.
    this.cancelUndoTimer();
  }

  private async load(noteId: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview(noteId);
      return;
    }
    try {
      const service = await QuickNoteService.open(hostContext);
      this.detail = await service.findNote(noteId);
      if (this.detail === null) {
        this.isDeleted = false;
      } else {
        this.isDeleted = await service.isDeleted(noteId);
      }
      this.missing = this.detail === null;
    } catch (error) {
      this.loadPreview(noteId);
    } finally {
      this.isLoading = false;
    }
  }

  private loadPreview(noteId: string): void {
    this.isPreview = true;
    this.detail = previewStore.findNote(noteId);
    this.isDeleted = false;
    this.missing = this.detail === null;
    this.isLoading = false;
  }

  private confirmDelete(): void {
    if (this.isPreview || this.detail === null) {
      this.getUIContext().getPromptAction().showToast({ message: '演示模式下不能删除速记' });
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除这条速记？',
      message: '删除后 5 秒内可撤销。',
      primaryButton: {
        value: '继续保留',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.deleteNote();
        }
      }
    });
  }

  private async deleteNote(): Promise<void> {
    if (this.detail === null) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '运行环境未就绪' });
      return;
    }
    try {
      const service = await QuickNoteService.open(hostContext);
      await service.delete(this.detail.id);
      notifyHomeRefresh();
      this.isDeleted = true;
      this.showRevisions = false;
      this.pendingUndoId = this.detail.id;
      this.startUndoTimer(this.detail.id);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '删除失败，请重试' });
    }
  }

  private startUndoTimer(noteId: string): void {
    this.cancelUndoTimer();
    this.undoTimer = setTimeout(() => {
      this.undoTimer = -1;
      if (this.pendingUndoId === noteId) {
        this.pendingUndoId = '';
      }
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    }, DELETE_UNDO_WINDOW_MS);
  }

  private cancelUndoTimer(): void {
    if (this.undoTimer !== -1) {
      clearTimeout(this.undoTimer);
      this.undoTimer = -1;
    }
  }

  private async undoPendingDelete(): Promise<void> {
    const noteId = this.pendingUndoId;
    if (noteId.length === 0 || this.undoing) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '恢复失败' });
      return;
    }
    this.undoing = true;
    try {
      const service = await QuickNoteService.open(hostContext);
      const restored = await service.undoDelete(noteId);
      if (!restored) {
        this.getUIContext().getPromptAction().showToast({ message: '恢复失败' });
        return;
      }
      this.cancelUndoTimer();
      this.pendingUndoId = '';
      notifyHomeRefresh();
      this.getUIContext().getPromptAction().showToast({ message: '已恢复' });
      await this.load(noteId);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '恢复失败' });
    } finally {
      this.undoing = false;
    }
  }

  private openAttach(): void {
    if (this.detail === null || this.navStack === null) {
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.NOTE,
      targetId: this.detail.id,
      label: this.detail.title
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  private openEdit(): void {
    if (this.detail === null || this.navStack === null || this.isDeleted) {
      return;
    }
    const params: NoteEditParams = { templateId: null, noteId: this.detail.id };
    this.navStack.pushPathByName(ROUTES.NOTE_EDIT, params, () => {
      if (this.detail !== null) {
        this.load(this.detail.id);
      }
    });
  }

  /** Revision number of the open row; an original note is v1. */
  private currentVersion(): number {
    return this.detail === null ? 1 : (this.detail.version ?? 1);
  }

  /** True when this row revises an earlier note. */
  private isRevision(): boolean {
    return this.detail !== null && (this.detail.revisionOf ?? '').length > 0;
  }

  /** Version this revision was written from. */
  private baseVersion(): number {
    const version = this.currentVersion();
    return version > 1 ? version - 1 : 1;
  }

  /** Loads the chain once, then toggles the read-only history list. */
  private async toggleRevisions(): Promise<void> {
    if (this.showRevisions) {
      this.showRevisions = false;
      return;
    }
    const detail = this.detail;
    if (detail === null || this.isPreview) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return;
    }
    try {
      const service = await QuickNoteService.open(hostContext);
      this.revisions = await service.listRevisions(detail.id);
      this.showRevisions = true;
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '历史版本加载失败' });
    }
  }

  private openRevision(noteId: string): void {
    if (this.navStack === null || this.detail === null || noteId === this.detail.id) {
      return;
    }
    const params: NoteDetailParams = { noteId: noteId };
    this.navStack.pushPathByName(ROUTES.NOTE_DETAIL, params);
  }

  /** Materials kept with the note; a copy of the body is shown as its kind only. */
  private noteMaterials(): ExperienceMaterial[] {
    const detail = this.detail;
    if (detail === null || detail.materials === undefined) {
      return [];
    }
    return detail.materials;
  }

  /** True when this material only repeats the body, so the card text would be duplication. */
  private isBodyEcho(material: ExperienceMaterial): boolean {
    const detail = this.detail;
    if (detail === null) {
      return false;
    }
    const body = detail.content.trim();
    return body.length > 0 && material.text.trim() === body;
  }

  @Builder
  editMenu() {
    Row({ space: 4 }) {
      Text('编辑')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s8 })
        .accessibilityText('编辑速记')
        .onClick(() => {
          this.openEdit();
        })
      Text('计划')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s4, right: AppTheme.spacing.s8 })
        .onClick(() => {
          this.openAttach();
        })
      Text('删除')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.danger)
        .padding({ left: AppTheme.spacing.s4, right: AppTheme.spacing.s16 })
        .accessibilityText('删除速记')
        .onClick(() => {
          this.confirmDelete();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  deleteMenu() {
    Text('删除')
      .fontSize(AppTheme.font.subtitle)
      .fontColor(AppTheme.color.danger)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s16 })
      .onClick(() => {
        this.confirmDelete();
      })
  }

  @Builder
  noteDetailPageBody() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.noteDetailBody();
      if (this.pendingUndoId.length > 0) {
        this.undoBar();
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  undoBar() {
    Column() {
      Row({ space: AppTheme.spacing.s8 }) {
        Text('已删除')
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        Text('撤销')
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.primary)
          .padding({
            left: AppTheme.spacing.s12,
            right: AppTheme.spacing.s12,
            top: AppTheme.spacing.s6,
            bottom: AppTheme.spacing.s6
          })
          .accessibilityText('撤销删除速记')
          .id('note_undo_action')
          .onClick(() => {
            this.undoPendingDelete();
          })
      }
      .id('note_undo_bar')
      .width('100%')
      .padding({
        left: AppTheme.spacing.s16,
        right: AppTheme.spacing.s12,
        top: AppTheme.spacing.s10,
        bottom: AppTheme.spacing.s10
      })
      .backgroundColor(AppTheme.color.surface)
      .borderRadius(AppTheme.radius.md)
      .shadow({ radius: 12, color: '#22000000', offsetX: 0, offsetY: 2 })
    }
    .width('100%')
    .padding({
      left: AppTheme.spacing.s16,
      right: AppTheme.spacing.s16,
      bottom: AppTheme.spacing.s16
    })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    AppDestination({
      route: 'note_detail',
      title: '速记详情',
      content: () => {
        this.noteDetailPageBody();
      },
      menus: () => {
        if (!this.isLoading && !this.missing && !this.isDeleted && this.detail !== null) {
          this.editMenu();
        }
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          this.missing = true;
          return;
        }
        const params = context.pathInfo.param as NoteDetailParams;
        this.load(params.noteId);
      }
    })
  }

  @Builder
  noteDetailBody() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppTheme.color.primary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      } else if (this.missing || this.detail === null) {
        Column() {
          NoteEmptyState({
            title: '记录不存在',
            hint: '可能已经被删除',
            actionLabel: '返回',
            onAction: () => {
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      } else if (this.isDeleted) {
        Column({ space: 12 }) {
          Text(DELETED_NOTE_TITLE)
            .fontSize(AppTheme.font.headline)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.color.text)
            .width('100%')
          Text(this.detail.timeLabel)
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
        .width('100%')
        .height('100%')
        .padding(AppTheme.spacing.s20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(Color.Transparent)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text(this.detail.type)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.primary)
                .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                .backgroundColor(AppTheme.color.tint)
                .borderRadius(AppTheme.radius.sm)
              Text(this.detail.timeLabel)
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.textMuted)
              Blank()
              Text(securityLevelText(this.detail.level))
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.textSecondary)
            }
            .width('100%')

            Row({ space: 8 }) {
              Text(this.detail.title)
                .fontSize(AppTheme.font.headline)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.color.text)
                .layoutWeight(1)
              if (this.currentVersion() > 1) {
                Text(`v${this.currentVersion()}`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.primaryDeep)
                  .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                  .backgroundColor(AppTheme.color.tint)
                  .borderRadius(AppTheme.radius.sm)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            if (this.isRevision()) {
              Text(`本版基于 v${this.baseVersion()} 修订`)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            }

            if (this.detail.tags.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.detail.tags, (tag: string) => {
                  Text(tag)
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.primaryDeep)
                    .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                    .backgroundColor(AppTheme.color.tint)
                    .borderRadius(AppTheme.radius.md)
                    .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
                }, (tag: string) => tag)
              }
              .width('100%')
            }

            Text(this.detail.content)
              .fontSize(AppTheme.font.subtitle)
              .lineHeight(24)
              .fontColor(AppTheme.color.text)
              .width('100%')

            if (!this.isPreview && (this.isRevision() || this.currentVersion() > 1)) {
              Column({ space: 6 }) {
                Text(this.showRevisions ? '收起历史版本' : '历史版本')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.primaryDeep)
                  .padding({ top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                  .id('note_revision_toggle')
                  .onClick(() => {
                    this.toggleRevisions();
                  })
                if (this.showRevisions) {
                  ForEach(this.revisions, (item: NoteListItem) => {
                    Column({ space: 2 }) {
                      Text(`v${item.version ?? 1} · ${item.timeLabel}`)
                        .fontSize(AppTheme.font.caption)
                        .fontColor(AppTheme.color.textMuted)
                        .width('100%')
                      Text(item.summary)
                        .fontSize(AppTheme.font.body)
                        .fontColor(AppTheme.color.text)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                    }
                    .width('100%')
                    .padding(AppTheme.spacing.s10)
                    .backgroundColor(AppTheme.color.surfaceTint)
                    .borderRadius(AppTheme.radius.md)
                    .alignItems(HorizontalAlign.Start)
                    .id(`note_revision_${item.id}`)
                    .onClick(() => {
                      this.openRevision(item.id);
                    })
                  }, (item: NoteListItem) => `${item.id}_${item.version ?? 1}`)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.noteMaterials().length > 0) {
              Column({ space: 6 }) {
                Text('材料')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                ForEach(this.noteMaterials(), (material: ExperienceMaterial) => {
                  if (this.isBodyEcho(material)) {
                    Text(`类型：${materialKindText(material.kind)}`)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                      .id(`note_material_kind_${material.id}`)
                  } else {
                    Column({ space: 4 }) {
                      Text(`${materialKindText(material.kind)} · ${materialSourceText(material.source)} · ` +
                        `${materialFormText(material.form)} · ${securityLevelText(material.level)}`)
                        .fontSize(AppTheme.font.caption)
                        .fontColor(AppTheme.color.textMuted)
                        .width('100%')
                      Text(material.text)
                        .fontSize(AppTheme.font.body)
                        .lineHeight(20)
                        .fontColor(AppTheme.color.text)
                        .width('100%')
                    }
                    .width('100%')
                    .padding(AppTheme.spacing.s10)
                    .backgroundColor(AppTheme.color.surfaceTint)
                    .borderRadius(AppTheme.radius.md)
                    .alignItems(HorizontalAlign.Start)
                  }
                }, (material: ExperienceMaterial) => material.id)
              }
              .width('100%')
              .margin({ top: AppTheme.spacing.s12 })
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.s20)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(Color.Transparent)
      }
  }
}
