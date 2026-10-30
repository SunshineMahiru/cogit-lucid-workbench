import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';
import { ReviewPeriod } from '../model/ReviewPeriod';
import {
  API_BASE_URL,
  HttpClient,
  HttpReviewPromptRepository,
  ReviewPrompt,
  ReviewPromptRepository
} from '../network';
import { SettingsStore } from '../settings';

const STATE_LOADING = 'loading';
const STATE_READY = 'ready';
const STATE_EMPTY = 'empty';
const STATE_ERROR = 'error';

const LOCAL_PROMPTS: ReviewPrompt[] = [
  { id: 'local_1', text: '这一周哪件事最消耗你？', category: 'energy' },
  { id: 'local_2', text: '哪次判断事后被证明是对的？', category: 'judgement' },
  { id: 'local_3', text: '如果重来一次，你会先确认什么？', category: 'action' }
];

/** Fetches review prompts with explicit loading, empty, error and ready states. */
@ComponentV2
export struct ReviewPromptPanel {
  @Param period: ReviewPeriod = ReviewPeriod.WEEK;
  @Local state: string = STATE_LOADING;
  @Local prompts: ReviewPrompt[] = [];
  private repository: ReviewPromptRepository = new HttpReviewPromptRepository();

  aboutToAppear(): void {
    this.prepareRepository();
  }

  private async prepareRepository(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      try {
        const store = await SettingsStore.open(context);
        const settings = await store.load();
        const base = mockBaseFrom(settings.llmBaseUrl);
        if (base.length > 0) {
          this.repository = new HttpReviewPromptRepository(new HttpClient(), base);
        }
      } catch (error) {
      }
    }
    this.load();
  }

  private async load(): Promise<void> {
    this.state = STATE_LOADING;
    try {
      const prompts = await this.repository.fetch(this.period);
      this.prompts = prompts;
      this.state = prompts.length > 0 ? STATE_READY : STATE_EMPTY;
    } catch (error) {
      this.prompts = LOCAL_PROMPTS;
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
          Text(this.state === STATE_ERROR ? 'Mock 未连接' : '本地 Mock')
            .fontSize(10)
            .fontColor(this.state === STATE_ERROR ? AppTheme.color.danger : AppTheme.color.textMuted)
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
          Column({ space: 4 }) {
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
            Text(`先启动 mock-server，确认 ${API_BASE_URL}/review-prompts 可访问`)
              .fontSize(10)
              .lineHeight(15)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
            Text('当前显示本地回退提示')
              .fontSize(10)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
            ForEach(this.prompts, (prompt: ReviewPrompt) => {
              Text(`· ${prompt.text}`)
                .fontSize(12)
                .lineHeight(19)
                .fontColor(AppTheme.color.text)
                .width('100%')
            }, (prompt: ReviewPrompt) => prompt.id)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
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

function mockBaseFrom(baseUrl: string): string {
  let value = baseUrl.trim();
  if (value.endsWith('/v1')) {
    value = value.slice(0, value.length - 3);
  }
  if (value.endsWith('/')) {
    value = value.slice(0, value.length - 1);
  }
  return value;
}
