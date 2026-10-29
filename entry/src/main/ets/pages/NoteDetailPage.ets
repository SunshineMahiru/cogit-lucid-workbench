import { NoteDetail, QuickNoteService, securityLevelText } from '../note';
import { NoteDetailParams } from '../navigation/RouteParams';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { previewStore } from '../preview/PreviewStore';

/** Read-only view of one stored note. */
@ComponentV2
export struct NoteDetailPage {
  @Local detail: NoteDetail | null = null;
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  private navStack: NavPathStack | null = null;

  private async load(noteId: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview(noteId);
      return;
    }
    try {
      const service = await QuickNoteService.open(hostContext);
      this.detail = await service.findNote(noteId);
      this.missing = this.detail === null;
    } catch (error) {
      this.loadPreview(noteId);
    } finally {
      this.isLoading = false;
    }
  }

  private loadPreview(noteId: string): void {
    this.detail = previewStore.findNote(noteId);
    this.missing = this.detail === null;
    this.isLoading = false;
  }

  build() {
    NavDestination() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color('#4A6FA5')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F5F6F8')
      } else if (this.missing || this.detail === null) {
        Column() {
          NoteEmptyState({
            title: '记录不存在',
            hint: '可能已经被删除',
            actionLabel: '返回',
            onAction: () => {
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F5F6F8')
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text(this.detail.type)
                .fontSize(10)
                .fontColor('#4A6FA5')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('#E8EFF7')
                .borderRadius(8)
              Text(this.detail.timeLabel)
                .fontSize(11)
                .fontColor('#B0B4BE')
              Blank()
              Text(securityLevelText(this.detail.level))
                .fontSize(11)
                .fontColor('#8A8F99')
            }
            .width('100%')

            Text(this.detail.title)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F2329')
              .width('100%')

            if (this.detail.tags.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.detail.tags, (tag: string) => {
                  Text(tag)
                    .fontSize(11)
                    .fontColor('#185FA5')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor('#E8EFF7')
                    .borderRadius(10)
                    .margin({ right: 6, bottom: 6 })
                }, (tag: string) => tag)
              }
              .width('100%')
            }

            Text(this.detail.content)
              .fontSize(14)
              .lineHeight(24)
              .fontColor('#1F2329')
              .width('100%')
          }
          .width('100%')
          .padding(20)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor('#F5F6F8')
      }
    }
    .title('速记详情')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param === undefined) {
        this.isLoading = false;
        this.missing = true;
        return;
      }
      const params = context.pathInfo.param as NoteDetailParams;
      this.load(params.noteId);
    })
  }
}
