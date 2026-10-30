import { BodyReading } from '../model/HomeModel';
import { AppTheme } from '../theme/AppTheme';

/** Displays one body reading (sleep, exercise, note count) in the dashboard. */
@ComponentV2
export struct ReadingCard {
  @Param reading: BodyReading = { label: '', value: '', unit: '' };

  private iconForLabel(label: string): string {
    if (label === '睡眠') {
      return '眠';
    } else if (label === '运动') {
      return '动';
    } else {
      return '记';
    }
  }

  private colorForLabel(label: string): string {
    if (label === '睡眠') {
      return AppTheme.color.accentPurple;
    } else if (label === '运动') {
      return AppTheme.color.primary;
    } else {
      return AppTheme.color.accentGold;
    }
  }

  build() {
    Column({ space: 4 }) {
      Text(this.iconForLabel(this.reading.label))
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colorForLabel(this.reading.label))
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.color.tint)
        .borderRadius(AppTheme.radius.tag)
      Text(this.reading.value + this.reading.unit)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colorForLabel(this.reading.label))
      Text(this.reading.label)
        .fontSize(11)
        .fontColor(AppTheme.color.textSecondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(`${this.reading.label} ${this.reading.value}${this.reading.unit}`)
  }
}
