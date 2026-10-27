import { BodyReading } from '../model/HomeModel';

/** Displays one body reading (sleep, exercise, note count) in the dashboard. */
@ComponentV2
export struct ReadingCard {
  @Param reading: BodyReading = { label: '', value: '', unit: '' };

  private iconForLabel(label: string): string {
    if (label === '睡眠') {
      return '🌙';
    } else if (label === '运动') {
      return '🏃';
    } else {
      return '📝';
    }
  }

  private colorForLabel(label: string): string {
    if (label === '睡眠') {
      return '#6B5B95';
    } else if (label === '运动') {
      return '#4A6FA5';
    } else {
      return '#E8A93C';
    }
  }

  build() {
    Column({ space: 4 }) {
      Text(this.iconForLabel(this.reading.label))
        .fontSize(18)
      Text(this.reading.value + this.reading.unit)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colorForLabel(this.reading.label))
      Text(this.reading.label)
        .fontSize(11)
        .fontColor('#8A8F99')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}