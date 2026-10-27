import { BodyReading } from '../model/HomeModel';

/** Displays one body reading (sleep, exercise, note count) in the dashboard. */
@ComponentV2
export struct ReadingCard {
  @Param reading: BodyReading = { label: '', value: '', unit: '' };

  build() {
    Column({ space: 6 }) {
      Text(this.reading.value + this.reading.unit)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2329')
      Text(this.reading.label)
        .fontSize(12)
        .fontColor('#8A8F99')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }
}