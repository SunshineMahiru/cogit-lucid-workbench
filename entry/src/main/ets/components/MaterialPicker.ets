import {
  ExperienceMaterial,
  InteractionSource,
  MaterialKind,
  MaterialSource,
  MaterialStance
} from '../model/ExperienceMaterial';
import { SecurityLevel } from '../model/SecurityLevel';
import { AppTheme } from '../theme/AppTheme';

/** One kind bucket shown in the picker; empty kinds are dropped before rendering. */
interface MaterialGroup {
  kind: MaterialKind;
  title: string;
  items: ExperienceMaterial[];
}

const KIND_ORDER: MaterialKind[] = [
  'scene',
  'feeling',
  'body',
  'existing_action',
  'interpretation',
  'unclassified'
];
const KIND_TITLES: string[] = ['现场', '感受', '身体', '已做', '解释', '未分类'];
const SUMMARY_LIMIT: number = 40;

/** Buckets materials by kind in display order; unknown kinds read as unclassified. */
function groupMaterials(materials: ExperienceMaterial[]): MaterialGroup[] {
  const groups: MaterialGroup[] = [];
  KIND_ORDER.forEach((kind: MaterialKind, index: number) => {
    const items = materials.filter((material: ExperienceMaterial) => kindOf(material) === kind);
    if (items.length > 0) {
      groups.push({ kind: kind, title: KIND_TITLES[index], items: items });
    }
  });
  return groups;
}

/** Maps a stored kind onto the six buckets the picker shows. */
function kindOf(material: ExperienceMaterial): MaterialKind {
  return KIND_ORDER.indexOf(material.kind) >= 0 ? material.kind : 'unclassified';
}

/** Collapses line breaks and cuts the text down to one summary line. */
function summaryOf(text: string): string {
  const flat = text.split('\n').join(' ').trim();
  return flat.length > SUMMARY_LIMIT ? `${flat.substring(0, SUMMARY_LIMIT)}…` : flat;
}

function sourceLabel(source: MaterialSource): string {
  if (source === 'direct') {
    return '直接经历';
  }
  if (source === 'reading') {
    return '阅读';
  }
  if (source === 'exercise') {
    return '练习';
  }
  if (source === 'interaction') {
    return '互动';
  }
  if (source === 'reflection') {
    return '反思';
  }
  if (source === 'external') {
    return '外部资料';
  }
  return '来源未标注';
}

function stanceLabel(stance: MaterialStance): string {
  if (stance === 'support') {
    return '支持';
  }
  if (stance === 'challenge') {
    return '挑战';
  }
  if (stance === 'undecided') {
    return '未判定';
  }
  return '';
}

function interactionLabel(source: InteractionSource): string {
  if (source === 'observed') {
    return '我的观察';
  }
  if (source === 'stated') {
    return '对方说过';
  }
  if (source === 'shared_activity') {
    return '一起做过';
  }
  if (source === 'inferred') {
    return '我的推测';
  }
  return '';
}

function levelLabel(level: SecurityLevel): string {
  if (level === SecurityLevel.ANALYZABLE) {
    return '可分析';
  }
  if (level === SecurityLevel.LOCAL_ONLY) {
    return '仅本地';
  }
  return '已封存';
}

/** Groups quotable materials by kind and reports which ones the session cites. */
@ComponentV2
export struct MaterialPicker {
  @Param materials: ExperienceMaterial[] = [];
  @Param selectedIds: string[] = [];
  @Event onToggle: (id: string) => void = () => {};

  private isSelected(id: string): boolean {
    return this.selectedIds.includes(id);
  }

  @Builder
  tag(label: string) {
    Text(label)
      .fontSize(AppTheme.font.caption)
      .fontColor(AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
      .backgroundColor(AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
  }

  @Builder
  groupBlock(group: MaterialGroup) {
    Column({ space: 6 }) {
      Row({ space: 4 }) {
        Text(group.title)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textSecondary)
        Text(`· ${group.items.length}`)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.textMuted)
      }
      .width('100%')

      ForEach(group.items, (material: ExperienceMaterial) => {
        Column({ space: 4 }) {
          Text(summaryOf(material.text))
            .fontSize(AppTheme.font.bodyStrong)
            .lineHeight(18)
            .fontColor(this.isSelected(material.id) ? AppTheme.color.primaryDeep : AppTheme.color.text)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row({ space: 4 }) {
            this.tag(sourceLabel(material.source))
            if (stanceLabel(material.sourceStance).length > 0) {
              this.tag(stanceLabel(material.sourceStance))
            }
            if (interactionLabel(material.interactionSource ?? '').length > 0) {
              this.tag(interactionLabel(material.interactionSource ?? ''))
            }
            this.tag(levelLabel(material.level))
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppTheme.spacing.s10)
        .backgroundColor(this.isSelected(material.id) ? AppTheme.color.tint : AppTheme.color.surfaceAlt)
        .borderRadius(AppTheme.radius.sm)
        .border({
          width: this.isSelected(material.id) ? 1 : 0,
          color: AppTheme.color.borderSelected
        })
        .id(`review_material_${material.id}`)
        .onClick(() => {
          this.onToggle(material.id);
        })
      }, (material: ExperienceMaterial) => `${material.id}_${this.isSelected(material.id) ? 1 : 0}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 8 }) {
      Text('引用材料 · 点击选择本次真正用到的')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')

      if (this.materials.length === 0) {
        Text('还没有可引用的材料')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      } else {
        ForEach(groupMaterials(this.materials), (group: MaterialGroup) => {
          this.groupBlock(group)
        }, (group: MaterialGroup) => `${group.kind}_${group.items.length}`)
      }
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surfaceWarm)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }
}