import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { RelationCard } from '../components/RelationCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { TagChip } from '../components/TagChip';
import { RelationListItem, RelationService, trustLevelText } from '../relation';
import { TrustLevel } from '../model/TrustLevel';
import { RelationDetailParams, RelationEditParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { PREVIEW_RELATION_ITEMS } from '../preview/PreviewData';
import { PREVIEW_WRITE_BLOCKED } from '../preview/PreviewMode';

/** Read-only relation list with trust tier filters and an explicit demo seed. */
@ComponentV2
export struct RelationListPage {
  @Local service: RelationService | null = null;
  @Local items: RelationListItem[] = [];
  @Local filter: TrustLevel | null = null;
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  @Local isPreview: boolean = false;
  @Local showHelp: boolean = false;
  @Local listVersion: number = 0;
  private navStack: NavPathStack | null = null;
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
      this.items = await this.service.list(this.filter);
      this.listVersion += 1;
      this.isLoading = false;
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '关系数据加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.items = this.filter === null ? PREVIEW_RELATION_ITEMS.slice() :
      PREVIEW_RELATION_ITEMS.filter((item: RelationListItem) => item.trustLevel === this.filter);
    this.listVersion += 1;
    this.isLoading = false;
  }

  private async refresh(): Promise<void> {
    if (this.isPreview) {
      this.loadPreview();
      return;
    }
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.items = await this.service.list(this.filter);
      this.listVersion += 1;
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

  private openEditor(): void {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: PREVIEW_WRITE_BLOCKED });
      return;
    }
    if (this.navStack === null) {
      return;
    }
    const params: RelationEditParams = { relationId: null };
    this.navStack.pushPathByName(ROUTES.RELATION_EDIT, params, () => {
      this.refresh();
    });
  }

  @Builder
  filterChip(label: string, level: TrustLevel | null) {
    TagChip({
      label: label,
      tone: AppTheme.color.primary,
      surface: AppTheme.color.tint,
      selected: this.filter === level,
      onTap: () => {
        this.selectFilter(level);
      }
    })
  }

  @Builder
  headerCard() {
    SectionCard() {
      Column({ space: AppTheme.spacing.s6 }) {
        Row({ space: AppTheme.spacing.s8 }) {
          Text('关系层')
            .fontSize(AppTheme.font.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Blank()
          Text(`${this.items.length} 人`)
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
          Text('＋ 新建')
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.primary)
            .padding({ left: AppTheme.spacing.s8 })
            .accessibilityText('新建关系')
            .onClick(() => {
              this.openEditor();
            })
        }
        .width('100%')

        Row({ space: AppTheme.spacing.s8 }) {
          Text('他者叙述是纠正的来源：先记下对方怎样纠正你，再补一条自己的回应。')
            .fontSize(AppTheme.font.body)
            .lineHeight(18)
            .fontColor(AppTheme.color.textSecondary)
            .layoutWeight(1)
          Text(this.showHelp ? '收起' : '怎么用')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.showHelp = !this.showHelp;
            })
        }
        .width('100%')

        if (this.showHelp) {
          Column({ space: AppTheme.spacing.s4 }) {
            Text('1. 新建：起一个化名，再选友好、真诚或透明。')
              .fontSize(AppTheme.font.caption)
              .lineHeight(16)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            Text('2. 记录：把对方明确说过的话或一次纠正写进互动记录。')
              .fontSize(AppTheme.font.caption)
              .lineHeight(16)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
            Text('3. 回应：读完后补一条本人观察，待回应数归零。')
              .fontSize(AppTheme.font.caption)
              .lineHeight(16)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: AppTheme.spacing.s2 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    AppDestination({
      route: 'relation',
      title: '关系层',
      content: () => {
        this.relationListBody();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.refresh();
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }

  @Builder
  relationListBody() {
      Column() {
        Column() {
          this.headerCard()
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: AppTheme.spacing.s12 })

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
        .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: AppTheme.spacing.s10 })

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
              hint: '先记下一个人的化名，再把他者的纠正写进详情页',
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
              }, (item: RelationListItem) => `${item.id}_${this.listVersion}`)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s16 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }
}
