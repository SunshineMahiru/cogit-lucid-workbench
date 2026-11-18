import { AppTheme } from '../../theme/AppTheme';
import { ModuleCard } from '../../components/ModuleCard';
import { TabKey } from '../../navigation/TabItems';

/** One compact module card in the home status rail. */
export interface ModuleStatus {
  icon: Resource;
  title: string;
  /** Headline number, already formatted for display */
  value: string;
  /** Unit or qualifier under the headline */
  caption: string;
  tone: string;
  /** Route pushed when the card is tapped; empty when the card switches tabs instead */
  route: string;
  /** Tab activated instead of pushing a route; null when a route is used */
  tabKey: TabKey | null;
}

/** Horizontal rail of compact module status cards, replacing the old 3x3 grid. */
@ComponentV2
export struct ModuleRail {
  @Param modules: ModuleStatus[] = [];
  @Event onOpen: (module: ModuleStatus) => void = () => {
  };

  build() {
    Column({ space: AppTheme.spacing.s6 }) {
      Text('模块状态')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')

      Scroll() {
        Row({ space: AppTheme.spacing.s8 }) {
          ForEach(this.modules, (module: ModuleStatus) => {
            Column() {
              ModuleCard({
                icon: module.icon,
                title: module.title,
                value: module.value,
                caption: module.caption,
                tone: module.tone,
                onTap: () => {
                  this.onOpen(module);
                }
              })
            }
            .width(132)
          }, (module: ModuleStatus) => module.title)
        }
        .alignItems(VerticalAlign.Top)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
  }
}