import {
  BarChart,
  BarChartModel,
  BarData,
  BarDataSet,
  BarEntry,
  HorizontalBarChart,
  HorizontalBarChartModel,
  JArrayList,
  XAxisPosition
} from '@ohos/mpchart';
import { AppTheme } from '../../theme/AppTheme';
import { ChartPoint } from './ChartModels';

/** Vertical or horizontal bars with labels rendered outside the canvas. */
@ComponentV2
export struct SimpleBarChart {
  @Param points: ChartPoint[] = [];
  @Param color: number = 0xFF185FA5;
  @Param maxValue: number = 0;
  @Param horizontal: boolean = false;
  @Param chartHeight: number = 170;
  private verticalModel: BarChartModel = new BarChartModel();
  private horizontalModel: HorizontalBarChartModel = new HorizontalBarChartModel();

  aboutToAppear(): void {
    if (this.points.length > 0) {
      this.setup();
    }
  }

  private ceiling(): number {
    if (this.maxValue > 0) {
      return this.maxValue;
    }
    let max = 1;
    for (const point of this.points) {
      max = Math.max(max, point.value);
    }
    return Math.ceil(max * 1.2);
  }

  private setup(): void {
    const entries: JArrayList<BarEntry> = new JArrayList<BarEntry>();
    for (let index = 0; index < this.points.length; index += 1) {
      entries.add(new BarEntry(index, this.points[index].value));
    }
    const dataSet = new BarDataSet(entries, '');
    dataSet.setColorByColor(this.color);
    dataSet.setDrawValues(false);
    const sets: JArrayList<BarDataSet> = new JArrayList<BarDataSet>();
    sets.add(dataSet);
    const data = new BarData(sets);
    data.setBarWidth(0.55);

    if (this.horizontal) {
      this.horizontalModel.setData(data);
      const left = this.horizontalModel.getAxisLeft();
      if (left) {
        left.setAxisMinimum(0);
        left.setAxisMaximum(this.ceiling());
        left.setLabelCount(3, true);
      }
      const right = this.horizontalModel.getAxisRight();
      if (right) {
        right.setEnabled(false);
      }
      const xAxis = this.horizontalModel.getXAxis();
      if (xAxis) {
        xAxis.setDrawLabels(false);
        xAxis.setDrawGridLines(false);
        xAxis.setGranularity(1);
      }
      const description = this.horizontalModel.getDescription();
      if (description) {
        description.setEnabled(false);
      }
    } else {
      this.verticalModel.setData(data);
      const left = this.verticalModel.getAxisLeft();
      if (left) {
        left.setAxisMinimum(0);
        left.setAxisMaximum(this.ceiling());
        left.setLabelCount(3, true);
        left.setDrawAxisLine(false);
      }
      const right = this.verticalModel.getAxisRight();
      if (right) {
        right.setEnabled(false);
      }
      const xAxis = this.verticalModel.getXAxis();
      if (xAxis) {
        xAxis.setPosition(XAxisPosition.BOTTOM);
        xAxis.setDrawLabels(false);
        xAxis.setDrawGridLines(false);
        xAxis.setGranularity(1);
      }
      const description = this.verticalModel.getDescription();
      if (description) {
        description.setEnabled(false);
      }
    }
  }

  build() {
    if (this.points.length === 0) {
      Text('数据不足，暂不绘图')
        .fontSize(11)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .padding({ top: 16, bottom: 16 })
    } else if (this.horizontal) {
      Column({ space: 6 }) {
        HorizontalBarChart({ model: this.horizontalModel })
          .width('100%')
          .height(this.chartHeight)
        ForEach(this.points, (point: ChartPoint) => {
          Row({ space: 6 }) {
            Text(point.label)
              .fontSize(10)
              .fontColor(AppTheme.color.textMuted)
              .layoutWeight(1)
              .maxLines(1)
            Text(point.note.length > 0 ? point.note : String(point.value))
              .fontSize(10)
              .fontColor(AppTheme.color.text)
          }
          .width('100%')
        }, (point: ChartPoint) => point.label)
      }
      .width('100%')
    } else {
      Column({ space: 4 }) {
        BarChart({ model: this.verticalModel })
          .width('100%')
          .height(this.chartHeight)
        Row() {
          ForEach(this.points, (point: ChartPoint) => {
            Text(point.label)
              .fontSize(9)
              .fontColor(AppTheme.color.textMuted)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .maxLines(1)
          }, (point: ChartPoint) => point.label)
        }
        .width('100%')
        .padding({ left: 30, right: 6 })
      }
      .width('100%')
    }
  }
}
