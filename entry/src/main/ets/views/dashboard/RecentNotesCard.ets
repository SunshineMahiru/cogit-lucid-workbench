import { AppTheme } from '../../theme/AppTheme';
import { curves } from '@kit.ArkUI';
import { NoteListItem } from '../../note';
import { NoteCard } from '../../components/NoteCard';

/** The trace stream: recent notes, or an invitation to leave the first one. */
@ComponentV2
export struct RecentNotesCard {
  @Param notes: NoteListItem[] = [];
  @Param dataVersion: number = 0;
  @Event onOpenAll: () => void = () => {};
  @Event onNoteTap: (id: string) => void = () => {};
  @Event onWrite: () => void = () => {};

  build() {
    Column({ space: 10 }) {
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
    .borderRadius(16)
    .border({ width: 0.5, color: AppTheme.color.border })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
      .animation({ curve: curves.springMotion(0.35, 0.9) }))
  }

  @Builder
  emptyView() {
    Column({ space: 8 }) {
      Text('还没有痕迹')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.textSecondary)
      Text('点上方「此刻」卡片，留下第一句。')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textMuted)
    }
    .id('home_traces_empty')
    .width('100%')
    .padding(AppTheme.spacing.s24)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onWrite();
    })
  }
}