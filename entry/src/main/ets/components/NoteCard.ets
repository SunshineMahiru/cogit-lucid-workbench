import { NoteListItem } from '../note/NoteListItem';

/** Displays one recent note in the dashboard list. */
@ComponentV2
export struct NoteCard {
  @Param note: NoteListItem = {
    id: '', title: '', summary: '', type: '', tags: [], timestamp: 0, timeLabel: ''
  };

  build() {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(this.note.title)
          .fontSize(14)
          .fontColor('#1F2329')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.note.summary)
          .fontSize(12)
          .fontColor('#8A8F99')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.note.timeLabel)
        .fontSize(12)
        .fontColor('#B0B4BE')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(10)
  }
}