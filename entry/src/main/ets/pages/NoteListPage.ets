import { AppTheme } from '../theme/AppTheme';
import { NoteListItem, QuickNoteService } from '../note';
import { NoteDetailParams, NoteEditParams, NoteListParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { NoteCard } from '../components/NoteCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { previewStore } from '../preview/PreviewStore';

const PAGE_SIZE = 20;

/** Note browser with type filters and an entry point to the editor. */
@ComponentV2
export struct NoteListPage {
  @Local service: QuickNoteService | null = null;
  @Local items: NoteListItem[] = [];
  @Local filter: string = '';
  @Local search: string = '';
  @Local isLoading: boolean = true;
  @Local isLoadingMore: boolean = false;
  @Local hasMore: boolean = false;
  @Local isPreview: boolean = false;
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.openService();
  }

  private async openService(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await QuickNoteService.open(hostContext);
      await this.refresh();
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.items = previewStore.listNotes(this.filter);
    this.isLoading = false;
  }

  async refresh(): Promise<void> {
    if (this.isPreview) {
      this.items = previewStore.listNotes(this.filter);
      this.isLoading = false;
      return;
    }
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.items = this.filter.length === 0 ?
        await this.service.listRecentPage(PAGE_SIZE, 0) :
        await this.service.listByTypePage(this.filter, PAGE_SIZE, 0);
      this.hasMore = this.items.length >= PAGE_SIZE;
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.service === null || this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    try {
      const next = this.filter.length === 0 ?
        await this.service.listRecentPage(PAGE_SIZE, this.items.length) :
        await this.service.listByTypePage(this.filter, PAGE_SIZE, this.items.length);
      this.items = this.items.concat(next);
      this.hasMore = next.length >= PAGE_SIZE;
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '加载更多失败，请重试' });
    } finally {
      this.isLoadingMore = false;
    }
  }

  private selectFilter(type: string): void {
    this.filter = type;
    this.refresh();
  }

  private visibleItems(): NoteListItem[] {
    const query = this.search.trim().toLowerCase();
    if (query.length === 0) {
      return this.items;
    }
    return this.items.filter((item: NoteListItem) =>
      item.title.toLowerCase().includes(query) ||
      item.summary.toLowerCase().includes(query) ||
      item.tags.some((tag: string) => tag.toLowerCase().includes(query)));
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
      .fontColor(this.filter === type ? Color.White : AppTheme.color.textStrong)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === type ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(14)
      .onClick(() => {
        this.selectFilter(type);
      })
  }

  @Builder
  addMenu() {
    Row() {
      Text('＋')
        .fontSize(20)
        .fontColor(AppTheme.color.primary)
        .padding({ left: 12, right: 16 })
        .onClick(() => {
          this.openEditor();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column({ space: 10 }) {
          TextInput({ text: this.search, placeholder: '搜索标题、摘要或标签' })
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(12)
            .accessibilityText('搜索速记标题、摘要或标签')
            .onChange((value: string) => {
              this.search = value;
            })

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
                .color(AppTheme.color.primary)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.visibleItems().length === 0) {
            Column() {
              NoteEmptyState({
                title: this.search.trim().length > 0 ? '没有匹配的速记' :
                  (this.filter.length === 0 ? '还没有速记' : '没有匹配的速记'),
                hint: this.search.trim().length > 0 ? '换个关键词试试' :
                  (this.filter.length === 0 ? '点下面的按钮记第一条' : '换个类型看看，或者记一条新的'),
                actionLabel: '记一条',
                dashed: true,
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
              ForEach(this.visibleItems(), (item: NoteListItem) => {
                ListItem() {
                  NoteCard({
                    note: item,
                    onTap: () => {
                      this.openDetail(item.id);
                    }
                  })
                }
              }, (item: NoteListItem) => item.id)
              if (this.hasMore) {
                ListItem() {
                  Text(this.isLoadingMore ? '加载中…' : '加载更多')
                    .fontSize(12)
                    .fontColor(AppTheme.color.primary)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 10, bottom: 10 })
                    .onClick(() => {
                      this.loadMore();
                    })
                    .accessibilityText(this.isLoadingMore ? '正在加载更多速记' : '加载更多速记')
                }
              }
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
          .backgroundColor(AppTheme.color.primary)
          .borderRadius(24)
          .margin({ right: 16, bottom: 24 })
          .onClick(() => {
            this.openEditor();
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title('速记列表')
    .menus(this.addMenu)
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
