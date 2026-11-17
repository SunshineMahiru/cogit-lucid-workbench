import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { ChartSection } from '../components/charts/ChartSection';
import { SimpleLineChart } from '../components/charts/SimpleLineChart';
import { SimpleBarChart } from '../components/charts/SimpleBarChart';
import { SimplePieChart } from '../components/charts/SimplePieChart';
import { ChartPoint, ChartSeries, ChartSlice } from '../components/charts/ChartModels';
import { EvidenceChip } from '../components/EvidenceChip';
import { AppTheme } from '../theme/AppTheme';
import { evidenceStyle } from '../theme/EvidenceLanguage';
import { SAMPLE_FLOOR } from '../analysis/metrics/SampleFloor';
import { RemoteStatsRepository } from '../network/RemoteStatsRepository';
import { RemoteStats } from '../network/RemoteStats';
import {
  buildLocalStats,
  loadLocalStats,
  EvidenceCount,
  LocalStatsInput,
  LocalStatsReport,
  RatioPoint,
  StatBucket
} from '../analytics/LocalStatsMapper';
import {
  DEMO_STATS_EVIDENCE,
  DEMO_STATS_MATERIALS,
  DEMO_STATS_PREDICTIONS,
  DEMO_STATS_RELATIONS
} from '../analytics/DemoStats';

const HIT_COLOR = 0xFF4A6FA5;
const LINE_COLOR = 0xFF2E6F9E;
const REF_COLOR = 0xFFB7B3A6;
const SUCCESS_COLOR = 0xFF2E7D32;
const WARNING_COLOR = 0xFFB0761E;

/** Local judgement dashboard: six questions answered from the device itself. */
@ComponentV2
export struct AnalyticsPage {
  @Local report: LocalStatsReport | null = null;
  @Local isLoading: boolean = true;
  @Local errorText: string = '';
  @Local usingDemo: boolean = false;
  @Local demoEnabled: boolean = true;
  @Local hasReal: boolean = false;
  @Local isPreview: boolean = false;
  @Local remoteOpen: boolean = false;
  @Local remoteStats: RemoteStats | null = null;
  @Local remoteLoading: boolean = false;
  @Local remoteError: string = '';
  private repository: RemoteStatsRepository = new RemoteStatsRepository();
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private demoInput(): LocalStatsInput {
    return {
      predictions: DEMO_STATS_PREDICTIONS,
      materials: DEMO_STATS_MATERIALS,
      relations: DEMO_STATS_RELATIONS,
      evidence: DEMO_STATS_EVIDENCE
    };
  }

  private showDemo(): void {
    this.report = buildLocalStats(this.demoInput());
    this.usingDemo = true;
  }

