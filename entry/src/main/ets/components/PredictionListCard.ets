import {
  PredictionListItem,
  PredictionResultLabel,
  PredictionResultTone,
  predictionLifecycleLabel,
  predictionResultLabel
} from '../prediction';
import { PredictionStatus } from '../model/PredictionStatus';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppTheme } from '../theme/AppTheme';
import { formatDate } from '../analysis/time/DateTime';
import { SectionCard } from './SectionCard';
import { TagChip } from './TagChip';

/** Prediction row for the log list, covering both pending and settled states. */
@ComponentV2
export struct PredictionListCard {
  @Param item: PredictionListItem = {
    id: '',
    target: '',
    judgment: '',
    confidence: 0,
    settlementDate: '',
    status: PredictionStatus.PENDING,
    hit: null,
    outcome: '',
    actualResult: '',
    createdAt: 0,
    revisedAt: 0,
    version: 1,
    hypothesisExcerpt: '',
    termOnly: false,
    level: SecurityLevel.LOCAL_ONLY
  };
  @Event onTap: () => void = () => {};

  private isOpen(): boolean {
    return this.item.status === PredictionStatus.PENDING;
  }

  private result(): PredictionResultLabel {
    return predictionResultLabel(this.item);
  }

  private toneColor(tone: PredictionResultTone): ResourceColor {
    if (tone === 'success') {
      return AppTheme.color.success;
    }
    if (tone === 'danger') {
      return AppTheme.color.danger;
    }
    if (tone === 'warning') {
      return AppTheme.color.warning;
    }
    return AppTheme.color.textMuted;
  }

  private toneSurface(tone: PredictionResultTone): ResourceColor {
    if (tone === 'success') {
      return AppTheme.color.successSurface;
    }
    if (tone === 'danger') {
      return AppTheme.color.dangerSurface;
    }
    if (tone === 'warning') {
      return AppTheme.color.warningSurface;
    }
    return AppTheme.color.chip;
  }

  private excerpt(): string {
    return this.item.hypothesisExcerpt.length > 0 ? this.item.hypothesisExcerpt : this.item.judgment;
  }

  private confidenceText(): string {
    return this.item.confidence === null ? '置信度 未量化' : `置信度 ${this.item.confidence}%`;
  }

  private metaText(): string {
    const due = this.item.settlementDate.length > 0 ? `期限 ${this.item.settlementDate.substring(5)}` : '期限 未定';
    const revision = this.item.version > 1 ?
      `修订 ${formatDate(this.item.revisedAt).substring(5)}` :
      `创建 ${formatDate(this.item.revisedAt).substring(5)}`;
    return `${this.confidenceText()} · ${due} · v${this.item.version} · ${revision}`;
  }

  build() {
    Column() {
      SectionCard() {
        Column({ space: AppTheme.spacing.s8 }) {
          Row({ space: AppTheme.spacing.s6 }) {
            Text(this.item.target)
              .fontSize(AppTheme.font.bodyStrong)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.color.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            TagChip({
              label: predictionLifecycleLabel(this.item.status),
              tone: this.isOpen() ? AppTheme.color.warning : AppTheme.color.textSecondary,
              surface: this.isOpen() ? AppTheme.color.warningSurface : AppTheme.color.chip,
              selected: true
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(this.excerpt())
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Row({ space: AppTheme.spacing.s8 }) {
            Text(this.metaText())
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (!this.isOpen()) {
              TagChip({
                label: this.result().label,
                tone: this.toneColor(this.result().tone),
                surface: this.toneSurface(this.result().tone),
                selected: true
              })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .onClick(() => {
      this.onTap();
    })
  }
}