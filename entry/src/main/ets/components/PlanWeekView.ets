import { AppTheme } from '../theme/AppTheme';
import { DayActivity } from '../plan/PlanInsights';

/** Seven day cells of one week; tapping a cell shows that day's counts below. */
@ComponentV2
export struct PlanWeekView {
  @Param days: DayActivity[] = [];
  @Param previewMode: boolean = false;
  @Local selected: string = '';

  private pick(date: string): void {
    this.selected = this.selected === date ? '' : date;
  }

  private selectedDay(): DayActivity | null {
    for (const day of this.days) {
      if (day.date === this.selected) {
        return day;
      }
    }
    return null;
  }

  @Builder
  dayCell(day: DayActivity) {
    Column({ space: 3 }) {
      Text(day.weekday)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
      Text(day.date.slice(5))
        .fontSize(AppTheme.font.body)
        .fontColor(this.selected === day.date ? Color.White : AppTheme.color.text)
        .width(32)
        .height(24)
        .textAlign(TextAlign.Center)
        .lineHeight(24)
        .backgroundColor(this.selected === day.date ? AppTheme.color.primary : Color.Transparent)
        .borderRadius(6)
      Row({ space: 3 }) {
        Text(day.noteCount > 0 ? `${day.noteCount}` : '·')
          .fontSize(AppTheme.font.caption)
          .fontColor(day.noteCount > 0 ? AppTheme.color.primary : AppTheme.color.textMuted)
        Text(day.hasReading ? '读' : '·')
          .fontSize(AppTheme.font.caption)
          .fontColor(day.hasReading ? AppTheme.color.success : AppTheme.color.textMuted)
      }
    }
    .layoutWeight(1)
    .onClick(() => {
      this.pick(day.date);
    })
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        ForEach(this.days, (day: DayActivity) => {
          this.dayCell(day)
        }, (day: DayActivity) => `${day.date}_${day.noteCount}_${day.hasReading}_${this.selected === day.date ? 1 : 0}`)
      }
      .width('100%')

      if (this.selectedDay() !== null) {
        Text(this.detailText(this.selectedDay()!))
          .fontSize(AppTheme.font.caption)
          .lineHeight(16)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
      } else if (this.previewMode) {
        Text('预览器不读取本地数据库，这里只显示日期；速记与读数请在模拟器里查看')
          .fontSize(AppTheme.font.caption)
          .lineHeight(15)
          .fontColor(AppTheme.color.warning)
          .width('100%')
      } else {
        Text('数字为当天速记条数，「读」表示当天记了读数')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private detailText(day: DayActivity): string {
    const note = day.noteCount > 0 ? `速记 ${day.noteCount} 条` : '没有速记';
    const reading = day.hasReading
      ? `睡眠 ${day.sleepHours} 小时 · 运动 ${day.exerciseCount} 次`
      : '没有读数';
    return `${day.date} · ${note} · ${reading}`;
  }
}
