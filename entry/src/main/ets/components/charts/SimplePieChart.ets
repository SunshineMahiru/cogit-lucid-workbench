import { JArrayList, PieChart, PieChartModel, PieData, PieDataSet, PieEntry } from '@ohos/mpchart';
import { AppTheme } from '../../theme/AppTheme';
import { ChartSlice } from './ChartModels';

/** Donut with a center label and a text legend. */
@ComponentV2
export struct SimplePieChart {
  @Param slices: ChartSlice[] = [];
  @Param centerText: string = '';
  @Param diameter: number = 150;
  private model: PieChartModel = new PieChartModel();

  aboutToAppear(): void {
    if (this.total() > 0) {
      this.setup();
    }
  }

  /** Re-applies the slices and the centre label when either input changes. */
  @Monitor('slices', 'centerText')
  onSlicesChange(): void {
    if (this.total() > 0) {
      this.setup();
    }
  }

  private total(): number {
    let sum = 0;
    for (const slice of this.slices) {
      sum += slice.value;
    }
    return sum;
  }

  private setup(): void {
    const entries: JArrayList<PieEntry> = new JArrayList<PieEntry>();
    const colors: number[] = [];
    for (const slice of this.slices) {
      if (slice.value > 0) {
        entries.add(new PieEntry(slice.value, slice.label, undefined, undefined));
        colors.push(slice.color);
      }
    }
    const dataSet = new PieDataSet(entries, '');
    dataSet.setColorsByArr(colors);
    dataSet.setDrawValues(false);
    this.model.setData(new PieData(dataSet));
    this.model.setUsePercentValues(false);
    this.model.setDrawEntryLabels(false);
    this.model.setDrawHoleEnabled(true);
    this.model.setHoleRadius(60);
    this.model.setHoleColor(0xFFFFFFFF);
    this.model.setDrawCenterText(this.centerText.length > 0);
    this.model.setCenterText(this.centerText);
    this.model.setCenterTextSize(15);
    const description = this.model.getDescription();
    if (description) {
      description.setEnabled(false);
    }
    const legend = this.model.getLegend();
    if (legend) {
      legend.setEnabled(false);
    }
  }

  build() {
    if (this.total() <= 0) {
      Text('数据不足，暂不绘图')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .padding({ top: 16, bottom: 16 })
    } else {
      Row({ space: 12 }) {
        PieChart({ model: this.model })
          .width(this.diameter)
          .height(this.diameter)
        Column({ space: 8 }) {
          ForEach(this.slices, (slice: ChartSlice) => {
            Row({ space: 6 }) {
              Row().width(9).height(9).backgroundColor(slice.color).borderRadius(2)
              Text(`${slice.label} ${slice.value}`)
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.textMuted)
            }
            .width('100%')
          }, (slice: ChartSlice) => slice.label)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }
}
