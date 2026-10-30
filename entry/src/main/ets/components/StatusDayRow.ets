import { AppTheme } from '../theme/AppTheme';
import { StatusDayRow as StatusRow } from '../status';

/** One status day: date, sleep bar, exercise/alert counts and an optional note. */
@ComponentV2
export struct StatusDayRow {
  @Param row: StatusRow = {
    id: '',
    date: '',
    sleepHours: 0,
    exerciseCount: 0,
    alertCount: 0,
    note: '',
    flags: []
  };
  @Param compact: boolean = false;

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.row.date)
          .fontSize(12)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        Text(`${this.row.sleepHours} 小时`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.row.flags.length > 0 ? AppTheme.color.danger : AppTheme.color.text)
      }
      .width('100%')

      Progress({ value: this.row.sleepHours, total: 10, type: ProgressType.Linear })
        .height(6)
        .color(this.row.flags.length > 0 ? AppTheme.color.danger : AppTheme.color.primary)
        .backgroundColor(AppTheme.color.track)

      Row({ space: 12 }) {
        Text(`运动 ${this.row.exerciseCount} 次`)
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
        Text(`报警 ${this.row.alertCount} 次`)
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        if (this.row.flags.length > 0) {
          Text(`${this.row.flags.length} 项提示`)
            .fontSize(10)
            .fontColor(AppTheme.color.danger)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(AppTheme.color.dangerSurface)
            .borderRadius(6)
        }
      }
      .width('100%')

      if (!this.compact && this.row.note.length > 0) {
        Text(this.row.note)
          .fontSize(11)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
