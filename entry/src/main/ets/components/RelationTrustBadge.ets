import { TrustLevel } from '../model/TrustLevel';
import { trustLevelText } from '../relation';
import { AppTheme } from '../theme/AppTheme';

/** Trust tier badge shared by the relation list and detail page. */
@ComponentV2
export struct RelationTrustBadge {
  @Param level: TrustLevel = TrustLevel.FRIENDLY;

  private textColor(): string {
    if (this.level === TrustLevel.TRANSPARENT) {
      return AppTheme.color.success;
    }
    if (this.level === TrustLevel.SINCERE) {
      return AppTheme.color.warning;
    }
    return AppTheme.color.primaryDeep;
  }

  private surfaceColor(): string {
    if (this.level === TrustLevel.TRANSPARENT) {
      return AppTheme.color.successSurface;
    }
    if (this.level === TrustLevel.SINCERE) {
      return AppTheme.color.warningSurface;
    }
    return AppTheme.color.tint;
  }

  build() {
    Text(trustLevelText(this.level))
      .fontSize(10)
      .fontColor(this.textColor())
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor(this.surfaceColor())
      .borderRadius(AppTheme.radius.tag)
  }
}
