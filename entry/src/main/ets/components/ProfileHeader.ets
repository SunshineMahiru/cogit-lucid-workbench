import { fileUri } from '@kit.CoreFileKit';
import { AppTheme } from '../theme/AppTheme';
import { ROUTES } from '../navigation/Routes';
import {
  DEFAULT_PROFILE,
  Profile,
  ProfileStore,
  sanitizeProfile
} from '../profile/ProfileStore';
import { pickAvatarUri, removeAvatar, saveAvatar } from '../profile/AvatarService';
import { BackgroundImageSource } from '../settings/PageBackgroundService';

/** Identity band on the home page: avatar, nickname, signature, title and the two page actions. */
@ComponentV2
export struct ProfileHeader {
  @Require @Param pathStack: NavPathStack;
  @Local profile: Profile = DEFAULT_PROFILE;
  @Local showEditor: boolean = false;
  @Local busyKey: string = '';
  @Local draftNickname: string = '';
  @Local draftSignature: string = '';
  @Local draftTitle: string = '';
  @Local draftAvatar: string = '';
  private store: ProfileStore | null = null;

  aboutToAppear(): void {
    this.load();
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
    this.draftNickname = this.profile.nickname;
    this.draftSignature = this.profile.signature;
    this.draftTitle = this.profile.title;
    this.draftAvatar = this.profile.avatarPath;
    this.showEditor = true;
  }

  private async pickAvatar(source: BackgroundImageSource): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'avatar';
    try {
      const uri = await pickAvatarUri(source, context);
      if (uri.length === 0) {
        return;
      }
      this.draftAvatar = await saveAvatar(uri, context, this.draftAvatar);
    } catch (error) {
      this.toast('头像读取失败，换一张或换格式再试');
    } finally {
      this.busyKey = '';
    }
  }

  private async saveProfile(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'save';
    try {
      const store = this.store ?? await ProfileStore.open(context);
      this.store = store;
      const next = sanitizeProfile({
        nickname: this.draftNickname,
        signature: this.draftSignature,
        title: this.draftTitle,
        avatarPath: this.draftAvatar
      });
      await store.save(next);
      this.profile = next;
      this.showEditor = false;
      this.toast('已保存');
    } catch (error) {
      this.toast('保存失败，请重试');
    } finally {
      this.busyKey = '';
    }
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private openSettings(): void {
    this.pathStack.pushPathByName(ROUTES.SETTINGS, null);
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

  @Builder
  draftAvatarBox() {
    if (this.draftAvatar.length > 0) {
      Image(fileUri.getUriFromPath(this.draftAvatar))
        .width(56)
        .height(56)
        .objectFit(ImageFit.Cover)
        .borderRadius(28)
    } else {
      Column() {
        Text(this.draftNickname.slice(0, 1))
          .fontSize(20)
          .fontColor(AppTheme.color.primary)
      }
      .width(56)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.color.tint)
      .borderRadius(28)
    }
  }

  @Builder
  sourceChip(label: string, source: BackgroundImageSource) {
    Text(label)
      .fontSize(11)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(AppTheme.color.tint)
      .borderRadius(8)
      .accessibilityText(label)
      .onClick(() => {
        this.pickAvatar(source);
      })
  }

  @Builder
  editor() {
    Column({ space: 12 }) {
      Text('编辑身份')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
        .width('100%')
      Row({ space: 12 }) {
        this.draftAvatarBox()
        Column({ space: 6 }) {
          Text('头像')
            .fontSize(11)
            .fontColor(AppTheme.color.textSecondary)
          Row({ space: 8 }) {
            this.sourceChip('相册', BackgroundImageSource.GALLERY)
            this.sourceChip('拍照', BackgroundImageSource.CAMERA)
            this.sourceChip('文件', BackgroundImageSource.FILES)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Column({ space: 4 }) {
        Text('昵称')
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
        TextInput({ text: this.draftNickname })
          .fontSize(13)
          .maxLength(12)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(8)
          .padding({ left: 10, right: 10 })
          .onChange((text: string) => {
            this.draftNickname = text;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 4 }) {
        Text('签名')
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
        TextInput({ text: this.draftSignature })
          .fontSize(13)
          .maxLength(24)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(8)
          .padding({ left: 10, right: 10 })
          .onChange((text: string) => {
            this.draftSignature = text;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 4 }) {
        Text('头衔')
          .fontSize(11)
          .fontColor(AppTheme.color.textSecondary)
        TextInput({ text: this.draftTitle })
          .fontSize(13)
          .maxLength(8)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(8)
          .padding({ left: 10, right: 10 })
          .onChange((text: string) => {
            this.draftTitle = text;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 10 }) {
        Text('取消')
          .fontSize(13)
          .fontColor(AppTheme.color.textSecondary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(10)
          .onClick(() => {
            this.showEditor = false;
          })
        Text(this.busyKey === 'save' ? '保存中…' : '保存')
          .fontSize(13)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(AppTheme.color.primary)
          .borderRadius(10)
          .accessibilityText('保存身份信息')
          .onClick(() => {
            this.saveProfile();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    .alignItems(HorizontalAlign.Start)
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
    .bindSheet($$this.showEditor, this.editor(), {
      height: 480,
      dragBar: false,
      backgroundColor: AppTheme.color.surface,
      onDisappear: () => {
        if (this.draftAvatar.length > 0 && this.draftAvatar !== this.profile.avatarPath) {
          removeAvatar(this.draftAvatar);
          this.draftAvatar = this.profile.avatarPath;
        }
      }
    })
  }
}
