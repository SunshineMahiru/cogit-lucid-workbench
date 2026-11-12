import { AppTheme } from '../../theme/AppTheme';
import { NoteListItem } from '../../note';
import { NoteCard } from '../../components/NoteCard';

/** Recent notes list with its empty state; the dashboard only supplies data and callbacks. */
@ComponentV2
export struct RecentNotesCard {
  @Param notes: NoteListItem[] = [];
  @Param dataVersion: number = 0;
  @Event onOpenAll: () => void = () => {};
  @Event onNoteTap: (id: string) => void = () => {};

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('最近速记')
          .fontSize(AppTheme.font.subtitle)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Blank()
        Text('全部')
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.textSecondary)
          .onClick(() => {
            this.onOpenAll();
          })
      }
      .width('100%')

      if (this.notes.length === 0) {
        this.emptyView()
      } else {
        List({ space: 8 }) {
          ForEach(this.notes, (note: NoteListItem) => {
            ListItem() {
              NoteCard({
                note: note,
                onTap: () => {
                  this.onNoteTap(note.id);
                }
              })
            }
          }, (note: NoteListItem) => `${note.id}_${this.dataVersion}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  emptyView() {
    Column({ space: 8 }) {
      Text('暂无速记')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.textSecondary)
      Text('点击「速记」模块开始记录')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textMuted)
    }
    .width('100%')
    .padding(AppTheme.spacing.s24)
    .justifyContent(FlexAlign.Center)
  }
}
