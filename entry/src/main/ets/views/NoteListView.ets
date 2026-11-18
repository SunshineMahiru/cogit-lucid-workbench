import { AppTheme } from '../theme/AppTheme';
import { NoteListItem, QuickNoteService } from '../note';
import { NoteDetailParams, NoteEditParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { NoteCard } from '../components/NoteCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { previewStore } from '../preview/PreviewStore';

const PAGE_SIZE = 20;

/**
 * Note browser body shared by the note list page and the logs tab: search, type chips, paging and
 * the four empty states. The host supplies the stack and bumps refreshToken whenever the list has
 * to be reloaded.
 */
@ComponentV2
export struct NoteListView {
  @Require @Param pathStack: NavPathStack;
  /** Host-owned counter; every change reloads the first page. */
  @Param refreshToken: number = 0;
  /** Type selected when the page opens; an empty string shows every note. */
  @Param initialFilter: string = '';
  /** The logs tab keeps the create entry in its header, so the floating button is optional. */
  @Param showFab: boolean = true;
  @Local service: QuickNoteService | null = null;
  @Local items: NoteListItem[] = [];
  @Local filter: string = '';
  @Local search: string = '';
  @Local isLoading: boolean = true;
  @Local isLoadingMore: boolean = false;
  @Local hasMore: boolean = false;
  @Local isPreview: boolean = false;
  @Local listVersion: number = 0;
  private loadToken: number = 0;

  aboutToAppear(): void {
    this.filter = this.initialFilter;
    this.openService();
  }

  @Monitor('refreshToken')
  onRefreshToken(): void {
    this.refresh();
  }

  @Monitor('initialFilter')
  onInitialFilterChanged(): void {
    this.filter = this.initialFilter;
    this.refresh();
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
    this.listVersion += 1;
    this.isLoading = false;
  }

  async refresh(): Promise<void> {
    if (this.isPreview) {
      this.items = previewStore.listNotes(this.filter);
      this.listVersion += 1;
      this.isLoading = false;
      return;
    }
    if (this.service === null) {
      return;
    }
    const token = ++this.loadToken;
    this.isLoading = true;
    try {
      const rows: NoteListItem[] = this.filter.length === 0 ?
        await this.service.listRecentPage(PAGE_SIZE, 0) :
        await this.service.listByTypePage(this.filter, PAGE_SIZE, 0);
      if (token !== this.loadToken) {
        return;
      }
      this.items = rows;
      this.listVersion += 1;
      this.hasMore = rows.length === PAGE_SIZE;
    } catch (error) {
      if (token !== this.loadToken) {
        return;
      }
      this.getUIContext().getPromptAction().showToast({ message: '加载失败，请重试' });
    } finally {
      if (token === this.loadToken) {
        this.isLoading = false;
      }
    }
  }

  private async loadMore(): Promise<void> {
    if (this.service === null || this.isLoadingMore || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    try {
      const next: NoteListItem[] = this.filter.length === 0 ?
        await this.service.listRecentPage(PAGE_SIZE, this.items.length) :
        await this.service.listByTypePage(this.filter, PAGE_SIZE, this.items.length);
      this.items = this.items.concat(next);
      this.listVersion += 1;
      this.hasMore = next.length === PAGE_SIZE;
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
    const params: NoteEditParams = { templateId: null };
    this.pathStack.pushPathByName(ROUTES.NOTE_EDIT, params, () => {
      this.refresh();
    });
  }

  private openDetail(noteId: string): void {
    const params: NoteDetailParams = { noteId: noteId };
    this.pathStack.pushPathByName(ROUTES.NOTE_DETAIL, params, () => {
      this.refresh();
    });
  }

  @Builder
  filterChip(label: string, type: string) {
    Text(label)
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.filter === type ? Color.White : AppTheme.color.textStrong)
      .padding({
        left: AppTheme.spacing.s12,
        right: AppTheme.spacing.s12,
        top: AppTheme.spacing.s6,
        bottom: AppTheme.spacing.s6
      })
      .backgroundColor(this.filter === type ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.selectFilter(type);
      })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 10 }) {
        TextInput({ text: this.search, placeholder: '搜索标题、摘要或标签' })
          .backgroundColor(AppTheme.color.surface)
          .borderRadius(AppTheme.radius.md)
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
                (this.filter.length === 0 ? '直接在上方记第一条' : '换个类型看看，或者记一条新的'),
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
            }, (item: NoteListItem) => `${item.id}_${this.listVersion}`)
            if (this.hasMore) {
              ListItem() {
                Text(this.isLoadingMore ? '加载中…' : '加载更多')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.primary)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
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
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .padding({
        left: AppTheme.spacing.s16,
        right: AppTheme.spacing.s16,
        top: AppTheme.spacing.s12,
        // The 80 vp bottom inset reserves room for the floating action button, so it stays off the scale.
        bottom: this.showFab ? 80 : AppTheme.spacing.s12
      })

      if (this.showFab) {
        Text('＋')
          .fontSize(AppTheme.font.headline)
          .fontColor(Color.White)
          .width(48)
          .height(48)
          .lineHeight(48)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.color.primary)
          .borderRadius(AppTheme.radius.xl)
          .margin({ right: AppTheme.spacing.s16, bottom: AppTheme.spacing.s24 })
          .accessibilityText('新建速记')
          .onClick(() => {
            this.openEditor();
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}