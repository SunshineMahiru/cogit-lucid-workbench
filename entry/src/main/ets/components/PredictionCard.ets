import { PredictionItem } from '../model/HomeModel';
import { todayDateString } from '../prediction';
import { AppTheme } from '../theme/AppTheme';

/**
 * 待结算预测卡片。
 * 数据由父组件通过 @Param 传入，组件自身不持有可变状态，便于在列表里反复复用。
 */
@ComponentV2
export struct PredictionCard {
  @Param item: PredictionItem = { id: '', title: '', confidence: 0, dueDate: '' };
  @Event onTap: () => void = () => {};

  private dueLabel(): string {
    const today = todayDateString();
    if (this.item.dueDate < today) {
      return '已到期';
    }
    if (this.item.dueDate === today) {
      return '今日到期';
    }
    return '待结算';
  }

  private dueColor(): string {
    return this.item.dueDate <= todayDateString() ? AppTheme.color.danger : AppTheme.color.accentGold;
  }

  private dueSurface(): string {
    return this.item.dueDate <= todayDateString() ? AppTheme.color.dangerSurface : AppTheme.color.warningSurface;
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(this.dueLabel())
          .fontSize(10)
          .fontColor(this.dueColor())
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.dueSurface())
          .borderRadius(8)
          .margin({ right: 6 })
        Text(this.item.title)
          .fontSize(15)
          .fontColor(AppTheme.color.text)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.item.confidence}%`)
          .fontSize(14)
          .fontColor(AppTheme.color.primary)
          .margin({ left: 8 })
      }
      .width('100%')

      Row() {
        Text('置信度')
          .fontSize(12)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        Text(this.item.dueDate)
          .fontSize(12)
          .fontColor(AppTheme.color.textSecondary)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => {
      this.onTap();
    })
  }
}
