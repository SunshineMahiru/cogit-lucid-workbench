import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from './SectionCard';
import { RelationTrustBadge } from './RelationTrustBadge';
import { TagChip } from './TagChip';
import { EvidenceChip } from './EvidenceChip';
import { RelationListItem } from '../relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';

/** One relation row: alias, trust badge, latest correction excerpt and pending-response badge. */
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

  private excerpt(): string {
    const text = this.item.latestCorrectionExcerpt ?? '';
    return text.length > 0 ? text : '暂无他者纠正';
  }

  build() {
    SectionCard({ contentPadding: 0 }) {
      Column({ space: AppTheme.spacing.s6 }) {
        Row({ space: AppTheme.spacing.s6 }) {
          Text(this.item.name)
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.text)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          RelationTrustBadge({ level: this.item.trustLevel })
          if ((this.item.pendingCorrections ?? 0) > 0) {
            TagChip({
              label: `待回应 ${this.item.pendingCorrections ?? 0}`,
              tone: AppTheme.color.warning,
              surface: AppTheme.color.warningSurface,
              selected: true
            })
          }
        }
        .width('100%')

        Row({ space: AppTheme.spacing.s6 }) {
          Text(`最近互动 ${this.item.lastInteractionLabel}`)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textSecondary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.item.forbidAnalysis) {
            Text('禁分析')
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.danger)
              .padding({
                left: AppTheme.spacing.s6,
                right: AppTheme.spacing.s6,
                top: AppTheme.spacing.s2,
                bottom: AppTheme.spacing.s2
              })
              .backgroundColor(AppTheme.color.dangerSurface)
              .borderRadius(AppTheme.radius.sm)
          }
        }
        .width('100%')

        Row({ space: AppTheme.spacing.s6 }) {
          EvidenceChip({ source: 'other_person' })
          Text(this.excerpt())
            .fontSize(AppTheme.font.body)
            .lineHeight(20)
            .fontColor(AppTheme.color.textSecondary)
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(AppTheme.spacing.s16)
      .onClick(() => {
        this.onTap();
      })
    }
  }
}