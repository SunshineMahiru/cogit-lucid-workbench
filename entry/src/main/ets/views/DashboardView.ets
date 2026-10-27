import { BodyReading, HomeModule, HomeSummary, PredictionItem, todayLabel } from '../model/HomeModel';
import { HomeDataService } from '../model/HomeDataService';
import { ModuleCard } from '../components/ModuleCard';
import { PredictionCard } from '../components/PredictionCard';
import { ReadingCard } from '../components/ReadingCard';
import { NoteCard } from '../components/NoteCard';
import { NoteListItem } from '../note/NoteListItem';
import { NoteEditParams, PredictionDetailParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';

/** Dashboard content: readings first, then module tiles and the two recent lists. */
@ComponentV2
export struct DashboardView {
  @Require @Param pathStack: NavPathStack;
  @Local today: string = todayLabel();
  @Local readings: BodyReading[] = [];
  @Local predictions: PredictionItem[] = [];
  @Local recentNotes: NoteListItem[] = [];
  @Local summary: HomeSummary = {
    totalNotes: 0, totalPredictions: 0, pendingPredictions: 0, settledPredictions: 0, hitRate: 0,
    unreviewedDecisions: 0, totalAnchors: 0, totalRelations: 0
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

  private modules(): HomeModule[] {
    const sleep = this.readings.length > 0 ? this.readings[0].value : '--';
    return [
      {
        route: ROUTES.NOTE_EDIT,
        icon: '📝',
        title: '速记',
        summary: `共 ${this.summary.totalNotes} 条`
      },
      {
        route: ROUTES.PREDICTION_LIST,
        icon: '🔮',
        title: '预测',
        summary: `待结算 ${this.summary.pendingPredictions} · 命中 ${this.summary.hitRate}%`
      },
      {
        route: ROUTES.REVIEW,
        icon: '🔄',
        title: '复盘',
        summary: `待复盘 ${this.summary.unreviewedDecisions} 条`
      },
      {
        route: ROUTES.ANCHOR,
        icon: '⭐',
        title: '锚点',
        summary: `共 ${this.summary.totalAnchors} 条`
      },
      {
        route: ROUTES.STATUS,
        icon: '📊',
        title: '状态',
        summary: `睡眠 ${sleep} 小时`
      },
      {
        route: ROUTES.RELATION,
        icon: '🔗',
        title: '关系',
        summary: `共 ${this.summary.totalRelations} 人`
      }
    ];
  }

  private openNoteEditor(): void {
    const params: NoteEditParams = { templateId: null };
    this.pathStack.pushPathByName(ROUTES.NOTE_EDIT, params);
  }

  private openPredictionDetail(predictionId: string): void {
    const params: PredictionDetailParams = { predictionId: predictionId };
    this.pathStack.pushPathByName(ROUTES.PREDICTION_DETAIL, params);
  }

  private openModule(route: string): void {
    if (route === ROUTES.NOTE_EDIT) {
      this.openNoteEditor();
      return;
    }
    this.pathStack.pushPathByName(route, null);
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
      Text('点击「预测」模块创建一条')
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
      Text('点击「速记」模块开始记录')
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
        Stack({ alignContent: Alignment.BottomEnd }) {
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

              // 模块入口
              Column({ space: 10 }) {
                Text('模块入口')
                  .fontSize(12)
                  .fontColor('#8A8F99')
                  .width('100%')
                  .textAlign(TextAlign.Start)
                Grid() {
                  ForEach(this.modules(), (module: HomeModule) => {
                    GridItem() {
                      ModuleCard({
                        icon: module.icon,
                        title: module.title,
                        summary: module.summary,
                        onTap: () => {
                          this.openModule(module.route);
                        }
                      })
                    }
                  }, (module: HomeModule) => module.route)
                }
                .columnsTemplate('1fr 1fr')
                .columnsGap(10)
                .rowsGap(10)
                .width('100%')
                .height(266)
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
                    .onClick(() => {
                      this.pathStack.pushPathByName(ROUTES.NOTE_LIST, null);
                    })
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
                            this.pathStack.pushPathByName(ROUTES.NOTE_LIST, null);
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
                    .onClick(() => {
                      this.pathStack.pushPathByName(ROUTES.PREDICTION_LIST, null);
                    })
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
                            this.openPredictionDetail(item.id);
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
            .padding({ left: 20, right: 20, bottom: 96 })
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Auto)

          // 常驻速记入口，保证任何位置都能一条点击进入编辑
          Text('＋ 速记')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .backgroundColor('#4A6FA5')
            .borderRadius(24)
            .margin({ right: 20, bottom: 24 })
            .onClick(() => {
              this.openNoteEditor();
            })
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
