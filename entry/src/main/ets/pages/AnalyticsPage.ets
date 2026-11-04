import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { AppTheme } from '../theme/AppTheme';
import { SimpleLineChart } from '../components/charts/SimpleLineChart';
import { SimpleBarChart } from '../components/charts/SimpleBarChart';
import { SimplePieChart } from '../components/charts/SimplePieChart';
import { HeatmapGrid } from '../components/charts/HeatmapGrid';
import { ChartSection } from '../components/charts/ChartSection';
import { ChartPoint, ChartSeries, ChartSlice, HeatCell, HeatmapData } from '../components/charts/ChartModels';
import { RemoteStatsRepository, StatsRange } from '../network/RemoteStatsRepository';
import { RemoteStats } from '../network/RemoteStats';

const HIT_COLOR = 0xFF185FA5;
const MISS_COLOR = 0xFFC0563F;
const VOID_COLOR = 0xFF8C8A80;
const LINE_COLOR = 0xFF2E6F9E;
const REF_COLOR = 0xFFB7B3A6;

/** Remote analytics dashboard: ten charts over one payload, with range switch and retry. */
@ComponentV2
export struct AnalyticsPage {
  @Local stats: RemoteStats | null = null;
  @Local isLoading: boolean = true;
  @Local errorText: string = '';
  @Local range: StatsRange = '6m';
  private repository: RemoteStatsRepository = new RemoteStatsRepository();

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.isLoading = true;
    this.errorText = '';
    try {
      this.stats = await this.repository.fetch(this.range);
    } catch (error) {
      this.errorText = error instanceof Error ? error.message : '图表数据加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private switchRange(next: StatsRange): void {
    if (this.range === next) {
      return;
    }
    this.range = next;
    this.load();
  }

  private monthSeries(): ChartSeries[] {
    if (this.stats === null) {
      return [];
    }
    const points: ChartPoint[] = [];
    for (const month of this.stats.months) {
      points.push({ label: month.label.slice(5), value: Math.round(month.hitRate * 100), note: `${month.settled} 条` });
    }
    const series: ChartSeries[] = [{ name: '命中率', color: LINE_COLOR, points: points }];
    return series;
  }

  private calibrationSeries(): ChartSeries[] {
    if (this.stats === null) {
      return [];
    }
    const perfect: ChartPoint[] = [
      { label: '0', value: 0, note: '' },
      { label: '100', value: 100, note: '' }
    ];
    const actual: ChartPoint[] = [];
    for (const bucket of this.stats.calibration) {
      actual.push({
        label: bucket.bucket,
        value: Math.round(bucket.actual * 100),
        note: `${bucket.samples} 条`
      });
    }
    return [
      { name: '理想校准', color: REF_COLOR, points: perfect },
      { name: '实际命中', color: HIT_COLOR, points: actual }
    ];
  }

