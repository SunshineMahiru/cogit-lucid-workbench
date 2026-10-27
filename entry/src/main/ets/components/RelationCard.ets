import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';
import { RelationTrustBadge } from './RelationTrustBadge';
import { RelationListItem } from '../relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';

/** One relation row: alias, trust badge, interaction count and analysis flags. */
@ComponentV2
export struct RelationCard {
  @Param item: RelationListItem = {
    id: '',
    name: '',
    trustLevel: TrustLevel.FRIENDLY,
    interactionCount: 0,
    lastInteractionLabel: '',
    lastInteractionAt: 0,
    rawMaterialTest: false,
    forbidAnalysis: false,
    level: SecurityLevel.LOCAL_ONLY,
    notes: ''
  };
  @Event onTap: () => void = () => {};

  build() {
    SectionCard({ contentPadding: 0 }) {
      Column({ space: 8 }) {
        Row({ space: 6 }) {
          Text(this.item.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          RelationTrustBadge({ level: this.item.trustLevel })
        }
        .width('100%')

        Row({ space: 6 }) {
          Text(`${this.item.interactionCount} 次互动 · ${this.item.lastInteractionLabel}`)
            .fontSize(11)
            .fontColor(AppTheme.color.textSecondary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.item.rawMaterialTest) {
            Text('未加工材料')
              .fontSize(9)
              .fontColor(AppTheme.color.primaryDeep)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .backgroundColor(AppTheme.color.tint)
              .borderRadius(6)
          }
          if (this.item.forbidAnalysis) {
            Text('禁分析')
              .fontSize(9)
              .fontColor(AppTheme.color.danger)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .backgroundColor(AppTheme.color.dangerSurface)
              .borderRadius(6)
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
      .onClick(() => {
        this.onTap();
      })
    }
  }
}
