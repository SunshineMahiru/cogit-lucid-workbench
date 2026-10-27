import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { RelationCard } from '../components/RelationCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { RelationListItem, RelationService, trustLevelText } from '../relation';
import { TrustLevel } from '../model/TrustLevel';
import { RelationDetailParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';

/** Read-only relation list with trust tier filters and an explicit demo seed. */
@ComponentV2
export struct RelationListPage {
  @Local service: RelationService | null = null;
  @Local items: RelationListItem[] = [];
  @Local filter: TrustLevel | null = null;
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  private navStack: NavPathStack | null = null;
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
      this.service = await RelationService.open(hostContext);
      this.items = await this.service.list(this.filter);
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '关系数据加载失败' });
    }
  }

  private async refresh(): Promise<void> {
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.items = await this.service.list(this.filter);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '关系数据加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private selectFilter(level: TrustLevel | null): void {
    this.filter = level;
    this.refresh();
  }

  private async seed(): Promise<void> {
    if (this.service === null || this.isSeeding) {
      return;
    }
    this.isSeeding = true;
    try {
      const added = await this.service.seedDemoRelations();
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已载入 ${added} 条示例关系` : '已有关系记录，未重复载入'
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '载入失败，请重试' });
    } finally {
      this.isSeeding = false;
    }
  }

  private openDetail(relationId: string): void {
    if (this.navStack === null) {
      return;
    }
    const params: RelationDetailParams = { relationId: relationId };
    this.navStack.pushPathByName(ROUTES.RELATION_DETAIL, params);
  }

  @Builder
  filterChip(label: string, level: TrustLevel | null) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filter === level ? Color.White : AppTheme.color.text)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === level ? AppTheme.color.primary : '#F1EFE8')
      .borderRadius(14)
      .onClick(() => {
        this.selectFilter(level);
      })
  }

  @Builder
  graphMenu() {
    Text('图谱')
      .fontSize(14)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 12, right: 16 })
      .onClick(() => {
        if (this.navStack !== null) {
          this.navStack.pushPathByName(ROUTES.RELATION_GRAPH, null);
        }
      })
  }

  @Builder
  headerCard() {
    SectionCard() {
      Column({ space: 4 }) {
        Row() {
          Text('关系层')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Blank()
          Text(`${this.items.length} 人`)
            .fontSize(11)
            .fontColor(AppTheme.color.textSecondary)
        }
        .width('100%')

        Text('只读 · 按信任层级排序；互动记录用于复盘时判断可分析边界。')
          .fontSize(11)
          .lineHeight(17)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          this.headerCard()
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: 12 })

        Scroll() {
          Row({ space: AppTheme.spacing.gap }) {
            this.filterChip('全部', null)
            this.filterChip('友好', TrustLevel.FRIENDLY)
            this.filterChip('真诚', TrustLevel.SINCERE)
            this.filterChip('透明', TrustLevel.TRANSPARENT)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: 10 })

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
              title: this.filter === null ? '还没有关系记录' : `没有${trustLevelText(this.filter)}层级的关系`,
              hint: '关系用于复盘时判断可分析边界；示例数据仅用于演示',
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
            Column({ space: AppTheme.spacing.gap }) {
              ForEach(this.items, (item: RelationListItem) => {
                RelationCard({
                  item: item,
                  onTap: () => {
                    this.openDetail(item.id);
                  }
                })
              }, (item: RelationListItem) => item.id)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: 10, bottom: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.color.page)
    }
    .title('关系层')
    .menus(this.graphMenu)
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
    .onShown(() => {
      if (this.hasShownOnce) {
        this.refresh();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
