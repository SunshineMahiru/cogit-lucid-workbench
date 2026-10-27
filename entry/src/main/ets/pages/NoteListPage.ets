import { DEFAULT_NOTE_LIST_LIMIT, NoteListItem, QuickNoteService } from '../note';
import { NoteDetailParams, NoteEditParams, NoteListParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { NoteCard } from '../components/NoteCard';
import { NoteEmptyState } from '../components/NoteEmptyState';

/** Note browser with type filters and an entry point to the editor. */
@ComponentV2
export struct NoteListPage {
  @Local service: QuickNoteService | null = null;
  @Local items: NoteListItem[] = [];
  @Local filter: string = '';
  @Local isLoading: boolean = true;
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.openService();
  }

  private async openService(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isLoading = false;
      return;
    }
    try {
      this.service = await QuickNoteService.open(hostContext);
      await this.refresh();
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，请重试' });
    }
  }

  async refresh(): Promise<void> {
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.items = this.filter.length === 0 ?
        await this.service.listRecent(DEFAULT_NOTE_LIST_LIMIT) :
        await this.service.listByType(this.filter, DEFAULT_NOTE_LIST_LIMIT);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private selectFilter(type: string): void {
    this.filter = type;
    this.refresh();
  }

  private openEditor(): void {
    if (this.navStack === null) {
      return;
    }
    const params: NoteEditParams = { templateId: null };
    this.navStack.pushPathByName(ROUTES.NOTE_EDIT, params);
  }

  private openDetail(noteId: string): void {
    if (this.navStack === null) {
      return;
    }
    const params: NoteDetailParams = { noteId: noteId };
    this.navStack.pushPathByName(ROUTES.NOTE_DETAIL, params);
  }

  @Builder
  filterChip(label: string, type: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filter === type ? Color.White : '#444441')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === type ? '#4A6FA5' : '#F1EFE8')
      .borderRadius(14)
      .onClick(() => {
        this.selectFilter(type);
      })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column({ space: 10 }) {
          Scroll() {
            Row({ space: 8 }) {
              this.filterChip('全部', '')
              this.filterChip('决策', '决策')
              this.filterChip('人际', '人际')
              this.filterChip('情绪', '情绪')
              this.filterChip('身体', '身体')
              this.filterChip('自由', '速记')
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(32)
                .height(32)
                .color('#4A6FA5')
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.items.length === 0) {
            Column() {
              NoteEmptyState({
                title: this.filter.length === 0 ? '还没有速记' : '没有匹配的速记',
                hint: this.filter.length === 0 ? '点下面的按钮记第一条' : '换个类型看看，或者记一条新的',
                actionLabel: '记一条',
                onAction: () => {
                  this.openEditor();
                }
              })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 8 }) {
              ForEach(this.items, (item: NoteListItem) => {
                ListItem() {
                  NoteCard({
                    note: item,
                    onTap: () => {
                      this.openDetail(item.id);
                    }
                  })
                }
              }, (item: NoteListItem) => item.id)
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 80 })

        Text('＋')
          .fontSize(22)
          .fontColor(Color.White)
          .width(48)
          .height(48)
          .lineHeight(48)
          .textAlign(TextAlign.Center)
          .backgroundColor('#4A6FA5')
          .borderRadius(24)
          .margin({ right: 16, bottom: 24 })
          .onClick(() => {
            this.openEditor();
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F6F8')
    }
    .title('速记')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param !== undefined) {
        const params = context.pathInfo.param as NoteListParams;
        this.filter = params.filterType;
        if (this.service !== null) {
          this.refresh();
        }
      }
    })
    .onShown(() => {
      if (this.hasShownOnce) {
        this.refresh();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
