import { fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { AppTheme, avatarGlyphSize } from '../theme/AppTheme';
import { profileCache } from '../profile/ProfileCache';
import { Profile } from '../profile/ProfileStore';
import { subscribeProfileRefresh, unsubscribeProfileRefresh } from '../app/ProfileRefreshBus';

/**
 * Read-only identity card: avatar, nickname, title and signature, plus one edit entry.
 * It never navigates on its own; the host decides where the edit entry goes.
 */
@ComponentV2
export struct IdentityCard {
  @Param showAvatar: boolean = true;
  /** Bumped by the host after the editor returns; forces a reload from the shared cache. */
  @Param refreshToken: number = 0;
  @Event onEdit: () => void = () => {
  };
  @Local profile: Profile = profileCache.profile;
  private listener: ((profile?: Profile) => void) | null = null;

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

  aboutToDisappear(): void {
    if (this.listener !== null) {
      unsubscribeProfileRefresh(this.listener);
      this.listener = null;
    }
  }

  @Monitor('refreshToken')
  onRefreshToken(): void {
    this.load();
  }

  private async syncCache(context: common.Context): Promise<void> {
    await profileCache.ensure(context);
    this.profile = profileCache.profile;
  }

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    await profileCache.reload(context);
    this.profile = profileCache.profile;
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
        .accessibilityText('头像')
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
      .accessibilityText('头像占位')
    }
  }

  build() {
    Column({ space: AppTheme.spacing.s4 }) {
      Row({ space: AppTheme.spacing.s12 }) {
        if (this.showAvatar) {
          this.avatar(48)
        }
        Column({ space: AppTheme.spacing.s2 }) {
          Row({ space: AppTheme.spacing.s6 }) {
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
              .padding({
                left: AppTheme.spacing.s6,
                right: AppTheme.spacing.s6,
                top: AppTheme.spacing.s2,
                bottom: AppTheme.spacing.s2
              })
              .backgroundColor(AppTheme.color.surfaceWarm)
              .borderRadius(AppTheme.radius.sm)
              .flexShrink(0)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(this.profile.signature.length > 0 ? this.profile.signature : '写一句留给自己的话')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('编辑')
          .id('identity_card_edit')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s4 })
          .flexShrink(0)
          .accessibilityText('编辑身份信息')
          .onClick(() => {
            this.onEdit();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }
}