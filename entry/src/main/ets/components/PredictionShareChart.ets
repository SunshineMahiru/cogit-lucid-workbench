import {
  JArrayList,
  PieChart,
  PieChartModel,
  PieData,
  PieDataSet,
  PieEntry
} from '@ohos/mpchart';
import { AppTheme } from '../theme/AppTheme';

const HIT_COLOR = 0xFF185FA5;
const MISS_COLOR = 0xFFD3D1C7;

/** Hit versus miss donut with the overall hit rate in the hole. */
@ComponentV2
export struct PredictionShareChart {
  @Param hits: number = 0;
  @Param misses: number = 0;
  @Param hitRate: number = 0;
  private model: PieChartModel = new PieChartModel();

  aboutToAppear(): void {
    if (this.hits + this.misses > 0) {
      this.setup();
    }
  }

  private setup(): void {
    const entries: JArrayList<PieEntry> = new JArrayList<PieEntry>();
    entries.add(new PieEntry(this.hits, '命中', undefined, undefined));
    entries.add(new PieEntry(this.misses, '未命中', undefined, undefined));

    const dataSet = new PieDataSet(entries, '结果');
    dataSet.setColorsByArr([HIT_COLOR, MISS_COLOR]);
    dataSet.setDrawValues(false);

    this.model.setData(new PieData(dataSet));
    this.model.setUsePercentValues(false);
    this.model.setDrawEntryLabels(false);
    this.model.setDrawHoleEnabled(true);
    this.model.setHoleRadius(62);
    this.model.setHoleColor(0xFFFFFFFF);
    this.model.setDrawCenterText(true);
    this.model.setCenterText(`${this.hitRate}%`);
    this.model.setCenterTextSize(16);

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
    if (this.hits + this.misses > 0) {
      Row({ space: 8 }) {
        PieChart({ model: this.model })
          .width(150)
          .height(150)

        Column({ space: 10 }) {
          Row({ space: 6 }) {
            Row()
              .width(10)
              .height(10)
              .backgroundColor(AppTheme.color.primaryDeep)
              .borderRadius(2)
            Text(`命中 ${this.hits} 条`)
              .fontSize(11)
              .fontColor(AppTheme.color.text)
          }
          Row({ space: 6 }) {
            Row()
              .width(10)
              .height(10)
              .backgroundColor('#D3D1C7')
              .borderRadius(2)
            Text(`未命中 ${this.misses} 条`)
              .fontSize(11)
              .fontColor(AppTheme.color.text)
          }
          Text(`共 ${this.hits + this.misses} 条已结算`)
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    } else {
      Text('暂无可统计的结算结果')
        .fontSize(11)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .padding({ top: 16, bottom: 16 })
    }
  }
}
