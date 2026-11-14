import { AppTheme } from '../theme/AppTheme';
import { StatusDayRow as StatusRow } from '../status';
import { capacityText } from '../model/CapacityJudgment';
import { isReadingUnknown } from '../analysis/status/ReadingPresence';

/** One status day: date, sleep bar, reading counts, capacity judgment and body evidence. */
@ComponentV2
export struct StatusDayRow {
  @Param row: StatusRow = {
    id: '',
    date: '',
    sleepHours: 0,
    exerciseCount: 0,
    alertCount: 0,
    note: '',
    bodySignals: '',
    functionState: '',
    emotion: '',
    environment: '',
    capacity: '',
    functionGain: '',
    costPaid: '',
    unknownReadings: '',
    correctedAt: 0,
    revisions: [],
    flags: []
  };
  @Param compact: boolean = false;

  private sleepText(): string {
    return isReadingUnknown(this.row.unknownReadings, 'sleep') ? '睡眠未记录' : `${this.row.sleepHours} 小时`;
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.row.date)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        if (this.row.capacity.length > 0) {
          Text(capacityText(this.row.capacity))
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.primaryDeep)
            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(AppTheme.radius.sm)
            .margin({ right: AppTheme.spacing.s6 })
        }
        Text(this.sleepText())
          .fontSize(AppTheme.font.bodyStrong)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.row.flags.length > 0 ? AppTheme.color.danger :
            (isReadingUnknown(this.row.unknownReadings, 'sleep') ? AppTheme.color.textMuted : AppTheme.color.text))
      }
      .width('100%')

      if (!isReadingUnknown(this.row.unknownReadings, 'sleep')) {
        Progress({ value: this.row.sleepHours, total: 10, type: ProgressType.Linear })
          .height(6)
          .color(this.row.flags.length > 0 ? AppTheme.color.danger : AppTheme.color.primary)
          .backgroundColor(AppTheme.color.track)
      }

      Row({ space: 12 }) {
        Text(isReadingUnknown(this.row.unknownReadings, 'exercise') ? '运动未记录' : `运动 ${this.row.exerciseCount} 次`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
        Text(isReadingUnknown(this.row.unknownReadings, 'alert') ? '报警未记录' : `报警 ${this.row.alertCount} 次`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        if (this.row.flags.length > 0) {
          Text(`${this.row.flags.length} 项观察提示`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.danger)
            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
            .backgroundColor(AppTheme.color.dangerSurface)
            .borderRadius(AppTheme.radius.sm)
        }
      }
      .width('100%')

      if (this.row.correctedAt > 0) {
        Text('这一天改过读数，原读数保留在历史里')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }

      if (!this.compact && this.row.bodySignals.length > 0) {
        Text(`身体信号：${this.row.bodySignals}`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (!this.compact && this.row.note.length > 0) {
        Text(this.row.note)
          .fontSize(AppTheme.font.body)
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
