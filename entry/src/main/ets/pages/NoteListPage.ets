import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { NoteListView } from '../views/NoteListView';
import { NoteListParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';

/**
 * Note list route: a thin wrapper around the shared NoteListView. The title bar and the create
 * entry stay here; the tab bar no longer links to this page, but the route remains available.
 */
@ComponentV2
export struct NoteListPage {
  @Local navStack: NavPathStack | null = null;
  @Local refreshToken: number = 0;
  @Local initialFilter: string = '';
  private hasShownOnce: boolean = false;

  private openEditor(): void {
    if (this.navStack === null) {
      return;
    }
    this.navStack.pushPathByName(ROUTES.NOTE_EDIT, { templateId: null }, () => {
      this.refreshToken += 1;
    });
  }

  @Builder
  addMenu() {
    Row() {
      Text('＋')
        .fontSize(AppTheme.font.headline)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s16 })
        .accessibilityText('新建速记')
        .onClick(() => {
          this.openEditor();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  listContent() {
    if (this.navStack !== null) {
      NoteListView({
        pathStack: this.navStack,
        refreshToken: this.refreshToken,
        initialFilter: this.initialFilter,
        showFab: true
      })
    }
  }

  build() {
    AppDestination({
      route: 'note_list',
      title: '速记列表',
      content: () => {
        this.listContent();
      },
      menus: () => {
        this.addMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param !== undefined) {
          const params = context.pathInfo.param as NoteListParams;
          this.initialFilter = params.filterType;
        }
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.refreshToken += 1;
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }
}