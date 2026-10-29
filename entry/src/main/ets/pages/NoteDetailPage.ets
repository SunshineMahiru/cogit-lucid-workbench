import { NoteDetail, QuickNoteService, securityLevelText } from '../note';
import { NoteDetailParams } from '../navigation/RouteParams';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { previewStore } from '../preview/PreviewStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

/** Read-only view of one stored note. */
@ComponentV2
export struct NoteDetailPage {
  @Local detail: NoteDetail | null = null;
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local isPreview: boolean = false;
  private navStack: NavPathStack | null = null;

  private async load(noteId: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview(noteId);
      return;
    }
    try {
      const service = await QuickNoteService.open(hostContext);
      this.detail = await service.findNote(noteId);
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
      message: '删除后无法从应用内恢复。',
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
      this.getUIContext().getPromptAction().showToast({ message: '速记已删除' });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '删除失败，请重试' });
    }
  }

  @Builder
  deleteMenu() {
    Text('删除')
      .fontSize(14)
      .fontColor('#A32D2D')
      .padding({ left: 12, right: 16 })
      .onClick(() => {
        this.confirmDelete();
      })
  }

  build() {
    NavDestination() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color('#4A6FA5')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F5F6F8')
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
        .backgroundColor('#F5F6F8')
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text(this.detail.type)
                .fontSize(10)
                .fontColor('#4A6FA5')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('#E8EFF7')
                .borderRadius(8)
              Text(this.detail.timeLabel)
                .fontSize(11)
                .fontColor('#B0B4BE')
              Blank()
              Text(securityLevelText(this.detail.level))
                .fontSize(11)
                .fontColor('#8A8F99')
            }
            .width('100%')

            Text(this.detail.title)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F2329')
              .width('100%')

            if (this.detail.tags.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.detail.tags, (tag: string) => {
                  Text(tag)
                    .fontSize(11)
                    .fontColor('#185FA5')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor('#E8EFF7')
                    .borderRadius(10)
                    .margin({ right: 6, bottom: 6 })
                }, (tag: string) => tag)
              }
              .width('100%')
            }

            Text(this.detail.content)
              .fontSize(14)
              .lineHeight(24)
              .fontColor('#1F2329')
              .width('100%')
          }
          .width('100%')
          .padding(20)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor('#F5F6F8')
      }
    }
    .title('速记详情')
    .menus(this.deleteMenu)
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param === undefined) {
        this.isLoading = false;
        this.missing = true;
        return;
      }
      const params = context.pathInfo.param as NoteDetailParams;
      this.load(params.noteId);
    })
  }
}
