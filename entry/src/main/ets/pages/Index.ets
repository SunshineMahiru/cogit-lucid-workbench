import { DashboardView } from '../views/DashboardView';
import { ROUTES } from '../navigation/Routes';
import { PlaceholderPage } from './PlaceholderPage';
import { NoteEditPage } from './NoteEditPage';
import { NoteListPage } from './NoteListPage';
import { NoteDetailPage } from './NoteDetailPage';
import { PredictionListPage } from './PredictionListPage';
import { PredictionDetailPage } from './PredictionDetailPage';
import { ReviewPage } from './ReviewPage';
import { AnchorPage } from './AnchorPage';
import { RelationListPage } from './RelationListPage';
import { RelationDetailPage } from './RelationDetailPage';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();

  @Builder
  pageMap(name: string) {
    if (name === ROUTES.NOTE_EDIT) {
      NoteEditPage()
    } else if (name === ROUTES.NOTE_LIST) {
      NoteListPage()
    } else if (name === ROUTES.NOTE_DETAIL) {
      NoteDetailPage()
    } else if (name === ROUTES.PREDICTION_LIST) {
      PredictionListPage()
    } else if (name === ROUTES.PREDICTION_DETAIL) {
      PredictionDetailPage()
    } else if (name === ROUTES.REVIEW) {
      ReviewPage()
    } else if (name === ROUTES.ANCHOR) {
      AnchorPage()
    } else if (name === ROUTES.RELATION) {
      RelationListPage()
    } else if (name === ROUTES.RELATION_DETAIL) {
      RelationDetailPage()
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
