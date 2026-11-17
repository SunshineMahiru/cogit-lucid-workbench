import { AppTheme } from '../../theme/AppTheme';
import { NoteListItem } from '../../note';
import { NoteCard } from '../../components/NoteCard';
import { SectionCard } from '../../components/SectionCard';

/** The trace stream: the three latest notes, or an invitation to leave the first one. */
@ComponentV2
export struct RecentNotesCard {
  @Param notes: NoteListItem[] = [];
  @Param dataVersion: number = 0;
  @Event onOpenAll: () => void = () => {
  };
  @Event onNoteTap: (id: string) => void = () => {
  };
  @Event onWrite: () => void = () => {
  };

  private visibleNotes(): NoteListItem[] {
    return this.notes.slice(0, 3);
  }

  build() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s10 }) {
        Row() {
          Text('最近的痕迹')
            .fontSize(AppTheme.font.subtitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Blank()
          Text('全部')
            .id('home_notes_all')
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
          Column({ space: AppTheme.spacing.s8 }) {
            ForEach(this.visibleNotes(), (note: NoteListItem) => {
              NoteCard({
                note: note,
                onTap: () => {
                  this.onNoteTap(note.id);
                }
              })
            }, (note: NoteListItem) => `${note.id}_${this.dataVersion}`)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  /** Core surface stays blank when empty: no placeholder, no skeleton, no inferred text. */
  @Builder
  emptyView() {
    Column()
      .id('home_traces_empty')
      .width('100%')
      .height(AppTheme.spacing.s24)
  }
}