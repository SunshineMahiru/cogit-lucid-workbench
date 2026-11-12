import { AppTheme } from '../../theme/AppTheme';
import { HomeModule } from '../../model/HomeModel';
import { ModuleCard } from '../../components/ModuleCard';

/** Section wrapper around the module tiles, kept out of the dashboard page body. */
@ComponentV2
export struct ModuleGridCard {
  @Param moduleItems: HomeModule[] = [];
  @Param dataVersion: number = 0;
  @Event onOpen: (route: string) => void = () => {};

  build() {
    Column({ space: 10 }) {
      Text('模块入口')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
        .textAlign(TextAlign.Start)
      Grid() {
        ForEach(this.moduleItems, (module: HomeModule) => {
          GridItem() {
            ModuleCard({
              icon: module.icon,
              title: module.title,
              summary: module.summary,
              onTap: () => {
                this.onOpen(module.route);
              }
            })
          }
        }, (module: HomeModule) => `${module.route}_${this.dataVersion}`)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
      .height(266)
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.lg)
  }
}
