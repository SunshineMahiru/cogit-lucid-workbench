import { AppTheme } from '../../theme/AppTheme';
import { SectionCard } from '../../components/SectionCard';
import { ChartPoint } from '../../components/charts/ChartModels';
import { SimpleBarChart } from '../../components/charts/SimpleBarChart';

/** Link counts by module; the page turns link rows into chart points. */
@ComponentV2
export struct LinkCompositionCard {
  @Param points: ChartPoint[] = [];
  @Param total: number = 0;

  build() {
    SectionCard() {
      Column({ space: 8 }) {
        Row() {
          Text('关联构成')
            .fontSize(12)
            .fontColor(AppTheme.color.textSecondary)
          Blank()
          Text(`共 ${this.total} 条`)
            .fontSize(9)
            .fontColor(AppTheme.color.textMuted)
        }
        .width('100%')

        if (this.total === 0) {
          Text('还没有关联记录；在周节点里挑几条挂上来。')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        } else {
          SimpleBarChart({
            points: this.points,
            color: 0xFF185FA5,
            maxValue: 0,
            horizontal: true,
            chartHeight: 150
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