  private confidencePoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      for (const bucket of this.stats.confidence) {
        points.push({ label: bucket.bucket, value: bucket.count, note: `${bucket.count} 条` });
      }
    }
    return points;
  }

  private horizonPoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      for (const bucket of this.stats.horizon) {
        points.push({
          label: bucket.label,
          value: Math.round(bucket.hitRate * 100),
          note: `${bucket.samples} 条`
        });
      }
    }
    return points;
  }

  private sleepPoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      const readings = this.stats.readings.slice(-14);
      for (const reading of readings) {
        points.push({ label: reading.date.slice(5), value: reading.sleep, note: `${reading.sleep} 小时` });
      }
    }
    return points;
  }

  private sleepBucketPoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      for (const bucket of this.stats.sleepBuckets) {
        points.push({
          label: bucket.label,
          value: Math.round(bucket.hitRate * 100),
          note: `${bucket.samples} 条`
        });
      }
    }
    return points;
  }

  private interactionPoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      for (const item of this.stats.interactions) {
        points.push({ label: item.alias, value: item.count, note: `${item.count} 次` });
      }
    }
    return points;
  }

  private outcomeSlices(): ChartSlice[] {
    if (this.stats === null) {
      return [];
    }
    return [
      { label: '命中', value: this.stats.outcomes.hit, color: HIT_COLOR },
      { label: '未命中', value: this.stats.outcomes.miss, color: MISS_COLOR },
      { label: '作废', value: this.stats.outcomes.void, color: VOID_COLOR },
      { label: '被替代', value: this.stats.outcomes.superseded, color: 0xFFD3D1C7 }
    ];
  }

  private outcomeCenter(): string {
    if (this.stats === null) {
      return '';
    }
    const total = this.stats.outcomes.hit + this.stats.outcomes.miss +
      this.stats.outcomes.void + this.stats.outcomes.superseded;
    if (total === 0) {
      return '';
    }
    return `${Math.round(this.stats.outcomes.hit / total * 100)}%`;
  }

  private coverageHeatmap(): HeatmapData {
    const rows: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    const columns: string[] = [];
    for (let index = 0; index < 12; index += 1) {
      columns.push(`${index + 1}`);
    }
    const cells: HeatCell[] = [];
    if (this.stats !== null) {
      const days = this.stats.coverage.slice(-84);
      for (let index = 0; index < days.length; index += 1) {
        const day = days[index];
        const row = (new Date(day.date).getDay() + 6) % 7;
        cells.push({ row: row, column: Math.floor(index / 7), value: day.recorded ? 1 : 0 });
      }
    }
    return { rows: rows, columns: columns, cells: cells, legend: '近 12 周读数记录' };
  }

  private activityHeatmap(): HeatmapData {
    const rows: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    const hours: number[] = [8, 12, 20, 21, 22];
    const columns: string[] = ['08', '12', '20', '21', '22'];
    const cells: HeatCell[] = [];
    if (this.stats !== null) {
      for (const item of this.stats.activity) {
        const column = hours.indexOf(item.hour);
        if (column >= 0) {
          cells.push({ row: item.weekday - 1, column: column, value: item.count });
        }
      }
    }
    return { rows: rows, columns: columns, cells: cells, legend: '速记时段分布' };
  }

  @Builder
  header() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text('数据看板')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Text(this.stats !== null ? `远端示例数据 · ${this.stats.generatedAt}` : '等待远端数据')
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Row({ space: 6 }) {
        Text('6 月')
          .fontSize(11)
          .fontColor(this.range === '6m' ? AppTheme.color.primary : AppTheme.color.textMuted)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(this.range === '6m' ? AppTheme.color.surfaceAlt : AppTheme.color.surface)
          .borderRadius(12)
          .onClick(() => this.switchRange('6m'))
        Text('12 月')
          .fontSize(11)
          .fontColor(this.range === '12m' ? AppTheme.color.primary : AppTheme.color.textMuted)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(this.range === '12m' ? AppTheme.color.surfaceAlt : AppTheme.color.surface)
          .borderRadius(12)
          .onClick(() => this.switchRange('12m'))
        Text('刷新')
          .fontSize(11)
          .fontColor(AppTheme.color.primary)
          .onClick(() => this.load())
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 6 })
  }

  @Builder
  stateCard() {
    if (this.isLoading) {
      Row({ space: 8 }) {
        LoadingProgress().width(16).height(16).color(AppTheme.color.primary)
        Text('正在加载远端数据…').fontSize(11).fontColor(AppTheme.color.textMuted)
      }
      .width('100%')
      .padding(16)
    } else if (this.errorText.length > 0) {
      Column({ space: 6 }) {
        Text('图表数据加载失败')
          .fontSize(12)
          .fontColor(AppTheme.color.danger)
        Text(this.errorText)
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
        Text('重试')
          .fontSize(11)
          .fontColor(AppTheme.color.primary)
          .onClick(() => this.load())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    } else if (this.stats !== null && this.stats.months.length === 0) {
      Text('远端暂无统计数据')
        .fontSize(11)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
        .padding(16)
    }
  }

  @Builder
  dashboardBody() {
    Scroll() {
      Column({ space: 10 }) {
        this.header()
        this.stateCard()
        if (this.stats !== null && this.stats.months.length > 0) {
          ChartSection({ title: '月度命中率', hint: '折线为命中率，标签为月份；样本量见下方结果分布' }) {
            SimpleLineChart({ series: this.monthSeries(), maxValue: 100, minValue: 0 })
          }
          ChartSection({ title: '校准曲线', hint: '横轴为置信度档位，纵轴为实际命中率；细线为理想校准' }) {
            SimpleLineChart({ series: this.calibrationSeries(), maxValue: 100, minValue: 0 })
            Text(`校准共 ${this.stats !== null ? this.stats.calibration.length : 0} 档，样本不足 20 条时仅作观察`)
              .fontSize(9)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          }
          ChartSection({ title: '结果分布', hint: '命中、未命中、作废与被替代的占比' }) {
            SimplePieChart({ slices: this.outcomeSlices(), centerText: this.outcomeCenter() })
          }
          ChartSection({ title: '置信度分布', hint: '预测提交时的信心分布，观察是否集中在高自信区' }) {
            SimpleBarChart({ points: this.confidencePoints(), color: HIT_COLOR, chartHeight: 140 })
          }
          ChartSection({ title: '期限分档命中率', hint: '期限越长，命中率是否下降' }) {
            SimpleBarChart({ points: this.horizonPoints(), color: LINE_COLOR, horizontal: true, chartHeight: 150 })
          }
          ChartSection({ title: '读数趋势', hint: '最近 14 天的睡眠时长，用于对照判断状态' }) {
            SimpleLineChart({ series: [{ name: '睡眠', color: LINE_COLOR, points: this.sleepPoints() }], minValue: 4, maxValue: 9 })
          }
          ChartSection({ title: '睡眠分组命中率', hint: '睡眠不足与充足两组的命中率对比' }) {
            SimpleBarChart({ points: this.sleepBucketPoints(), color: HIT_COLOR, maxValue: 100, chartHeight: 140 })
          }
          ChartSection({ title: '互动频率', hint: '近 90 天与各关系的记录次数，代号为脱敏别名' }) {
            SimpleBarChart({ points: this.interactionPoints(), color: LINE_COLOR, horizontal: true, chartHeight: 150 })
          }
          ChartSection({ title: '读数覆盖率', hint: '每格代表一天，颜色越深表示已记录' }) {
            HeatmapGrid({ data: this.coverageHeatmap(), maxValue: 1 })
          }
          ChartSection({ title: '速记时段', hint: '按星期与时段统计的记录次数' }) {
            HeatmapGrid({ data: this.activityHeatmap(), maxValue: 7 })
          }
          Text('数据来自远端示例接口，仅用于课程演示；图表随接口返回变化重绘。')
            .fontSize(9)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
            .padding({ top: 4, bottom: 20 })
        }
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
  }

  build() {
    AppDestination({
      route: 'analytics',
      title: '数据看板',
      content: () => {
        this.dashboardBody();
      }
    })
  }
}
