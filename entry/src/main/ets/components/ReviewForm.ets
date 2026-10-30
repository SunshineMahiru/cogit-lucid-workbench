import { Anchor } from '../model/Anchor';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { AppTheme } from '../theme/AppTheme';
import { formatHitRate } from '../model/HomeModel';
import { ReviewPromptPanel } from './ReviewPromptPanel';
import { ReviewAgentPanel } from './ReviewAgentPanel';
import {
  ReviewDraft,
  ReviewService,
  ReviewStats,
  emptyReviewStats
} from '../review';
import { PREVIEW_ANCHORS, PREVIEW_REVIEW_STATS } from '../preview/PreviewData';
import { previewStore } from '../preview/PreviewStore';
import { ReviewDraftStore } from '../review/ReviewDraftStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

const STEP_LABELS: string[] = ['事实', '解释', '矛盾', '行动'];
const STEP_HINTS: string[] = [
  '这段时间实际发生了什么？先只写事实，不写评价。',
  '我当时怎么解释这些事？把解释单独拎出来。',
  '解释和事实哪里对不上？对照下面的价值锚点。',
  '下一次遇到类似情况，准备怎么做？'
];
const STEP_PLACEHOLDERS: string[] = [
  '例如：连续四天睡不到 7 小时，周三临时改期两次。',
  '例如：我把它归因于「最近状态差」，但没有具体证据。',
  '例如：锚点说「先记录，再解释」，我却先下了结论。',
  '例如：晚上十点后不再安排需要集中注意力的事。'
];

