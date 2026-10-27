import { Anchor } from '../model/Anchor';
import { AnchorService } from '../anchor';
import { AnchorCard } from '../components/AnchorCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ROUTES } from '../navigation/Routes';

/** Read-only value anchor library with a shortcut into the review flow. */
@ComponentV2
export struct AnchorPage {
  @Local service: AnchorService | null = null;
  @Local anchors: Anchor[] = [];
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
      this.service = await AnchorService.open(hostContext);
      this.anchors = await this.service.list();
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '锚点加载失败' });
    }
  }

  private async seed(): Promise<void> {
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

  private openReview(): void {
    if (this.navStack === null) {
      return;
    }
    this.navStack.pushPathByName(ROUTES.REVIEW, null);
  }

  @Builder
  headerCard() {
    Column({ space: 6 }) {
      Row() {
        Text('北极星句段库')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2329')
        Blank()
        Text(`${this.anchors.length} 条`)
          .fontSize(11)
          .fontColor('#8A8F99')
      }
      .width('100%')

      Text('复盘第三步用来对照的稳定句子，只读。')
        .fontSize(12)
        .lineHeight(18)
        .fontColor('#8A8F99')
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          this.headerCard()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color('#4A6FA5')
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
          .padding({ left: 16, right: 16 })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.anchors, (anchor: Anchor, index: number) => {
                AnchorCard({ anchor: anchor, index: index + 1 })
              }, (anchor: Anchor) => anchor.id)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Column() {
            Text('用它做一次复盘')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 })
              .backgroundColor('#4A6FA5')
              .borderRadius(12)
              .onClick(() => {
                this.openReview();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24, top: 4 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F6F8')
    }
    .title('价值锚点')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
    .onShown(() => {
      if (this.hasShownOnce) {
        this.load();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
