import { AppTheme } from '../theme/AppTheme';
import { DeadlineProgress } from '../plan/PlanInsights';

/** Settlement countdown; falls back to the elapsed weeks when no end date is set. */
@ComponentV2
export struct PlanDeadlineCard {
  @Param progress: DeadlineProgress = {
    hasTarget: false, percent: 0, remainingDays: 0, totalDays: 0, overdue: false
  };
  @Param weeksElapsed: number = 0;

  build() {
    Row({ space: 14 }) {
      if (this.progress.hasTarget) {
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: this.progress.percent, total: 100, type: ProgressType.Ring })
            .width(66)
            .height(66)
            .color(this.progress.overdue ? AppTheme.color.danger : AppTheme.color.primary)
            .backgroundColor(AppTheme.color.track)
            .style({ strokeWidth: 7 })
          Text(`${this.progress.percent}%`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
        }
        .width(66)
        .height(66)
      }

      Column({ space: 3 }) {
        if (this.progress.hasTarget) {
          Text(this.progress.overdue
            ? `已超期 ${Math.abs(this.progress.remainingDays)} 天`
            : `剩余 ${this.progress.remainingDays} 天`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.progress.overdue ? AppTheme.color.danger : AppTheme.color.text)
            .width('100%')
          Text(`已用 ${this.progress.percent}% · 总 ${this.progress.totalDays} 天`)
            .fontSize(10)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')
        } else {
          Text(`已推进 ${this.weeksElapsed} 周`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
            .width('100%')
          Text('没有设结束日，进度按周数计；在编辑目标里可以补上')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }
}
