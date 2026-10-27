import { RelationListItem } from '../relation';
import { TrustLevel } from '../model/TrustLevel';
import { AppTheme } from '../theme/AppTheme';

const WIDTH = 320;
const HEIGHT = 260;
const CENTER_X = 160;
const CENTER_Y = 130;
const RADIUS = 92;
const MAX_NODES = 6;

/** Egocentric star map: the self in the middle, up to six relations around it. */
@ComponentV2
export struct RelationGraph {
  @Param items: RelationListItem[] = [];

  private nodeX(index: number): number {
    const angle = -Math.PI / 2 + index * (Math.PI * 2 / Math.max(this.items.slice(0, MAX_NODES).length, 1));
    return CENTER_X + Math.cos(angle) * RADIUS;
  }

  private nodeY(index: number): number {
    const angle = -Math.PI / 2 + index * (Math.PI * 2 / Math.max(this.items.slice(0, MAX_NODES).length, 1));
    return CENTER_Y + Math.sin(angle) * RADIUS;
  }

  private nodeColor(level: TrustLevel): string {
    if (level === TrustLevel.TRANSPARENT) {
      return AppTheme.color.success;
    }
    if (level === TrustLevel.SINCERE) {
      return AppTheme.color.warning;
    }
    return AppTheme.color.primaryDeep;
  }

  private edge(index: number): string {
    return `M ${CENTER_X} ${CENTER_Y} L ${this.nodeX(index)} ${this.nodeY(index)}`;
  }

  build() {
    Stack() {
      ForEach(this.items.slice(0, MAX_NODES), (item: RelationListItem, index: number) => {
        Path()
          .commands(this.edge(index))
          .width(WIDTH)
          .height(HEIGHT)
          .fill(Color.Transparent)
          .stroke('#D3D1C7')
          .strokeWidth(1)

        Circle()
          .width(28)
          .height(28)
          .fill(this.nodeColor(item.trustLevel))
          .position({ x: this.nodeX(index) - 14, y: this.nodeY(index) - 14 })

        Text(item.name)
          .fontSize(10)
          .fontColor(AppTheme.color.text)
          .width(70)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .position({ x: this.nodeX(index) - 35, y: this.nodeY(index) + 16 })
      }, (item: RelationListItem) => item.id)

      Circle()
        .width(46)
        .height(46)
        .fill(AppTheme.color.tint)
        .stroke(AppTheme.color.primary)
        .strokeWidth(1)
        .position({ x: CENTER_X - 23, y: CENTER_Y - 23 })

      Text('我')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.primaryDeep)
        .width(46)
        .textAlign(TextAlign.Center)
        .position({ x: CENTER_X - 23, y: CENTER_Y - 9 })
    }
    .width(WIDTH)
    .height(HEIGHT)
  }
}
