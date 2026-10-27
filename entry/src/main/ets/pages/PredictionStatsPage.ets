import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { PredictionTrendChart } from '../components/PredictionTrendChart';
import { PredictionShareChart } from '../components/PredictionShareChart';
import { PredictionService, PredictionStats } from '../prediction';
import { formatHitRate } from '../model/HomeModel';

/** Read-only statistics: monthly hit-rate trend and hit/miss share. */
@ComponentV2
export struct PredictionStatsPage {
  @Local service: PredictionService | null = null;
  @Local stats: PredictionStats = { settled: 0, hits: 0, misses: 0, hitRate: 0, months: [] };
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isLoading = false;
      return;
    }
    try {
      this.service = await PredictionService.open(hostContext);
      this.stats = await this.service.stats();
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '统计数据加载失败' });
    }
  }

  private async refresh(): Promise<void> {
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.stats = await this.service.stats();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '统计数据加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private async seed(): Promise<void> {
    if (this.service === null || this.isSeeding) {
      return;
    }
    this.isSeeding = true;
    try {
      const added = await this.service.seedDemoPredictions();
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已载入 ${added} 条示例预测` : '已有预测记录，未重复载入'
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '载入失败，请重试' });
    } finally {
      this.isSeeding = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(AppTheme.color.primary)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.stats.settled === 0) {
          Column() {
            NoteEmptyState({
              title: '还没有已结算的预测',
              hint: '至少结算一条预测后才能统计命中率；示例数据仅用于演示',
              actionLabel: this.isSeeding ? '载入中…' : '载入示例预测',
              dashed: true,
              onAction: () => {
                this.seed();
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page })
        } else {
          Scroll() {
            Column({ space: 12 }) {
              SectionCard() {
                Row() {
                  Column({ space: 2 }) {
                    Text(formatHitRate(this.stats.hitRate, this.stats.settled))
                      .fontSize(30)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppTheme.color.primary)
                    Text('整体命中率')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: 6 }) {
                    Text(`已结算 ${this.stats.settled} 条`)
                      .fontSize(11)
                      .fontColor(AppTheme.color.text)
                    Text(`命中 ${this.stats.hits} · 未命中 ${this.stats.misses}`)
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Row() {
                    Text('命中率趋势')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                    Blank()
                    Text('按月 · 最近 6 个月')
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                  }
                  .width('100%')

                  PredictionTrendChart({ points: this.stats.months })

                  Text(`整体样本 ${this.stats.settled} 条；趋势最多显示最近 6 个月`)
                    .fontSize(10)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('命中 / 未命中')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  PredictionShareChart({
                    hits: this.stats.hits,
                    misses: this.stats.misses,
                    hitRate: this.stats.hitRate
                  })
                  Text('口径：按结算日期归月，只统计已结算预测')
                    .fontSize(10)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title('预测统计')
    .onShown(() => {
      if (this.hasShownOnce) {
        this.refresh();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
