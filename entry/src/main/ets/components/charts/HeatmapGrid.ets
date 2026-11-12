import { HeatmapData } from './ChartModels';
import { AppTheme } from '../../theme/AppTheme';

/** Calendar-style grid drawn on Canvas; the only chart type mpchart does not cover. */
@ComponentV2
export struct HeatmapGrid {
  @Param data: HeatmapData = { rows: [], columns: [], cells: [], legend: '' };
  @Param maxValue: number = 1;
  @Param gridHeight: number = 150;
  @Param showColumnLabels: boolean = true;
  @Local canvasWidth: number = 320;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @Monitor('data')
  onDataChanged(): void {
    this.draw();
  }

  private colorFor(value: number): string {
    if (value <= 0) {
      return '#EDEBE4';
    }
    const ratio = Math.min(1, value / Math.max(1, this.maxValue));
    if (ratio <= 0.34) {
      return '#B7D3E8';
    }
    if (ratio <= 0.67) {
      return '#6FA8CC';
    }
    return '#2E6F9E';
  }

  private draw(): void {
    if (this.data.rows.length === 0 || this.data.columns.length === 0) {
      return;
    }
    const width = this.canvasWidth;
    const height = this.gridHeight;
    const gap = 2;
    const cellWidth = (width - gap * (this.data.columns.length - 1)) / this.data.columns.length;
    const cellHeight = (height - gap * (this.data.rows.length - 1)) / this.data.rows.length;
    this.context.clearRect(0, 0, width, height);
    for (const cell of this.data.cells) {
      if (cell.row < 0 || cell.row >= this.data.rows.length ||
        cell.column < 0 || cell.column >= this.data.columns.length) {
        continue;
      }
      this.context.fillStyle = this.colorFor(cell.value);
      this.context.fillRect(cell.column * (cellWidth + gap), cell.row * (cellHeight + gap), cellWidth, cellHeight);
    }
  }

  build() {
    if (this.data.rows.length === 0) {
      Text('数据不足，暂不绘图')
        .fontSize(AppTheme.font.body)
        .fontColor('#6B6A63')
        .width('100%')
        .padding({ top: 16, bottom: 16 })
    } else {
      Column({ space: 4 }) {
        Row({ space: 4 }) {
          Column() {
            ForEach(this.data.rows, (label: string) => {
              Text(label)
                .fontSize(AppTheme.font.caption)
                .fontColor('#6B6A63')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
            }, (label: string) => label)
          }
          .width(16)
          .height(this.gridHeight)

          Canvas(this.context)
            .layoutWeight(1)
            .height(this.gridHeight)
            .onReady(() => {
              this.draw();
            })
            .onAreaChange((oldValue: Area, newValue: Area) => {
              const next = Number(newValue.width);
              if (!Number.isNaN(next) && next > 0) {
                this.canvasWidth = next;
                this.draw();
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.showColumnLabels) {
          Row() {
            Blank().width(20)
            ForEach(this.data.columns, (label: string) => {
              Text(label)
                .fontSize(AppTheme.font.caption)
                .fontColor('#6B6A63')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
            }, (label: string) => label)
          }
          .width('100%')
        }
        Row({ space: 10 }) {
          Text(this.data.legend)
            .fontSize(AppTheme.font.caption)
            .fontColor('#6B6A63')
            .layoutWeight(1)
          Row({ space: 3 }) {
            Text('少').fontSize(AppTheme.font.caption).fontColor('#6B6A63')
            Row().width(9).height(9).backgroundColor('#EDEBE4').borderRadius(0)
            Row().width(9).height(9).backgroundColor('#B7D3E8').borderRadius(0)
            Row().width(9).height(9).backgroundColor('#6FA8CC').borderRadius(0)
            Row().width(9).height(9).backgroundColor('#2E6F9E').borderRadius(0)
            Text('多').fontSize(AppTheme.font.caption).fontColor('#6B6A63')
          }
        }
        .width('100%')
      }
      .width('100%')
    }
  }
}
