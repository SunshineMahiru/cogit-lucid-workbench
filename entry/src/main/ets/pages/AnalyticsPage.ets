import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { AnalyticsView } from '../views/AnalyticsView';

/**
 * Standalone analytics route: a thin wrapper that adds the page shell and its own scroll. The
 * bottom bar no longer links here; the prediction tab embeds the same view instead.
 */
@ComponentV2
export struct AnalyticsPage {
  @Local refreshToken: number = 0;
  private hasShownOnce: boolean = false;

  @Builder
  dashboardBody() {
    Scroll() {
      Column() {
        AnalyticsView({ refreshToken: this.refreshToken, collapsibleNotes: true })
      }
      .width('100%')
      .padding({
        left: AppTheme.spacing.page,
        right: AppTheme.spacing.page,
        top: AppTheme.spacing.s8,
        bottom: AppTheme.spacing.s24
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  build() {
    AppDestination({
      route: 'analytics',
      title: '数据看板',
      content: () => {
        this.dashboardBody();
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.refreshToken += 1;
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }
}