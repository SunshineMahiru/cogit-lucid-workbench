import { DashboardView } from '../views/DashboardView';
import { ROUTES } from '../navigation/Routes';
import { PlaceholderPage } from './PlaceholderPage';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();

  @Builder
  pageMap(name: string) {
    if (name === ROUTES.NOTE_EDIT) {
      PlaceholderPage({ title: '速记', hint: '速记编辑页将在 2.2 接入' })
    } else if (name === ROUTES.NOTE_LIST) {
      PlaceholderPage({ title: '速记列表', hint: '速记列表将在 2.2 接入' })
    } else if (name === ROUTES.PREDICTION_LIST) {
      PlaceholderPage({ title: '预测日志', hint: '预测列表将在 2.3 接入' })
    } else if (name === ROUTES.PREDICTION_DETAIL) {
      PlaceholderPage({ title: '预测详情', hint: '预测详情将在 2.4 接入' })
    } else if (name === ROUTES.REVIEW) {
      PlaceholderPage({ title: '复盘', hint: '复盘会话将在 2.5 接入' })
    } else if (name === ROUTES.ANCHOR) {
      PlaceholderPage({ title: '价值锚点', hint: '锚点页将在 2.6 接入' })
    } else if (name === ROUTES.RELATION) {
      PlaceholderPage({ title: '关系层', hint: '关系页将在 2.7 接入' })
    } else if (name === ROUTES.STATUS) {
      PlaceholderPage({ title: '状态面板', hint: '状态页将在 2.8 接入' })
    }
  }

  build() {
    Navigation(this.pathStack) {
      DashboardView({ pathStack: this.pathStack })
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
    .backgroundColor('#F5F6F8')
  }
}
