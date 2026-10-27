import { BodyReading, PredictionItem, HomeSummary, todayLabel } from '../model/HomeModel';
import { HomeDataService } from '../model/HomeDataService';
import { PredictionCard } from '../components/PredictionCard';
import { ReadingCard } from '../components/ReadingCard';
import { EntryChip } from '../components/EntryChip';
import { NoteCard } from '../components/NoteCard';
import { NoteListItem } from '../note/NoteListItem';
import { promptAction } from '@kit.ArkUI';

/** Dashboard content: readings first, then module entries and the two recent lists. */
@ComponentV2
export struct DashboardView {
  @Local today: string = todayLabel();
  @Local readings: BodyReading[] = [];
  @Local predictions: PredictionItem[] = [];
  @Local recentNotes: NoteListItem[] = [];
  @Local summary: HomeSummary = {
    totalNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0, hitRate: 0
  };
  @Local dataService: HomeDataService | null = null;
  @Local isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    this.dataService = await HomeDataService.open(getContext(this));
    await this.refresh();
  }

  async refresh(): Promise<void> {
    if (this.dataService === null) {
      return;
    }
    this.isLoading = true;
    this.readings = await this.dataService.loadReadings();
    this.predictions = await this.dataService.loadPendingPredictions();
    this.recentNotes = await this.dataService.loadRecentNotes();
    this.summary = await this.dataService.loadSummary();
    this.isLoading = false;
  }

  @Builder
  loadingView() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color('#4A6FA5')
      Text('加载中...')
        .fontSize(14)
        .fontColor('#8A8F99')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  emptyPredictionsView() {
    Column({ space: 8 }) {
      Text('暂无待结算预测')
        .fontSize(14)
        .fontColor('#8A8F99')
      Text('点击「预测」快捷入口创建一条')
        .fontSize(12)
        .fontColor('#B0B4BE')
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  emptyNotesView() {
    Column({ space: 8 }) {
      Text('暂无速记')
        .fontSize(14)
        .fontColor('#8A8F99')
      Text('点击「速记」快捷入口开始记录')
        .fontSize(12)
        .fontColor('#B0B4BE')
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column({ space: 4 }) {
          Text('此在')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F2329')
          Text(this.today)
            .fontSize(12)
            .fontColor('#8A8F99')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 12 }) {
          Text(`${this.predictions.length} 条待结算`)
            .fontSize(12)
            .fontColor('#4A6FA5')
          Text('↻ 刷新')
            .fontSize(12)
            .fontColor('#4A6FA5')
            .onClick(() => {
              this.refresh();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      .border({ width: { bottom: 0.5 }, color: '#E0E0E0' })

      if (this.isLoading) {
        this.loadingView()
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 读数区
            Grid() {
              ForEach(this.readings, (reading: BodyReading) => {
                GridItem() {
                  ReadingCard({ reading: reading })
                }
              }, (reading: BodyReading) => reading.label)
            }
            .columnsTemplate('1fr 1fr 1fr')
            .rowsGap(0)
            .columnsGap(0)
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(14)

            // 统计摘要
            Row() {
              Column({ space: 4 }) {
                Text(String(this.summary.totalNotes))
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2329')
                Text('总速记')
                  .fontSize(11)
                  .fontColor('#8A8F99')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Column({ space: 4 }) {
                Text(String(this.summary.pendingPredictions))
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2329')
                Text('待结算')
                  .fontSize(11)
                  .fontColor('#8A8F99')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Column({ space: 4 }) {
                Text(`${this.summary.hitRate}%`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#4A6FA5')
                Text('命中率')
                  .fontSize(11)
                  .fontColor('#8A8F99')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(14)

            // 快捷入口
            Column({ space: 10 }) {
              Text('快捷入口')
                .fontSize(12)
                .fontColor('#8A8F99')
                .width('100%')
                .textAlign(TextAlign.Start)
              Row({ space: 10 }) {
                EntryChip({
                  label: '速记',
                  onTap: () => {
                    promptAction.showToast({ message: '速记页面开发中' });
                  }
                })
                EntryChip({
                  label: '预测',
                  onTap: () => {
                    promptAction.showToast({ message: '预测页面开发中' });
                  }
                })
                EntryChip({
                  label: '复盘',
                  onTap: () => {
                    promptAction.showToast({ message: '复盘页面开发中' });
                  }
                })
                EntryChip({
                  label: '锚点',
                  onTap: () => {
                    promptAction.showToast({ message: '锚点页面开发中' });
                  }
                })
              }
              .width('100%')
              Row({ space: 10 }) {
                EntryChip({
                  label: '状态',
                  onTap: () => {
                    promptAction.showToast({ message: '状态页面开发中' });
                  }
                }).layoutWeight(1)
                EntryChip({
                  label: '关系',
                  onTap: () => {
                    promptAction.showToast({ message: '关系页面开发中' });
                  }
                }).layoutWeight(1)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(14)

            // 最近速记
            Column({ space: 10 }) {
              Row() {
                Text('最近速记')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2329')
                Blank()
                Text('全部')
                  .fontSize(12)
                  .fontColor('#8A8F99')
              }
              .width('100%')

              if (this.recentNotes.length === 0) {
                this.emptyNotesView()
              } else {
                List({ space: 8 }) {
                  ForEach(this.recentNotes, (note: NoteListItem) => {
                    ListItem() {
                      NoteCard({
                        note: note,
                        onTap: () => {
                          promptAction.showToast({ message: `速记: ${note.title}` });
                        }
                      })
                    }
                  }, (note: NoteListItem) => note.id)
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(14)

            // 待结算预测
            Column({ space: 10 }) {
              Row() {
                Text('今日待结算')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2329')
                Blank()
                Text('全部')
                  .fontSize(12)
                  .fontColor('#8A8F99')
              }
              .width('100%')

              if (this.predictions.length === 0) {
                this.emptyPredictionsView()
              } else {
                List({ space: 10 }) {
                  ForEach(this.predictions, (item: PredictionItem) => {
                    ListItem() {
                      PredictionCard({
                        item: item,
                        onTap: () => {
                          promptAction.showToast({ message: `预测: ${item.title}` });
                        }
                      })
                    }
                  }, (item: PredictionItem) => item.id)
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 34 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
