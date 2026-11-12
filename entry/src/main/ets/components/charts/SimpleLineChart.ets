import {
  EntryOhos,
  ILineDataSet,
  JArrayList,
  LineChart,
  LineChartModel,
  LineData,
  LineDataSet,
  Mode,
  XAxisPosition
} from '@ohos/mpchart';
import { AppTheme } from '../../theme/AppTheme';
import { ChartPoint, ChartSeries } from './ChartModels';

/** One or two line series sharing an axis; x labels come from the first series. */
@ComponentV2
export struct SimpleLineChart {
  @Param series: ChartSeries[] = [];
  @Param minValue: number = 0;
  @Param maxValue: number = 100;
  @Param chartHeight: number = 170;
  @Param showXLabels: boolean = true;
  @Param xMin: number = 0;
  @Param xMax: number = 0;
  private model: LineChartModel = new LineChartModel();

  aboutToAppear(): void {
    if (this.pointCount() >= 2) {
      this.setup();
    }
  }

  /** Re-applies the series when the parent swaps months or refreshes the payload. */
  @Monitor('series')
  onSeriesChange(): void {
    if (this.pointCount() >= 2) {
      this.setup();
    }
  }

  private pointCount(): number {
    let count = 0;
    for (const item of this.series) {
      count = Math.max(count, item.points.length);
    }
    return count;
  }

  private setup(): void {
    const sets: JArrayList<ILineDataSet> = new JArrayList<ILineDataSet>();
    for (const item of this.series) {
      const values: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
      for (let index = 0; index < item.points.length; index += 1) {
        const point = item.points[index];
        values.add(new EntryOhos(point.x !== undefined ? point.x : index, point.value));
      }
      const dataSet = new LineDataSet(values, item.name);
      dataSet.setColorByColor(item.color);
      dataSet.setCircleColor(item.color);
      dataSet.setCircleRadius(3);
      dataSet.setDrawCircles(true);
      dataSet.setLineWidth(2);
      dataSet.setDrawValues(false);
      dataSet.setMode(Mode.LINEAR);
      sets.add(dataSet);
    }
    this.model.setData(new LineData(sets));
    this.model.setDrawGridBackground(false);

    const description = this.model.getDescription();
    if (description) {
      description.setEnabled(false);
    }
    const legend = this.model.getLegend();
    if (legend) {
      legend.setEnabled(false);
    }
    const left = this.model.getAxisLeft();
    if (left) {
      left.setAxisMinimum(this.minValue);
      left.setAxisMaximum(this.maxValue);
      left.setLabelCount(5, true);
      left.setDrawAxisLine(false);
    }
    const right = this.model.getAxisRight();
    if (right) {
      right.setEnabled(false);
    }
    const xAxis = this.model.getXAxis();
    if (xAxis) {
      xAxis.setPosition(XAxisPosition.BOTTOM);
      xAxis.setDrawLabels(false);
      xAxis.setDrawGridLines(false);
      xAxis.setGranularity(1);
      if (this.xMax > 0) {
        xAxis.setAxisMinimum(this.xMin);
        xAxis.setAxisMaximum(this.xMax);
      }
    }
  }

  build() {
    if (this.pointCount() >= 2) {
      Column({ space: 4 }) {
        LineChart({ model: this.model })
          .width('100%')
          .height(this.chartHeight)
        if (this.series.length > 1) {
          Row({ space: 12 }) {
            ForEach(this.series, (item: ChartSeries) => {
              Row({ space: 4 }) {
                Row().width(8).height(8).backgroundColor(item.color).borderRadius(0)
                Text(item.name).fontSize(AppTheme.font.caption).fontColor(AppTheme.color.textMuted)
              }
            }, (item: ChartSeries) => item.name)
          }
          .width('100%')
        }
        if (this.showXLabels) {
          Row() {
            ForEach(this.series.length > 0 ? this.series[0].points : [], (point: ChartPoint) => {
              Text(point.label)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .maxLines(1)
            }, (point: ChartPoint) => point.label)
          }
          .width('100%')
          .padding({ left: 34, right: 8 })
        }
      }
      .width('100%')
    } else {
      Text('数据不足，暂不绘图')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .padding({ top: 16, bottom: 16 })
    }
  }
}