  private async load(): Promise<void> {
    this.isLoading = true;
    this.errorText = '';
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.isPreview = true;
      this.hasReal = false;
      this.showDemo();
      this.isLoading = false;
      return;
    }
    try {
      const loaded = await loadLocalStats(context);
      this.hasReal = loaded.hasRecords;
      if (loaded.hasRecords) {
        this.report = loaded;
        this.usingDemo = false;
      } else if (this.demoEnabled) {
        this.showDemo();
      } else {
        this.report = null;
        this.usingDemo = false;
      }
    } catch (error) {
      this.errorText = error instanceof Error ? error.message : '本机数据读取失败';
      if (this.demoEnabled) {
        this.showDemo();
      } else {
        this.report = null;
        this.usingDemo = false;
      }
    } finally {
      this.isLoading = false;
    }
  }

  private setDemoEnabled(isOn: boolean): void {
    this.demoEnabled = isOn;
    if (this.hasReal) {
      return;
    }
    if (isOn) {
      this.showDemo();
    } else {
      this.report = null;
      this.usingDemo = false;
    }
  }

  private statusTitle(): string {
    if (this.isPreview) {
      return '演示数据 · Previewer 无法读取本机数据库';
    }
    if (this.usingDemo) {
      return '演示数据·非真实记录';
    }
    if (this.hasReal) {
      return '已切换为真实数据';
    }
    return '等待本地记录';
  }

  private statusDetail(): string {
    const settled = this.report === null ? 0 : this.report.settled;
    return `本机已结算 ${settled} 条 · 预测、速记、关系与证据只在本机计算`;
  }

  private calibrationPoints(report: LocalStatsReport): ChartPoint[] {
    const points: ChartPoint[] = [];
    for (const bucket of report.calibration.buckets) {
      if (bucket.total < SAMPLE_FLOOR) {
        continue;
      }
      points.push({
        label: bucket.label,
        value: bucket.hitRate,
        note: `${bucket.total} 条`,
        x: bucket.mid
      });
    }
    return points;
  }

  private calibrationReady(report: LocalStatsReport): boolean {
    return this.calibrationPoints(report).length >= 2;
  }

  private calibrationSeries(report: LocalStatsReport): ChartSeries[] {
    const ideal: ChartPoint[] = [
      { label: '0%', value: 0, note: '', x: 0 },
      { label: '100%', value: 100, note: '', x: 100 }
    ];
    return [
      { name: '实际命中', color: HIT_COLOR, points: this.calibrationPoints(report) },
      { name: '理想校准', color: REF_COLOR, points: ideal }
    ];
  }

  private monthSeries(report: LocalStatsReport): ChartSeries[] {
    const points: ChartPoint[] = [];
    for (const month of report.months) {
      points.push({
        label: month.label,
        value: month.hitRate,
        note: `${month.settled} 条`
      });
    }
    return [{ name: '命中率', color: LINE_COLOR, points: points }];
  }

  private confidencePoints(report: LocalStatsReport): ChartPoint[] {
    const points: ChartPoint[] = [];
    for (const bucket of report.confidence.buckets) {
      if (!bucket.enough) {
        continue;
      }
      points.push({ label: bucket.label, value: bucket.hitRate, note: `${bucket.total} 条` });
    }
    return points;
  }

  private horizonPoints(report: LocalStatsReport): ChartPoint[] {
    const points: ChartPoint[] = [];
    for (const bucket of report.horizon.buckets) {
      if (!bucket.enough) {
        continue;
      }
      points.push({ label: bucket.label, value: bucket.hitRate, note: `${bucket.total} 条` });
    }
    return points;
  }

  private ratioSeries(report: LocalStatsReport): ChartSeries[] {
    const points: ChartPoint[] = report.interpretation.points.map((point: RatioPoint): ChartPoint => {
      return {
        label: point.label,
        value: Math.round(point.ratio * 100),
        note: `${point.interpretationChars}/${point.sceneFeelingChars} 字`
      };
    });
    return [{ name: '解释/现场', color: WARNING_COLOR, points: points }];
  }

  private ratioMax(report: LocalStatsReport): number {
    let max = 100;
    for (const point of report.interpretation.points) {
      max = Math.max(max, Math.round(point.ratio * 100));
    }
    return Math.ceil(max * 1.2 / 50) * 50;
  }

  private correctionSlices(report: LocalStatsReport): ChartSlice[] {
    return [
      { label: '已回应', value: report.correction.responded, color: SUCCESS_COLOR },
      { label: '待回应', value: report.correction.pending, color: WARNING_COLOR }
    ];
  }

  private revisionSlices(report: LocalStatsReport): ChartSlice[] {
    return [
      { label: '实质重建', value: report.revision.substantive, color: SUCCESS_COLOR },
      { label: '仅术语增加', value: report.revision.termOnly, color: WARNING_COLOR }
    ];
  }

  private missingBuckets(buckets: StatBucket[]): string {
    const labels: string[] = [];
    for (const bucket of buckets) {
      if (bucket.total > 0 && !bucket.enough) {
        labels.push(`${bucket.label} ${bucket.total} 条`);
      }
    }
    return labels.join('、');
  }

  private bucketFooter(report: LocalStatsReport): string {
    const parts: string[] = [];
    const confidenceMissing = this.missingBuckets(report.confidence.buckets);
    const horizonMissing = this.missingBuckets(report.horizon.buckets);
    if (confidenceMissing.length > 0) {
      parts.push(`置信分档样本不足未绘制：${confidenceMissing}`);
    }
    if (horizonMissing.length > 0) {
      parts.push(`期限分档样本不足未绘制：${horizonMissing}`);
    }
    const head = parts.length === 0 ? '' : `${parts.join('；')}；`;
    return `${head}口径：样本达到 ${SAMPLE_FLOOR} 条才绘制分档，非二值结果与封存记录不计入。`;
  }

  private remoteSeries(): ChartSeries[] {
    if (this.remoteStats === null) {
      return [];
    }
    const points: ChartPoint[] = [];
    for (const month of this.remoteStats.months) {
      points.push({
        label: month.label,
        value: Math.round(month.hitRate * 100),
        note: `${month.settled} 条`
      });
    }
    return [{ name: '远端命中率', color: LINE_COLOR, points: points }];
  }

  private remoteGeneratedAt(): string {
    return this.remoteStats === null ? '' : this.remoteStats.generatedAt;
  }

  private toggleRemote(): void {
    this.remoteOpen = !this.remoteOpen;
    if (this.remoteOpen && this.remoteStats === null && !this.remoteLoading) {
      this.loadRemote();
    }
  }

  private async loadRemote(): Promise<void> {
    this.remoteLoading = true;
    this.remoteError = '';
    try {
      this.remoteStats = await this.repository.fetch();
    } catch (error) {
      this.remoteError = error instanceof Error ? error.message : '远端数据加载失败';
    } finally {
      this.remoteLoading = false;
    }
  }

  @Builder
  header() {
    Row({ space: AppTheme.spacing.s8 }) {
      Column({ space: AppTheme.spacing.s2 }) {
        Text(this.statusTitle())
          .fontSize(AppTheme.font.caption)
          .fontColor(this.usingDemo ? AppTheme.color.warning : AppTheme.color.textMuted)
        Text(this.statusDetail())
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('刷新')
        .id('analytics_refresh')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.primary)
        .onClick(() => {
          this.load();
        })
    }
    .width('100%')
  }

  @Builder
  demoBanner() {
    Column({ space: AppTheme.spacing.s4 }) {
      Text('演示数据·非真实记录')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.warning)
        .width('100%')
      Text('本地还没有可统计的记录。图表来自内置脱敏样例；写入任意速记、预测或关系后会自动切换为真实数据。')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(AppTheme.spacing.s12)
    .backgroundColor(AppTheme.color.warningSurface)
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  demoToggle() {
    Row({ space: AppTheme.spacing.s8 }) {
      Column({ space: AppTheme.spacing.s2 }) {
        Text('显示演示数据')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.text)
        Text('本地没有可统计记录时，用内置脱敏样例填满看板')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.demoEnabled })
        .id('analytics_demo_toggle')
        .onChange((isOn: boolean) => {
          this.setDemoEnabled(isOn);
        })
    }
    .width('100%')
  }

  @Builder
  stateCard() {
    if (this.isLoading) {
      Row({ space: AppTheme.spacing.s8 }) {
        LoadingProgress().width(16).height(16).color(AppTheme.color.primary)
        Text('正在读取本机记录…')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textMuted)
      }
      .width('100%')
    } else if (this.errorText.length > 0) {
      Column({ space: AppTheme.spacing.s4 }) {
        Text(this.report !== null ? '本机数据读取失败，当前显示演示数据' : '本机数据读取失败')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.danger)
        Text(this.errorText)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
        Text('重试')
          .id('analytics_retry')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.load();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else if (this.report === null) {
      SectionCard() {
        Column({ space: AppTheme.spacing.s6 }) {
          Text('本地还没有可统计的记录')
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.text)
            .width('100%')
          Text('写入速记、预测、关系或证据后，图表会自动出现。也可以打开上方「显示演示数据」查看样例。')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
            .width('100%')
        }
        .width('100%')
      }
    }
  }

  @Builder
  evidenceBars(report: LocalStatsReport) {
    Column({ space: AppTheme.spacing.s8 }) {
      ForEach(report.evidence.rows, (row: EvidenceCount) => {
        Column({ space: AppTheme.spacing.s4 }) {
          Row() {
            EvidenceChip({ source: row.source })
            Blank()
            Text(`${row.count} 条 · ${row.percent}%`)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textSecondary)
          }
          .width('100%')
          Row() {
            Row()
              .width(`${row.percent}%`)
              .height(6)
              .backgroundColor(evidenceStyle(row.source).color)
              .borderRadius(AppTheme.radius.xs)
          }
          .width('100%')
          .height(6)
          .backgroundColor(AppTheme.color.track)
          .borderRadius(AppTheme.radius.xs)
        }
        .width('100%')
      }, (row: EvidenceCount) => row.source)
    }
    .width('100%')
  }

  @Builder
  metricCards(report: LocalStatsReport) {
    ChartSection({
      title: '校准与命中率',
      hint: '我是否过度自信？横轴为提交时的信心，纵轴为实际命中率；斜线为理想校准。',
      verdict: report.calibration.verdict,
      footer: `已结算 ${report.settled} 条，其中可判断 ${report.binarySettled} 条，命中率 ${report.hitRate}%；` +
        `Brier ${report.calibration.brierScore.toFixed(3)}，校准样本 ${report.calibration.settled} 条。` +
        '未记录按缺失留空，不补零；封存记录不参与统计。',
      demoTag: this.usingDemo
    }) {
      if (this.calibrationReady(report)) {
        SimpleLineChart({
          series: this.calibrationSeries(report),
          maxValue: 100,
          minValue: 0,
          showXLabels: false,
          xMin: 0,
          xMax: 100
        })
      } else {
        Text(`校准样本不足 ${SAMPLE_FLOOR} 条，暂不绘制曲线`)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      if (report.months.length >= 2) {
        Text('最近六个月命中率')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
        SimpleLineChart({
          series: this.monthSeries(report),
          maxValue: 100,
          minValue: 0
        })
      }
    }

    ChartSection({
      title: '命中率分档',
      hint: '我的判断在哪些条件下更准？按期限与提交信心分档，样本不足只标注数量。',
      verdict: `${report.horizon.verdict}；${report.confidence.verdict}`,
      footer: this.bucketFooter(report),
      demoTag: this.usingDemo
    }) {
      Text('期限分档')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
      if (this.horizonPoints(report).length > 0) {
        SimpleBarChart({
          points: this.horizonPoints(report),
          color: LINE_COLOR,
          maxValue: 100,
          horizontal: true,
          chartHeight: 140
        })
      } else {
        Text('各期限分档样本不足')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      Text('置信度分档')
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textMuted)
        .width('100%')
      if (this.confidencePoints(report).length > 0) {
        SimpleBarChart({
          points: this.confidencePoints(report),
          color: HIT_COLOR,
          maxValue: 100,
          chartHeight: 140
        })
      } else {
        Text('各置信分档样本不足')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
    }

    ChartSection({
      title: '解释比例趋势',
      hint: '我是否在用解释代替现场？每月的解释字数除以现场与感受字数，100 表示两者相当。',
      verdict: report.interpretation.verdict,
      footer: '口径：只统计现场、感受、解释三类材料；封存材料不参与。月份按材料记录日期归月。',
      demoTag: this.usingDemo
    }) {
      if (report.interpretation.points.length >= 2) {
        SimpleLineChart({
          series: this.ratioSeries(report),
          minValue: 0,
          maxValue: this.ratioMax(report)
        })
      } else {
        Text('至少两个月有现场、感受或解释材料后才绘制趋势')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
    }

    ChartSection({
      title: '证据来源分布',
      hint: '我的证据秩序是否偏食？六类证据来源的占比。',
      verdict: report.evidence.verdict,
      footer: '口径：统计复盘与预测上记录的证据条目；封存证据不参与。',
      demoTag: this.usingDemo
    }) {
      if (report.evidence.total > 0) {
        this.evidenceBars(report)
      } else {
        Text('还没有证据记录')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
    }

    ChartSection({
      title: '纠正回应率',
      hint: '我是否回应了他者纠正？他者纠正后，是否留下自己的观察。',
      verdict: report.correction.verdict,
      footer: '口径：一份纠正记录在纠正时间之后出现我自己的观察，才算已回应；未回应的按待回应显示。',
      demoTag: this.usingDemo
    }) {
      if (report.correction.corrected > 0) {
        SimplePieChart({
          slices: this.correctionSlices(report),
          centerText: `${report.correction.rate}%`
        })
      } else {
        Text('还没有他者纠正记录')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
    }

    ChartSection({
      title: '修订质量',
      hint: '我的重建是否只有术语？修订中仅增加术语、没有写新增解释力的比例。',
      verdict: report.revision.verdict,
      footer: '口径：版本大于 1 的预测记为一次修订；未填写新增解释力的修订归为仅术语增加。',
      demoTag: this.usingDemo
    }) {
      if (report.revision.revised > 0) {
        SimplePieChart({
          slices: this.revisionSlices(report),
          centerText: `${report.revision.rate}%`
        })
      } else {
        Text('还没有修订记录')
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
    }
  }

  @Builder
  remoteSection() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s6 }) {
        Row() {
          Column({ space: AppTheme.spacing.s2 }) {
            Text('远端参考')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.text)
            Text('可选附加区块，默认折叠；远端示例不参与本地判断')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text(this.remoteOpen ? '收起' : '展开')
            .id('analytics_remote_toggle')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.toggleRemote();
            })
        }
        .width('100%')
        if (this.remoteOpen) {
          if (this.remoteLoading) {
            Row({ space: AppTheme.spacing.s8 }) {
              LoadingProgress().width(16).height(16).color(AppTheme.color.primary)
              Text('正在加载远端数据…')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textMuted)
            }
            .width('100%')
          } else if (this.remoteError.length > 0) {
            Column({ space: AppTheme.spacing.s4 }) {
              Text(this.remoteError)
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.danger)
              Text('重试')
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.primary)
                .onClick(() => {
                  this.loadRemote();
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          } else if (this.remoteStats !== null) {
            SimpleLineChart({
              series: this.remoteSeries(),
              maxValue: 100,
              minValue: 0
            })
            Text(`远端示例生成于 ${this.remoteGeneratedAt()}，仅作参考。`)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          } else {
            Text('展开后加载远端示例')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          }
        }
      }
      .width('100%')
    }
  }

  @Builder
  dashboardBody() {
    Scroll() {
      Column({ space: AppTheme.spacing.s12 }) {
        this.header()
        if (this.usingDemo) {
          this.demoBanner()
        }
        if (!this.hasReal && !this.isPreview) {
          this.demoToggle()
        }
        this.stateCard()
        if (this.report !== null && !this.isLoading) {
          this.metricCards(this.report)
        }
        this.remoteSection()
      }
      .width('100%')
      .padding({
        left: AppTheme.spacing.page,
        right: AppTheme.spacing.page,
        top: AppTheme.spacing.s8,
        bottom: AppTheme.spacing.s24
      })
    }
    .width('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  build() {
    AppDestination({
      route: 'analytics',
      title: '数据看板',
      content: () => {
        this.dashboardBody();
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.load();
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }
}