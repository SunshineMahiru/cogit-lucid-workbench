import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { StatusDayRow } from '../components/StatusDayRow';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { StatusDayRow as StatusRow, StatusService } from '../status';

/** Full status history, newest first. */
@ComponentV2
export struct StatusHistoryPage {
  @Local service: StatusService | null = null;
  @Local rows: StatusRow[] = [];
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
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
      this.service = await StatusService.open(hostContext);
      this.rows = await this.service.history();
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '历史读数加载失败' });
    }
  }

  private async refresh(): Promise<void> {
    if (this.service === null) {
      return;
    }
    this.isLoading = true;
    try {
      this.rows = await this.service.history();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '历史读数加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private async seed(): Promise<void> {
    if (this.service === null || this.isSeeding) {
      return;
    }
    this.isSeeding = true;
    try {
      const added = await this.service.seedDemoRecords();
      await this.refresh();
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已载入 ${added} 天示例读数` : '已有读数，未重复载入'
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '载入失败，请重试' });
    } finally {
      this.isSeeding = false;
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
        } else if (this.rows.length === 0) {
          Column() {
            NoteEmptyState({
              title: '还没有历史读数',
              hint: '示例数据仅用于演示，可在状态面板或这里载入',
              actionLabel: this.isSeeding ? '载入中…' : '载入示例读数',
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
            Column({ space: 8 }) {
              ForEach(this.rows, (row: StatusRow) => {
                SectionCard() {
                  StatusDayRow({ row: row })
                }
              }, (row: StatusRow) => row.id)
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
    .title('状态历史')
    .onShown(() => {
      if (this.hasShownOnce) {
        this.refresh();
      } else {
        this.hasShownOnce = true;
      }
    })
  }
}
