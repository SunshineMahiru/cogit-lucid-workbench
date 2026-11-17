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
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(14)
          .fontColor([AppTheme.color.primary])
          .rotate({ angle: 180 })
          .width(28)
          .height(24)
          .onClick(() => {
            this.onPrev();
          })
        Text(this.label)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(14)
          .fontColor([AppTheme.color.primary])
          .width(28)
          .height(24)
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
          Row({ space: AppTheme.spacing.s10 }) {
            Column({ space: 2 }) {
              Text(`第 ${row.weekIndex} 周`)
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.text)
                .width('100%')
              Text(`${row.startDate.slice(5)} – ${row.endDate.slice(5)}`)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            }
            .width(88)
            .alignItems(HorizontalAlign.Start)

            Progress({
              value: row.done,
              total: row.total > 0 ? row.total : 1,
              type: ProgressType.Linear
            })
              .height(6)
              .layoutWeight(1)
              .color(AppTheme.color.evPractice)
              .backgroundColor(AppTheme.color.track)

            Text(`${row.done}/${row.total}`)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textSecondary)
              .width(38)
              .textAlign(TextAlign.End)

            if (row.openCarried > 0) {
              Text(`延续 ${row.openCarried}`)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.warning)
                .padding({
                  left: AppTheme.spacing.s6,
                  right: AppTheme.spacing.s6,
                  top: 2,
                  bottom: 2
                })
                .backgroundColor(AppTheme.color.warningSurface)
                .borderRadius(AppTheme.radius.sm)
            }
          }
          .width('100%')
          .padding({ top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
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
