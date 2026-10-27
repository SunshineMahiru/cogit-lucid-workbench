import { Anchor } from '../model/Anchor';
import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { ReviewAgentPanel } from '../components/ReviewAgentPanel';
import { ReviewService } from '../review';

/** Standalone agent workspace; the same panel is embedded in the contradiction step. */
@ComponentV2
export struct ReviewAgentPage {
  @Local facts: string = '';
  @Local interpretation: string = '';
  @Local notes: string = '';
  @Local anchors: Anchor[] = [];

  aboutToAppear(): void {
    this.loadAnchors();
  }

  private async loadAnchors(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return;
    }
    try {
      const service = await ReviewService.open(hostContext);
      this.anchors = await service.loadAnchors(3);
    } catch (error) {
      this.anchors = [];
    }
  }

  private appendNotes(text: string): void {
    const current = this.notes.trim();
    this.notes = current.length > 0 ? `${current}\n${text}` : text;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text('先写事实与解释，再让 Agent 找差距；结果只作提示，不替代你的判断。')
            .fontSize(11)
            .lineHeight(18)
            .fontColor(AppTheme.color.textSecondary)
            .width('100%')

          SectionCard() {
            Column({ space: 6 }) {
              Text('事实')
                .fontSize(11)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              TextArea({ text: this.facts, placeholder: '实际发生了什么？只写可核对的部分' })
                .height(96)
                .backgroundColor('#F7F6F2')
                .onChange((value: string) => {
                  this.facts = value;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 6 }) {
              Text('解释')
                .fontSize(11)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              TextArea({ text: this.interpretation, placeholder: '我当时怎么解释这些事？' })
                .height(96)
                .backgroundColor('#F7F6F2')
                .onChange((value: string) => {
                  this.interpretation = value;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          SectionCard() {
            Column({ space: 6 }) {
              Text(`参考锚点 ${this.anchors.length} 条`)
                .fontSize(11)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              if (this.anchors.length === 0) {
                Text('暂无锚点，Agent 只会基于事实与解释给提示')
                  .fontSize(10)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              } else {
                ForEach(this.anchors, (anchor: Anchor) => {
                  Text(`· ${anchor.text}`)
                    .fontSize(12)
                    .lineHeight(19)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                }, (anchor: Anchor) => anchor.id)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          ReviewAgentPanel({
            facts: this.facts,
            interpretation: this.interpretation,
            anchors: this.anchors,
            onInsert: (text: string) => {
              this.appendNotes(text);
            }
          })

          SectionCard() {
            Column({ space: 6 }) {
              Text('整理结果')
                .fontSize(11)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
              TextArea({ text: this.notes, placeholder: '填入的提示会追加到这里，可再改写' })
                .height(140)
                .backgroundColor('#F7F6F2')
                .onChange((value: string) => {
                  this.notes = value;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .padding(AppTheme.spacing.page)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(AppTheme.color.page)
    }
    .title('复盘 Agent')
  }
}
