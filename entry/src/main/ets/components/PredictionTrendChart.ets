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
import { PredictionMonthPoint } from '../prediction';
import { AppTheme } from '../theme/AppTheme';

const LINE_COLOR = 0xFF185FA5;

/** Monthly hit-rate line; falls back to a hint until two months exist. */
@ComponentV2
export struct PredictionTrendChart {
  @Param points: PredictionMonthPoint[] = [];
  private model: LineChartModel = new LineChartModel();

  aboutToAppear(): void {
    if (this.points.length >= 2) {
      this.setup();
    }
  }

  private setup(): void {
    const values: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
    for (let index = 0; index < this.points.length; index += 1) {
      values.add(new EntryOhos(index, this.points[index].hitRate));
    }
    const dataSet = new LineDataSet(values, '命中率');
    dataSet.setColorByColor(LINE_COLOR);
    dataSet.setCircleColor(LINE_COLOR);
    dataSet.setCircleRadius(3.5);
    dataSet.setDrawCircles(true);
    dataSet.setLineWidth(2);
    dataSet.setDrawValues(false);
    dataSet.setMode(Mode.LINEAR);

    const sets: JArrayList<ILineDataSet> = new JArrayList<ILineDataSet>();
    sets.add(dataSet);
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
      left.setAxisMinimum(0);
      left.setAxisMaximum(100);
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
    }
  }

  build() {
    if (this.points.length >= 2) {
      Column({ space: 4 }) {
        LineChart({ model: this.model })
          .width('100%')
          .height(170)
        Row() {
          ForEach(this.points, (point: PredictionMonthPoint) => {
            Text(point.label)
              .fontSize(10)
              .fontColor(AppTheme.color.textMuted)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }, (point: PredictionMonthPoint) => point.month)
        }
        .width('100%')
        .padding({ left: 36, right: 8 })
      }
      .width('100%')
    } else {
      Text('至少两个结算月份后显示趋势')
        .fontSize(11)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .padding({ top: 16, bottom: 16 })
    }
  }
}
