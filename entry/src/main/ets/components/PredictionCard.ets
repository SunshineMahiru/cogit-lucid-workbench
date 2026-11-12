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
          .fontSize(AppTheme.font.caption)
          .fontColor(this.dueColor())
          .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
          .backgroundColor(this.dueSurface())
          .borderRadius(AppTheme.radius.sm)
          .margin({ right: AppTheme.spacing.s6 })
        Text(this.item.title)
          .fontSize(AppTheme.font.subtitle)
          .fontColor(AppTheme.color.text)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.item.confidence}%`)
          .fontSize(AppTheme.font.subtitle)
          .fontColor(AppTheme.color.primary)
          .margin({ left: AppTheme.spacing.s8 })
      }
      .width('100%')

      Row() {
        Text('置信度')
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.textSecondary)
        Blank()
        Text(this.item.dueDate)
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.textSecondary)
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
    .onClick(() => {
      this.onTap();
    })
  }
}
