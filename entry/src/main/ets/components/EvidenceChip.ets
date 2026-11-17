import { AppTheme } from '../theme/AppTheme';
import { EvidenceSource } from '../model/EvidenceItem';
import { evidenceStyle } from '../theme/EvidenceLanguage';

/** Evidence-source tag with a fixed colour dot, used across review/prediction/relation. */
@ComponentV2
export struct EvidenceChip {
  @Param source: EvidenceSource = 'practice';
  @Param compact: boolean = false;

  build() {
    Row({ space: AppTheme.spacing.s4 }) {
      Circle()
        .width(6)
        .height(6)
        .fill(evidenceStyle(this.source).color)
      Text(evidenceStyle(this.source).label)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textSecondary)
    }
    .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
    .backgroundColor(evidenceStyle(this.source).surface)
    .borderRadius(AppTheme.radius.sm)
  }
}