import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';
import { ReviewPeriod } from '../model/ReviewPeriod';
import {
  HttpReviewPromptRepository,
  ReviewPrompt,
  ReviewPromptRepository
} from '../network';

const STATE_LOADING = 'loading';
const STATE_READY = 'ready';
const STATE_EMPTY = 'empty';
const STATE_ERROR = 'error';

/** Fetches review prompts with explicit loading, empty, error and ready states. */
@ComponentV2
export struct ReviewPromptPanel {
  @Param period: ReviewPeriod = ReviewPeriod.WEEK;
  @Local state: string = STATE_LOADING;
  @Local prompts: ReviewPrompt[] = [];
  private repository: ReviewPromptRepository = new HttpReviewPromptRepository();

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.state = STATE_LOADING;
    try {
      const prompts = await this.repository.fetch(this.period);
      this.prompts = prompts;
      this.state = prompts.length > 0 ? STATE_READY : STATE_EMPTY;
    } catch (error) {
      this.state = STATE_ERROR;
    }
  }

  build() {
    SectionCard() {
      Column({ space: 8 }) {
        Row() {
          Text('本期提示')
            .fontSize(11)
            .fontColor(AppTheme.color.textSecondary)
          Blank()
          Text('本地 Mock')
            .fontSize(10)
            .fontColor(AppTheme.color.textMuted)
        }
        .width('100%')

        if (this.state === STATE_LOADING) {
          Row({ space: 6 }) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color(AppTheme.color.primary)
            Text('正在获取提示…')
              .fontSize(11)
              .fontColor(AppTheme.color.textMuted)
          }
        } else if (this.state === STATE_ERROR) {
          Row({ space: 8 }) {
            Text('提示加载失败')
              .fontSize(11)
              .fontColor(AppTheme.color.danger)
            Blank()
            Text('重试')
              .fontSize(11)
              .fontColor(AppTheme.color.primary)
              .onClick(() => {
                this.load();
              })
          }
          .width('100%')
        } else if (this.state === STATE_EMPTY) {
          Text('暂无提示，稍后再试')
            .fontSize(11)
            .fontColor(AppTheme.color.textMuted)
        } else {
          ForEach(this.prompts, (prompt: ReviewPrompt) => {
            Text(`· ${prompt.text}`)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(AppTheme.color.text)
              .width('100%')
          }, (prompt: ReviewPrompt) => prompt.id)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
