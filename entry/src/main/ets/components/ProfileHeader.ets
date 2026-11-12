import { fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { AppTheme, avatarGlyphSize } from '../theme/AppTheme';
import { ROUTES } from '../navigation/Routes';
import { profileCache } from '../profile/ProfileCache';
import { Profile } from '../profile/ProfileStore';
import { subscribeProfileRefresh, unsubscribeProfileRefresh } from '../app/ProfileRefreshBus';

/** Identity band on the home page: avatar, nickname, signature, title and the two page actions. */
@ComponentV2
export struct ProfileHeader {
  @Require @Param pathStack: NavPathStack;
  @Local profile: Profile = profileCache.profile;
  private listener: ((profile?: Profile) => void) | null = null;
  private lastNavAt: number = 0;

  aboutToAppear(): void {
    this.profile = profileCache.profile;
    if (this.listener === null) {
      this.listener = (updated?: Profile) => {
        if (updated !== undefined) {
          this.profile = updated;
        } else {
          this.load();
        }
      };
      subscribeProfileRefresh(this.listener);
    }
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      this.syncCache(context);
    }
  }

  private async syncCache(context: common.Context): Promise<void> {
    await profileCache.ensure(context);
    this.profile = profileCache.profile;
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
    await profileCache.reload(context);
    this.profile = profileCache.profile;
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
          profileCache.set(this.profile);
        })
    } else {
      Column() {
        Text(this.profile.nickname.slice(0, 1))
          .fontSize(avatarGlyphSize(size))
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
            .fontSize(AppTheme.font.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .flexShrink(1)
          Text(this.profile.title)
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.accentGold)
            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
            .backgroundColor(AppTheme.color.surfaceWarm)
            .borderRadius(AppTheme.radius.sm)
            .flexShrink(0)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)

        Text('编辑')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .accessibilityText('编辑身份信息')
          .onClick(() => {
            this.openEditor();
          })
        Text('设置')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .accessibilityText('打开设置')
          .onClick(() => {
            this.openSettings();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.profile.signature.length > 0 ? this.profile.signature : '写一句留给自己的话')
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: AppTheme.spacing.s4 })
    }
    .width('100%')
    .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
    .border({ width: { bottom: 0.5 }, color: AppTheme.color.border })
  }
}
