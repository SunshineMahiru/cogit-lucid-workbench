import { PageBackgroundStore } from '../settings/PageBackgroundStore';
import { subscribePageBackground, unsubscribePageBackground } from '../settings/PageBackgroundBus';

/** A low-opacity image layer used behind one page group. */
@ComponentV2
export struct PageBackground {
  @Param route: string = 'home';
  @Local imagePath: string = '';
  @Local imageOpacity: number = 0.14;
  private listener: (() => void) | null = null;

  aboutToAppear(): void {
    this.listener = () => {
      this.load();
    };
    subscribePageBackground(this.listener);
    this.load();
  }

  aboutToDisappear(): void {
    if (this.listener !== null) {
      unsubscribePageBackground(this.listener);
      this.listener = null;
    }
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.imagePath = '';
      return;
    }
    try {
      const store = await PageBackgroundStore.open(context);
      this.imagePath = await store.get(this.route);
      this.imageOpacity = await store.getOpacity();
    } catch (error) {
      this.imagePath = '';
    }
  }

  build() {
    Stack() {
      if (this.imagePath.length > 0) {
        Image(this.imagePath)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.imageOpacity)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
