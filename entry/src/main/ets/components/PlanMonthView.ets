import { AppTheme } from '../theme/AppTheme';
import { NodeProgress } from '../plan/PlanInsights';

/** Month view: one row per week, with month switching handled by the host page. */
@ComponentV2
export struct PlanMonthView {
  @Param rows: NodeProgress[] = [];
  @Param label: string = '';
  @Event onPrev: () => void = () => {
  };
  @Event onNext: () => void = () => {
  };
  @Event onOpen: (nodeId: string) => void = () => {
  };

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('‹')
          .fontSize(AppTheme.font.title)
          .fontColor(AppTheme.color.primary)
          .width(28)
          .height(24)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.onPrev();
          })
        Text(this.label)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('›')
          .fontSize(AppTheme.font.title)
          .fontColor(AppTheme.color.primary)
          .width(28)
          .height(24)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.onNext();
          })
      }
      .width('100%')

      if (this.rows.length === 0) {
        Text('这个月没有周节点')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      } else {
        ForEach(this.rows, (row: NodeProgress) => {
          Row({ space: 8 }) {
            Text(`第 ${row.weekIndex} 周`)
              .fontSize(AppTheme.font.body)
              .fontColor(AppTheme.color.text)
              .width(60)
            Text(`${row.startDate.slice(5)} – ${row.endDate.slice(5)}`)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .layoutWeight(1)
            Text(row.openCarried > 0 ? `延续 ${row.openCarried}` : '')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.warning)
            Text(`${row.done}/${row.total}`)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textSecondary)
          }
          .width('100%')
          .padding({ top: 5, bottom: 5 })
          .onClick(() => {
            this.onOpen(row.nodeId);
          })
        }, (row: NodeProgress) => `${row.nodeId}_${row.done}_${row.total}_${row.openCarried}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
