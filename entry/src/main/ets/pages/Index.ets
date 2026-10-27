import { BodyReading, PredictionItem, todayLabel } from '../model/HomeModel';
import { HomeDataService } from '../model/HomeDataService';
import { PredictionCard } from '../components/PredictionCard';

@Entry
@ComponentV2
struct Index {
  @Local today: string = todayLabel();
  @Local readings: BodyReading[] = [];
  @Local predictions: PredictionItem[] = [];
  @Local dataService: HomeDataService | null = null;

  async aboutToAppear(): Promise<void> {
    this.dataService = await HomeDataService.open(getContext(this));
    await this.refresh();
  }

  async refresh(): Promise<void> {
    if (this.dataService === null) {
      return;
    }
    this.readings = await this.dataService.loadReadings();
    this.predictions = await this.dataService.loadPendingPredictions();
  }

  @Builder
  readingBlock(reading: BodyReading) {
    Column({ space: 6 }) {
      Text(reading.value + reading.unit)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2329')
      Text(reading.label)
        .fontSize(12)
        .fontColor('#8A8F99')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  entryChip(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor('#1F2329')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(Color.White)
      .borderRadius(16)
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column({ space: 4 }) {
          Text('cogit-lucid-workbench')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2329')
          Text(this.today)
            .fontSize(12)
            .fontColor('#8A8F99')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(`${this.predictions.length} 条待结算`)
          .fontSize(12)
          .fontColor('#4A6FA5')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      Column({ space: 16 }) {
        // 读数区
        Row() {
          ForEach(this.readings, (reading: BodyReading) => {
            this.readingBlock(reading)
          }, (reading: BodyReading) => reading.label)
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
            this.entryChip('速记')
            this.entryChip('预测')
            this.entryChip('复盘')
            this.entryChip('锚点')
          }
          .width('100%')
        }

        // 列表标题
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

        // 待结算列表
        List({ space: 10 }) {
          ForEach(this.predictions, (item: PredictionItem) => {
            ListItem() {
              PredictionCard({ item: item })
            }
          }, (item: PredictionItem) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 20, right: 20, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
