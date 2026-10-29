import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { RelationGraph } from '../components/RelationGraph';
import { RelationListItem, RelationService, trustLevelText } from '../relation';
import { TrustLevel } from '../model/TrustLevel';
import { PREVIEW_RELATION_ITEMS } from '../preview/PreviewData';
import { PREVIEW_WRITE_BLOCKED } from '../preview/PreviewMode';

/** Read-only relation star map; the list view remains the editing-free directory. */
@ComponentV2
export struct RelationGraphPage {
  @Local service: RelationService | null = null;
  @Local items: RelationListItem[] = [];
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  @Local isPreview: boolean = false;
  private hasShownOnce: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await RelationService.open(hostContext);
      this.items = await this.service.list(null);
      this.isLoading = false;
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '关系图谱加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.items = PREVIEW_RELATION_ITEMS.slice();
    this.isLoading = false;
  }

  private async seed(): Promise<void> {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: PREVIEW_WRITE_BLOCKED });
      return;
    }
    if (this.service === null || this.isSeeding) {
      return;
    }
    this.isSeeding = true;
    try {
      const added = await this.service.seedDemoRelations();
      this.items = await this.service.list(null);
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已载入 ${added} 条示例关系` : '已有关系记录，未重复载入'
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '载入失败，请重试' });
    } finally {
      this.isSeeding = false;
    }
  }

  private count(level: TrustLevel): number {
    let total = 0;
    for (const item of this.items) {
      if (item.trustLevel === level) {
        total += 1;
      }
    }
    return total;
  }

  @Builder
  legendItem(level: TrustLevel) {
    Row({ space: 4 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(level === TrustLevel.TRANSPARENT ? AppTheme.color.success :
          (level === TrustLevel.SINCERE ? AppTheme.color.warning : AppTheme.color.primaryDeep))
      Text(`${trustLevelText(level)} ${this.count(level)}`)
        .fontSize(10)
        .fontColor(AppTheme.color.textSecondary)
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
        } else if (this.items.length === 0) {
          Column() {
            NoteEmptyState({
              title: '还没有关系记录',
              hint: '载入示例关系后可以看到以你为中心的信任星图',
              actionLabel: this.isSeeding ? '载入中…' : '载入示例关系',
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
                Column({ space: 8 }) {
                  Text(`关系星图 · ${this.items.length} 人`)
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row({ space: 12 }) {
                    this.legendItem(TrustLevel.FRIENDLY)
                    this.legendItem(TrustLevel.SINCERE)
                    this.legendItem(TrustLevel.TRANSPARENT)
                  }
                  .width('100%')

                  Column() {
                    RelationGraph({ items: this.items })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)

                  Text(this.items.length > 6 ? '仅显示前 6 人；完整名单见关系列表' : '以我为中心，颜色表示信任层级')
                    .fontSize(10)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              Text('说明：现有数据只有「我—关系」的互动，没有人与人之间的边，因此不绘制全量网络图。')
                .fontSize(10)
                .lineHeight(17)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title('关系图谱')
    .onShown(() => {
      if (this.hasShownOnce) {
        this.load();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
