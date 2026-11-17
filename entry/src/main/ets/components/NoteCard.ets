import { NoteListItem, securityLevelText } from '../note';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';
import { TagChip } from './TagChip';

/** Displays one note in the dashboard trace list or the note list. */
@ComponentV2
export struct NoteCard {
  @Param note: NoteListItem = {
    id: '', title: '', summary: '', type: '', tags: [], level: SecurityLevel.LOCAL_ONLY, timestamp: 0, timeLabel: ''
  };
  @Event onTap: () => void = () => {
  };

  build() {
    Column() {
      SectionCard({ contentPadding: AppTheme.spacing.s12 }) {
        Row({ space: AppTheme.spacing.s10 }) {
          Column({ space: AppTheme.spacing.s4 }) {
            Row({ space: AppTheme.spacing.s6 }) {
              TagChip({
                label: this.note.type,
                tone: AppTheme.color.evBook,
                surface: AppTheme.color.evBookSurface,
                selected: true
              })
              Text(this.note.title)
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            Text(this.note.summary)
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(securityLevelText(this.note.level))
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.note.timeLabel)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .onClick(() => {
      this.onTap();
    })
  }
}