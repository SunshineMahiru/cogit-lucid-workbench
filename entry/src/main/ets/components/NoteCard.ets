import { NoteListItem, securityLevelText } from '../note';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppTheme } from '../theme/AppTheme';

/** Displays one recent note in the dashboard list. */
@ComponentV2
export struct NoteCard {
  @Param note: NoteListItem = {
    id: '', title: '', summary: '', type: '', tags: [], level: SecurityLevel.LOCAL_ONLY, timestamp: 0, timeLabel: ''
  };
  @Event onTap: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.note.type)
            .fontSize(10)
            .fontColor(AppTheme.color.primary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(8)
          Text(this.note.title)
            .fontSize(14)
            .fontColor(AppTheme.color.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        Text(this.note.summary)
          .fontSize(12)
          .fontColor(AppTheme.color.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.note.type} · ${securityLevelText(this.note.level)}`)
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.note.timeLabel)
        .fontSize(12)
        .fontColor(AppTheme.color.textMuted)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(10)
    .onClick(() => {
      this.onTap();
    })
  }
}