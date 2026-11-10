import { AppTheme } from '../theme/AppTheme';
import { PlanNodeStatus } from '../model/PlanStatus';
import { NodeProgress } from '../plan/PlanInsights';

/** One square per week, newest last; tapping a square opens that node. */
@ComponentV2
export struct PlanRhythmStrip {
  @Param rows: NodeProgress[] = [];
  @Param currentId: string = '';
  @Event onOpen: (nodeId: string) => void = () => {
  };

  build() {
    if (this.rows.length === 0) {
      Text('还没有周节点')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
    } else {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.rows, (row: NodeProgress) => {
            Column({ space: 4 }) {
              Text(`${row.weekIndex}`)
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(row.status === PlanNodeStatus.CLOSED ? Color.White : AppTheme.color.textSecondary)
                .width(36)
                .height(36)
                .textAlign(TextAlign.Center)
                .lineHeight(36)
                .backgroundColor(row.status === PlanNodeStatus.CLOSED ? AppTheme.color.primary : AppTheme.color.tint)
                .borderRadius(8)
                .border({
                  width: row.nodeId === this.currentId ? 2 : 0,
                  color: AppTheme.color.primaryDeep
                })
              Text(row.total > 0 ? `${row.done}/${row.total}` : '—')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
            }
            .onClick(() => {
              this.onOpen(row.nodeId);
            })
          }, (row: NodeProgress) =>
            `${row.nodeId}_${row.status}_${row.done}_${row.total}_${row.nodeId === this.currentId ? 1 : 0}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
  }
}
