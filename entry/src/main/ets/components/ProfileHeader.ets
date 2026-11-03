import { fileUri } from '@kit.CoreFileKit';
import { AppTheme } from '../theme/AppTheme';
import { ROUTES } from '../navigation/Routes';
import { DEFAULT_PROFILE, Profile, ProfileStore } from '../profile/ProfileStore';
import { subscribeProfileRefresh, unsubscribeProfileRefresh } from '../app/ProfileRefreshBus';

/** Identity band on the home page: avatar, nickname, signature, title and the two page actions. */
@ComponentV2
export struct ProfileHeader {
  @Require @Param pathStack: NavPathStack;
  @Local profile: Profile = DEFAULT_PROFILE;
  private store: ProfileStore | null = null;
  private listener: (() => void) | null = null;
  private lastNavAt: number = 0;

  aboutToAppear(): void {
    if (this.listener === null) {
      this.listener = () => {
        this.load();
      };
      subscribeProfileRefresh(this.listener);
    }
    this.load();
  }

  aboutToDisappear(): void {
    if (this.listener !== null) {
      unsubscribeProfileRefresh(this.listener);
      this.listener = null;
    }
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      this.store = await ProfileStore.open(context);
      this.profile = await this.store.load();
    } catch (error) {
      this.profile = DEFAULT_PROFILE;
    }
  }

  private openEditor(): void {
    if (!this.canNavigate()) {
      return;
    }
    this.pathStack.pushPathByName(ROUTES.IDENTITY_EDIT, null);
  }

  private openSettings(): void {
    if (!this.canNavigate()) {
      return;
    }
    this.pathStack.pushPathByName(ROUTES.SETTINGS, null);
  }

  private canNavigate(): boolean {
    const now = Date.now();
    if (now - this.lastNavAt < 600) {
      return false;
    }
    this.lastNavAt = now;
    return true;
  }

  @Builder
  avatar(size: number) {
    if (this.profile.avatarPath.length > 0) {
      Image(fileUri.getUriFromPath(this.profile.avatarPath))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Cover)
        .borderRadius(size / 2)
        .border({ width: 1, color: AppTheme.color.borderStrong })
        .onError(() => {
          this.profile = {
            nickname: this.profile.nickname,
            signature: this.profile.signature,
            title: this.profile.title,
            avatarPath: ''
          };
        })
    } else {
      Column() {
        Text(this.profile.nickname.slice(0, 1))
          .fontSize(size / 2.6)
          .fontColor(AppTheme.color.primary)
      }
      .width(size)
      .height(size)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.color.tint)
      .borderRadius(size / 2)
      .border({ width: 1, color: AppTheme.color.borderSelected })
    }
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 12 }) {
        this.avatar(56)
        Row({ space: 6 }) {
          Text(this.profile.nickname)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .flexShrink(1)
          Text(this.profile.title)
            .fontSize(10)
            .fontColor(AppTheme.color.accentGold)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(AppTheme.color.surfaceWarm)
            .borderRadius(6)
            .flexShrink(0)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)

        Text('编辑')
          .fontSize(11)
          .fontColor(AppTheme.color.primary)
          .accessibilityText('编辑身份信息')
          .onClick(() => {
            this.openEditor();
          })
        Text('设置')
          .fontSize(11)
          .fontColor(AppTheme.color.primary)
          .accessibilityText('打开设置')
          .onClick(() => {
            this.openSettings();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.profile.signature.length > 0 ? this.profile.signature : '写一句留给自己的话')
        .fontSize(11)
        .fontColor(AppTheme.color.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 68 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .border({ width: { bottom: 0.5 }, color: AppTheme.color.border })
  }
}
