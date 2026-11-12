import { Anchor } from '../model/Anchor';
import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { AnchorService } from '../anchor';
import { AnchorCard } from '../components/AnchorCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ROUTES } from '../navigation/Routes';
import { PlanAttachParams } from '../navigation/RouteParams';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PREVIEW_ANCHORS } from '../preview/PreviewData';
import { PREVIEW_WRITE_BLOCKED } from '../preview/PreviewMode';

/** Read-only value anchor library with a shortcut into the review flow. */
@ComponentV2
export struct AnchorPage {
  @Local service: AnchorService | null = null;
  @Local anchors: Anchor[] = [];
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  @Local isPreview: boolean = false;
  @Local newAnchorText: string = '';
  @Local isAdding: boolean = false;
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
      this.service = await AnchorService.open(hostContext);
      this.anchors = await this.service.list();
      this.isLoading = false;
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '锚点加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.anchors = PREVIEW_ANCHORS.slice();
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
      const added = await this.service.seedDemoAnchors();
      this.anchors = await this.service.list();
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已载入 ${added} 条示例锚点` : '已有锚点，未重复载入'
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '载入失败，请重试' });
    } finally {
      this.isSeeding = false;
    }
  }

  private async addAnchor(): Promise<void> {
    const text = this.newAnchorText.trim();
    if (text.length === 0 || this.isAdding) {
      return;
    }
    this.isAdding = true;
    try {
      if (this.isPreview) {
        const next = this.anchors.slice();
        next.push({
          id: `local_anchor_${Date.now()}`,
          text: text,
          source: '自写',
          order: next.length
        });
        this.anchors = next;
      } else if (this.service !== null) {
        await this.service.create(text);
        this.anchors = await this.service.list();
      }
      this.newAnchorText = '';
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '锚点保存失败，请重试' });
    } finally {
      this.isAdding = false;
    }
  }

  private openReview(): void {
    if (this.navStack === null) {
      return;
    }
    this.navStack.pushPathByName(ROUTES.REVIEW, null);
  }

  private openAttach(anchor: Anchor): void {
    if (this.navStack === null) {
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.ANCHOR,
      targetId: anchor.id,
      label: anchor.text
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  @Builder
  headerCard() {
    Column({ space: 6 }) {
      Row() {
        Text('北极星句段库')
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Blank()
        Text(`${this.anchors.length} 条`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
      }
      .width('100%')

      Text('复盘第三步用来对照的稳定句子；新建后只读。')
        .fontSize(AppTheme.font.bodyStrong)
        .lineHeight(18)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.newAnchorText, placeholder: '写一条自己的锚点' })
          .id('anchor_input')
          .maxLength(80)
          .layoutWeight(1)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .onChange((value: string) => {
            this.newAnchorText = value;
          })
        Text(this.isAdding ? '保存中' : '添加')
          .id('anchor_add')
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.addAnchor();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    AppDestination({
      route: 'anchor',
      title: '价值锚点',
      content: () => {
        this.anchorBody();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
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

  @Builder
  anchorBody() {
      Column() {
        Column() {
          this.headerCard()
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s12 })

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
        } else if (this.anchors.length === 0) {
          Column() {
            NoteEmptyState({
              title: '锚点库还是空的',
              hint: '锚点用于复盘时对照；示例数据仅用于演示',
              actionLabel: this.isSeeding ? '载入中…' : '载入示例锚点',
              dashed: true,
              onAction: () => {
                this.seed();
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16 })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.anchors, (anchor: Anchor, index: number) => {
                AnchorCard({
                  anchor: anchor,
                  index: index + 1,
                  onAttachPlan: () => {
                    this.openAttach(anchor);
                  }
                })
              }, (anchor: Anchor) => anchor.id)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })

          Column() {
            Text('用它做一次复盘')
              .fontSize(AppTheme.font.subtitle)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(AppTheme.color.primary)
              .borderRadius(AppTheme.radius.md)
              .onClick(() => {
                this.openReview();
              })
          }
          .width('100%')
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, bottom: AppTheme.spacing.s24, top: AppTheme.spacing.s4 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
  }
}