/** Four-step review form for one period; each tab owns its own draft. */
@ComponentV2
export struct ReviewForm {
  @Param period: ReviewPeriod = ReviewPeriod.WEEK;
  @Local stats: ReviewStats = emptyReviewStats();
  @Local anchors: Anchor[] = [];
  @Local step: number = 0;
  @Local facts: string = '';
  @Local interpretation: string = '';
  @Local contradiction: string = '';
  @Local action: string = '';
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local saved: boolean = false;
  @Local selectedAnchorIds: string[] = [];
  @Local isPreview: boolean = false;
  private service: ReviewService | null = null;
  private draftStore: ReviewDraftStore | null = null;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.persistDraft();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await ReviewService.open(hostContext);
      this.draftStore = await ReviewDraftStore.open(hostContext);
      this.stats = await this.service.loadStats(this.period);
      this.anchors = await this.service.loadAnchors(3);
      this.selectedAnchorIds = this.anchors.map((anchor: Anchor) => anchor.id);
      const draft = await this.draftStore.load(this.period);
      if (draft !== null) {
        this.facts = draft.facts;
        this.interpretation = draft.interpretation;
        this.contradiction = draft.contradiction;
        this.action = draft.action;
        if (draft.anchorIds.length > 0) {
          this.selectedAnchorIds = draft.anchorIds.slice();
        }
      }
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '复盘数据加载失败' });
    }
  }

  private persistDraft(): void {
    if (this.draftStore === null) {
      return;
    }
    const draft: ReviewDraft = {
      facts: this.facts,
      interpretation: this.interpretation,
      contradiction: this.contradiction,
      action: this.action,
      anchorIds: this.selectedAnchorIds.slice()
    };
    this.draftStore.save(this.period, draft).catch(() => {
    });
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.stats = PREVIEW_REVIEW_STATS;
    this.anchors = PREVIEW_ANCHORS.slice(0, 3);
    this.selectedAnchorIds = this.anchors.map((anchor: Anchor) => anchor.id);
    this.isLoading = false;
  }

  private currentText(): string {
    if (this.step === 0) {
      return this.facts;
    }
    if (this.step === 1) {
      return this.interpretation;
    }
    if (this.step === 2) {
      return this.contradiction;
    }
    return this.action;
  }

  private updateCurrent(value: string): void {
    if (this.step === 0) {
      this.facts = value;
    } else if (this.step === 1) {
      this.interpretation = value;
    } else if (this.step === 2) {
      this.contradiction = value;
    } else {
      this.action = value;
    }
    this.persistDraft();
  }

  private appendContradiction(text: string): void {
    const current = this.contradiction.trim();
    this.contradiction = current.length > 0 ? `${current}\n${text}` : text;
    this.persistDraft();
  }

  private isAnchorSelected(id: string): boolean {
    return this.selectedAnchorIds.includes(id);
  }

  private toggleAnchor(id: string): void {
    if (this.isAnchorSelected(id)) {
      this.selectedAnchorIds = this.selectedAnchorIds.filter((item: string) => item !== id);
    } else {
      this.selectedAnchorIds = this.selectedAnchorIds.concat([id]);
    }
    this.persistDraft();
  }

  private async complete(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.facts.trim().length === 0) {
      this.step = 0;
      this.getUIContext().getPromptAction().showToast({ message: '先写下这一期的事实' });
      return;
    }
    if (this.action.trim().length === 0) {
      this.step = 3;
      this.getUIContext().getPromptAction().showToast({ message: '补一条下一步行动' });
      return;
    }
    if (this.isPreview) {
      const draft: ReviewDraft = {
        facts: this.facts,
        interpretation: this.interpretation,
        contradiction: this.contradiction,
        action: this.action,
        anchorIds: this.selectedAnchorIds.slice()
      };
      previewStore.saveReview(this.period, draft, this.stats.rangeLabel);
      notifyHomeRefresh();
      this.saved = true;
      this.getUIContext().getPromptAction().showToast({ message: '演示模式：复盘已保存在当前会话' });
      return;
    }
    if (this.service === null) {
      this.getUIContext().getPromptAction().showToast({ message: '数据库尚未就绪' });
      return;
    }
    this.isSaving = true;
    try {
      const draft: ReviewDraft = {
        facts: this.facts,
        interpretation: this.interpretation,
        contradiction: this.contradiction,
        action: this.action,
        anchorIds: this.selectedAnchorIds.slice()
      };
      await this.service.save(this.period, draft, this.stats.rangeLabel);
      if (this.draftStore !== null) {
        await this.draftStore.clear(this.period);
      }
      notifyHomeRefresh();
      this.saved = true;
      this.getUIContext().getPromptAction().showToast({ message: '复盘已保存' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private restart(): void {
    this.step = 0;
    this.facts = '';
    this.interpretation = '';
    this.contradiction = '';
    this.action = '';
    this.saved = false;
    if (this.draftStore !== null) {
      this.draftStore.clear(this.period).catch(() => {
      });
    }
    this.load();
  }

  @Builder
  statItem(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text(label)
        .fontSize(10)
        .fontColor(AppTheme.color.textSecondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  stepDots() {
    Row({ space: 6 }) {
      ForEach(STEP_LABELS, (label: string, index: number) => {
        Row({ space: 4 }) {
          Text(String(index + 1))
            .fontSize(10)
            .fontColor(index <= this.step ? Color.White : AppTheme.color.textSecondary)
            .width(18)
            .height(18)
            .textAlign(TextAlign.Center)
            .lineHeight(18)
            .backgroundColor(index <= this.step ? AppTheme.color.primary : AppTheme.color.tint)
            .borderRadius(9)
          Text(label)
            .fontSize(11)
            .fontColor(index === this.step ? AppTheme.color.text : AppTheme.color.textSecondary)
        }
        .margin({ right: 8 })
      }, (label: string) => label)
    }
    .width('100%')
  }

  build() {
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
      } else if (this.saved) {
        Column({ space: 12 }) {
          Text('本期复盘已完成')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text(this.stats.rangeLabel)
            .fontSize(12)
            .fontColor(AppTheme.color.textSecondary)
          Text(this.action)
            .fontSize(14)
            .lineHeight(22)
            .fontColor(AppTheme.color.text)
            .textAlign(TextAlign.Center)
          Text('再写一条')
            .fontSize(13)
            .fontColor(AppTheme.color.primary)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(16)
            .margin({ top: 8 })
            .onClick(() => {
              this.restart();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(24)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 8 }) {
              Row() {
                Text(this.period === ReviewPeriod.WEEK ? '本周' : '本月')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.color.text)
                Blank()
                Text(this.stats.rangeLabel)
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
              }
              .width('100%')

              Row() {
                this.statItem(String(this.stats.noteCount), '速记')
                this.statItem(String(this.stats.decisionCount), '决策')
                this.statItem(String(this.stats.settledPredictions), '已结算')
                this.statItem(formatHitRate(this.stats.hitRate, this.stats.settledPredictions), '命中率')
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(12)

            this.stepDots()

            if (this.step === 0) {
              ReviewPromptPanel({ period: this.period })
            }

            Text(`${this.step + 1}. ${STEP_LABELS[this.step]}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.color.text)
              .width('100%')
            Text(STEP_HINTS[this.step])
              .fontSize(12)
              .lineHeight(18)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')

            if (this.step === 2 && this.anchors.length > 0) {
              Column({ space: 8 }) {
                Text('对照锚点 · 点击选择本次真正用到的')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                ForEach(this.anchors, (anchor: Anchor) => {
                  Column({ space: 4 }) {
                    Row() {
                      Text(anchor.text)
                        .fontSize(13)
                        .lineHeight(20)
                        .fontColor(AppTheme.color.text)
                        .layoutWeight(1)
                      if (this.isAnchorSelected(anchor.id)) {
                        Text('已对照')
                          .fontSize(9)
                          .fontColor(AppTheme.color.primary)
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .backgroundColor(AppTheme.color.tint)
                          .borderRadius(6)
                      }
                    }
                    .width('100%')
                    Text(anchor.source)
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                  .width('100%')
                  .padding(10)
                  .backgroundColor(this.isAnchorSelected(anchor.id) ? AppTheme.color.selectedSurface : AppTheme.color.surfaceWarm)
                  .borderRadius(8)
                  .border({
                    width: this.isAnchorSelected(anchor.id) ? 1 : 0,
                    color: AppTheme.color.borderSelected
                  })
                  .onClick(() => {
                    this.toggleAnchor(anchor.id);
                  })
                }, (anchor: Anchor) => anchor.id)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.color.surfaceWarm)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }

            if (this.step === 2) {
              ReviewAgentPanel({
                facts: this.facts,
                interpretation: this.interpretation,
                anchors: this.anchors,
                onInsert: (text: string) => {
                  this.appendContradiction(text);
                }
              })
            }

            TextArea({ text: this.currentText(), placeholder: STEP_PLACEHOLDERS[this.step] })
              .fontSize(13)
              .height(180)
              .padding(12)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(12)
              .border({ width: 0.5, color: AppTheme.color.border })
              .onChange((value: string) => {
                this.updateCurrent(value);
              })
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        Row({ space: 12 }) {
          if (this.step > 0) {
            Text('上一步')
              .fontSize(14)
              .fontColor(AppTheme.color.textSecondaryStrong)
              .padding({ left: 20, right: 20, top: 11, bottom: 11 })
              .backgroundColor(AppTheme.color.chip)
              .borderRadius(12)
              .onClick(() => {
                this.step -= 1;
              })
          }
          Blank()
          Text(this.step < 3 ? '下一步' : '完成复盘')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: 24, right: 24, top: 11, bottom: 11 })
            .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
            .borderRadius(12)
            .accessibilityText(this.step < 3 ? '进入下一步' : '完成复盘')
            .onClick(() => {
              if (this.isSaving) {
                return;
              }
              if (this.step < 3) {
                this.step += 1;
              } else {
                this.complete();
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
