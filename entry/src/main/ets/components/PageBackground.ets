import { PageBackgroundStore } from '../settings/PageBackgroundStore';
import {
  isPageEmpty,
  subscribePageBackground,
  unsubscribePageBackground
} from '../settings/PageBackgroundBus';
import { PageBackgroundService } from '../settings/PageBackgroundService';
import { AppTheme, isDarkMode, withAlpha } from '../theme/AppTheme';
import { fileUri } from '@kit.CoreFileKit';

/** What a group renders with; kept in memory so switching groups does not wait for storage. */
interface SurfaceSnapshot {
  path: string;
  imageOpacity: number;
  surfaceAlpha: number;
}

const surfaceCache: Map<string, SurfaceSnapshot> = new Map();

/** Page surface: a translucent scrim in the theme colour plus the optional picture. */
@ComponentV2
export struct PageBackground {
  @Param route: string = 'home';
  @Local imagePath: string = '';
  @Local imageOpacity: number = 0.1;
  @Local surfaceAlpha: number = 1;
  private listener: (() => void) | null = null;
  private static readonly EMPTY_FACTOR: number = 0.55;
  private static readonly DARK_IMAGE_FACTOR: number = 0.7;
  private static readonly DARK_SCRIM: string = '#2E000000';

  aboutToAppear(): void {
    this.listener = () => {
      this.load();
    };
    subscribePageBackground(this.listener);
    this.applyCached();
    this.load();
  }

  @Monitor('route')
  onRouteChanged(): void {
    this.applyCached();
    this.load();
  }

  aboutToDisappear(): void {
    if (this.listener !== null) {
      unsubscribePageBackground(this.listener);
      this.listener = null;
    }
  }

  private applyCached(): void {
    const cached = surfaceCache.get(this.route);
    if (cached !== undefined) {
      this.applySnapshot(cached);
    }
  }

  private applySnapshot(snapshot: SurfaceSnapshot): void {
    this.imagePath = snapshot.path;
    this.imageOpacity = snapshot.imageOpacity;
    this.surfaceAlpha = snapshot.surfaceAlpha;
  }

  private imageStrength(base: number): number {
    const dimmed = isPageEmpty() ? base * PageBackground.EMPTY_FACTOR : base;
    return isDarkMode() ? dimmed * PageBackground.DARK_IMAGE_FACTOR : dimmed;
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.imagePath = '';
      return;
    }
    try {
      const store = await PageBackgroundStore.open(context);
      const resolved = await store.resolve(this.route);
      const path = await PageBackgroundService.prepareDisplayImage(resolved, context);
      const snapshot: SurfaceSnapshot = {
        path: path,
        imageOpacity: this.imageStrength(await store.getOpacity()),
        surfaceAlpha: await store.resolveAlpha(this.route)
      };
      surfaceCache.set(this.route, snapshot);
      this.applySnapshot(snapshot);
    } catch (error) {
      this.imagePath = '';
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(withAlpha(AppTheme.color.page, this.surfaceAlpha))
        .hitTestBehavior(HitTestMode.None)
      if (this.imagePath.length > 0) {
        Image(fileUri.getUriFromPath(this.imagePath))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.imageOpacity)
          .hitTestBehavior(HitTestMode.None)
          .onError(() => {
            this.imagePath = '';
          })
        if (isDarkMode()) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(PageBackground.DARK_SCRIM)
            .hitTestBehavior(HitTestMode.None)
        }
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
