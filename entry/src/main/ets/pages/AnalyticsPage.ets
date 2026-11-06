import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { AppTheme } from '../theme/AppTheme';
import { SimpleLineChart } from '../components/charts/SimpleLineChart';
import { SimpleBarChart } from '../components/charts/SimpleBarChart';
import { SimplePieChart } from '../components/charts/SimplePieChart';
import { HeatmapGrid } from '../components/charts/HeatmapGrid';
import { ChartSection } from '../components/charts/ChartSection';
import { ChartPoint, ChartSeries, ChartSlice, HeatCell, HeatmapData } from '../components/charts/ChartModels';
import { RemoteStatsRepository } from '../network/RemoteStatsRepository';
import { RemoteStats, StatsMonth, StatsMonthDetail } from '../network/RemoteStats';

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
  @Local selectedMonth: string = '';
  private repository: RemoteStatsRepository = new RemoteStatsRepository();
  /** Bumped on every load so a slow earlier response cannot overwrite a newer one. */
  private loadToken: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const token = this.loadToken + 1;
    this.loadToken = token;
    this.isLoading = true;
    this.errorText = '';
    try {
      const stats = await this.repository.fetch();
      if (token !== this.loadToken) {
        return;
      }
      this.stats = stats;
      if (stats.months.length > 0 && this.selectedMonth.length === 0) {
        this.selectedMonth = stats.months[stats.months.length - 1].label;
      }
    } catch (error) {
      if (token !== this.loadToken) {
        return;
      }
      this.errorText = error instanceof Error ? error.message : '图表数据加载失败';
    } finally {
      if (token === this.loadToken) {
        this.isLoading = false;
      }
    }
  }

  private switchMonth(month: string): void {
    this.selectedMonth = month;
  }

  private currentDetail(): StatsMonthDetail | null {
    if (this.stats === null) {
      return null;
    }
    for (const detail of this.stats.monthly) {
      if (detail.month === this.selectedMonth) {
        return detail;
      }
    }
    return null;
  }

  private monthsForPicker(): StatsMonth[] {
    if (this.stats === null) {
      return [];
    }
    return this.stats.months.slice().reverse();
  }

  private monthSeries(): ChartSeries[] {
    if (this.stats === null) {
      return [];
    }
    let end = this.stats.months.length;
    for (let index = 0; index < this.stats.months.length; index += 1) {
      if (this.stats.months[index].label === this.selectedMonth) {
        end = index + 1;
        break;
      }
    }
    const start = Math.max(0, end - 6);
    const points: ChartPoint[] = [];
    for (let index = start; index < end; index += 1) {
      const month = this.stats.months[index];
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
      { label: '0%', value: 0, note: '', x: 0 },
      { label: '100%', value: 100, note: '', x: 100 }
    ];
    const actual: ChartPoint[] = [];
    const detail = this.currentDetail();
    const buckets = detail !== null ? detail.calibration : this.stats.calibration;
    for (const bucket of buckets) {
      const confidence = Math.round(bucket.predicted * 100);
      actual.push({
        label: `${confidence}%`,
        value: Math.round(bucket.actual * 100),
        note: `${bucket.samples} 条`,
        x: confidence
      });
    }
    return [
      { name: '实际命中', color: HIT_COLOR, points: actual },
      { name: '理想校准', color: REF_COLOR, points: perfect }
    ];
  }

  private confidencePoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      const detail = this.currentDetail();
      const buckets = detail !== null ? detail.confidence : this.stats.confidence;
      for (const bucket of buckets) {
        points.push({ label: bucket.bucket, value: bucket.count, note: `${bucket.count} 条` });
      }
    }
    return points;
  }

  private horizonPoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      const detail = this.currentDetail();
      const buckets = detail !== null ? detail.horizon : this.stats.horizon;
      for (const bucket of buckets) {
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
      const detail = this.currentDetail();
      const readings = (detail !== null ? detail.readings : this.stats.readings).slice(-14);
      for (const reading of readings) {
        points.push({ label: reading.date.slice(5), value: reading.sleep, note: `${reading.sleep} 小时` });
      }
    }
    return points;
  }

  private sleepBucketPoints(): ChartPoint[] {
    const points: ChartPoint[] = [];
    if (this.stats !== null) {
      const detail = this.currentDetail();
      const buckets = detail !== null ? detail.sleepBuckets : this.stats.sleepBuckets;
      for (const bucket of buckets) {
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
      const detail = this.currentDetail();
      const items = detail !== null ? detail.interactions : this.stats.interactions;
      for (const item of items) {
        points.push({ label: item.alias, value: item.count, note: `${item.count} 次` });
      }
    }
    return points;
  }

  private outcomeSlices(): ChartSlice[] {
    if (this.stats === null) {
      return [];
    }
    const detail = this.currentDetail();
    const outcomes = detail !== null ? detail.outcomes : this.stats.outcomes;
    return [
      { label: '命中', value: outcomes.hit, color: HIT_COLOR },
      { label: '未命中', value: outcomes.miss, color: MISS_COLOR },
      { label: '作废', value: outcomes.void, color: VOID_COLOR },
      { label: '被替代', value: outcomes.superseded, color: 0xFFD3D1C7 }
    ];
  }

  private outcomeCenter(): string {
    if (this.stats === null) {
      return '';
    }
    const detail = this.currentDetail();
    const outcomes = detail !== null ? detail.outcomes : this.stats.outcomes;
    const total = outcomes.hit + outcomes.miss + outcomes.void + outcomes.superseded;
    if (total === 0) {
      return '';
    }
    return `${Math.round(outcomes.hit / total * 100)}%`;
  }

  private coverageHeatmap(): HeatmapData {
    const rows: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    const detail = this.currentDetail();
    const days = (detail !== null ? detail.coverage : []).slice(0, 28);
    const columnCount = Math.max(4, Math.ceil(days.length / 7));
    const columns: string[] = [];
    for (let index = 0; index < columnCount; index += 1) {
      columns.push(`${index + 1}`);
    }
    const cells: HeatCell[] = [];
    for (let index = 0; index < days.length; index += 1) {
      const day = days[index];
      const row = (new Date(day.date).getDay() + 6) % 7;
      cells.push({ row: row, column: Math.floor(index / 7), value: day.recorded ? 1 : 0 });
    }
    return { rows: rows, columns: columns, cells: cells, legend: '当月每日读数记录' };
  }

  private activityHeatmap(): HeatmapData {
    const rows: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    const hours: number[] = [8, 12, 20, 21, 22];
    const columns: string[] = ['08', '12', '20', '21', '22'];
    const cells: HeatCell[] = [];
    const detail = this.currentDetail();
    const items = detail !== null ? detail.activity : [];
    for (const item of items) {
      const column = hours.indexOf(item.hour);
      if (column >= 0) {
        cells.push({ row: item.weekday - 1, column: column, value: item.count });
      }
    }
    return { rows: rows, columns: columns, cells: cells, legend: '速记时段分布' };
  }

  @Builder
  header() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(this.stats !== null ? `远端示例数据 · ${this.stats.generatedAt}` : '等待远端数据')
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
        Text(this.selectedMonth.length > 0 ? `当前月份 ${this.selectedMonth}` : '选择月份后查看')
          .fontSize(10)
          .fontColor(AppTheme.color.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('刷新')
        .id('analytics_refresh')
        .fontSize(11)
        .fontColor(AppTheme.color.primary)
        .onClick(() => this.load())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 6 })
  }

  @Builder
  monthPicker() {
    Scroll() {
      Row({ space: 6 }) {
        ForEach(this.monthsForPicker(), (month: StatsMonth, index: number) => {
          Text(month.label)
            .id(index === 0 ? 'analytics_month_first' : (index === 1 ? 'analytics_month_second' : `analytics_month_${month.label}`))
            .fontSize(11)
            .fontColor(this.selectedMonth === month.label ? Color.White : AppTheme.color.textSecondary)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.selectedMonth === month.label ? AppTheme.color.primary : AppTheme.color.surfaceAlt)
            .borderRadius(14)
            .onClick(() => this.switchMonth(month.label))
        }, (month: StatsMonth) => month.label)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 4 })
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
          .id('analytics_retry')
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
        this.monthPicker()
        this.stateCard()
        if (this.stats !== null && this.stats.months.length > 0) {
          ChartSection({ title: '月度命中率', hint: '折线为命中率，标签为月份；样本量见下方结果分布' }) {
            SimpleLineChart({ series: this.monthSeries(), maxValue: 100, minValue: 0 })
          }
              ChartSection({ title: '校准曲线', hint: '横轴为提交置信度，纵轴为实际命中率；斜线为理想校准' }) {
                SimpleLineChart({
                  series: this.calibrationSeries(),
                  maxValue: 100,
                  minValue: 0,
                  showXLabels: false,
                  xMin: 0,
                  xMax: 100
                })
            Text(`校准共 ${this.stats !== null ? this.stats.calibration.length : 0} 档，样本不足 20 条时仅作观察`)
              .fontSize(9)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          }
          ChartSection({ title: '结果分布', hint: '命中、未命中、作废与被替代的占比' }) {
            SimplePieChart({ slices: this.outcomeSlices(), centerText: this.outcomeCenter() })
          }
          ChartSection({ title: '置信度分布', hint: '预测提交时的信心分布，观察是否集中在高自信区' }) {
            SimpleBarChart({ points: this.confidencePoints(), color: HIT_COLOR, maxValue: 10, chartHeight: 140 })
          }
          ChartSection({ title: '期限分档命中率', hint: '期限越长，命中率是否下降' }) {
            SimpleBarChart({ points: this.horizonPoints(), color: LINE_COLOR, maxValue: 100, horizontal: true, chartHeight: 150 })
          }
          ChartSection({ title: '读数趋势', hint: '最近 14 天的睡眠时长，用于对照判断状态' }) {
            SimpleLineChart({ series: [{ name: '睡眠', color: LINE_COLOR, points: this.sleepPoints() }], minValue: 4, maxValue: 9, showXLabels: false })
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
