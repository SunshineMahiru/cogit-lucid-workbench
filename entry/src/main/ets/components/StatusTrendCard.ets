import { StatusDayRow } from '../status/StatusListItem';
import { AppTheme } from '../theme/AppTheme';

/** Seven-day sleep trend rendered with simple bars, no chart dependency. */
@ComponentV2
export struct StatusTrendCard {
  @Param rows: StatusDayRow[] = [];

  private chronological(): StatusDayRow[] {
    return this.rows.slice().reverse();
  }

  private barHeight(sleepHours: number): number {
    return Math.max(6, Math.min(72, Math.round(sleepHours * 9)));
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('睡眠趋势')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        Text('最近 7 次')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach(this.chronological(), (row: StatusDayRow) => {
          Column({ space: 4 }) {
            Blank()
            Column()
              .width(16)
              .height(this.barHeight(row.sleepHours))
              .backgroundColor(row.sleepHours < 6.5 ? AppTheme.color.warning : AppTheme.color.primary)
              .borderRadius(AppTheme.radius.xs)
            Text(row.date.length >= 5 ? row.date.slice(5) : row.date)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
          }
          .layoutWeight(1)
          .height(98)
          .alignItems(HorizontalAlign.Center)
          .accessibilityText(`${row.date} 睡眠 ${row.sleepHours} 小时`)
        }, (row: StatusDayRow) => row.id)
      }
      .width('100%')
      .height(100)

      Row({ space: 12 }) {
        Text('低于 6.5 小时')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.warning)
        Text('其余记录')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.primary)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 12, left: 14, right: 14, bottom: 12 })
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }
}
