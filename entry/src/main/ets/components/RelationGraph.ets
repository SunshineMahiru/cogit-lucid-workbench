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
  private graphContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));

  private drawEdges(): void {
    const context = this.graphContext;
    context.clearRect(0, 0, WIDTH, HEIGHT);
    context.strokeStyle = AppTheme.color.borderStrong;
    context.lineWidth = 1;
    const total = Math.min(this.items.length, MAX_NODES);
    for (let index = 0; index < total; index += 1) {
      context.beginPath();
      context.moveTo(CENTER_X, CENTER_Y);
      context.lineTo(this.nodeX(index), this.nodeY(index));
      context.stroke();
    }
  }

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

  build() {
    Stack() {
      Canvas(this.graphContext)
        .width(WIDTH)
        .height(HEIGHT)
        .onReady(() => {
          this.drawEdges();
        })

      ForEach(this.items.slice(0, MAX_NODES), (item: RelationListItem, index: number) => {
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
