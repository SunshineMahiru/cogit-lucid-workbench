import { fileUri } from '@kit.CoreFileKit';
import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { ImageSourceSheet } from '../components/ImageSourceSheet';
import {
  DEFAULT_PROFILE,
  Profile,
  ProfileStore,
  sanitizeProfile
} from '../profile/ProfileStore';
import { pickAvatarUri, removeAvatar, saveAvatar } from '../profile/AvatarService';
import { BackgroundImageSource } from '../settings/PageBackgroundService';
import { notifyProfileRefresh } from '../app/ProfileRefreshBus';
import { profileCache } from '../profile/ProfileCache';

/** Full-screen identity editor; a destination so it shares the shell transition instead of a sheet. */
@ComponentV2
export struct IdentityEditPage {
  @Local profile: Profile = {
    nickname: '记录者',
    signature: '把判断留下来，过一段时间再看',
    title: '未命名',
    avatarPath: ''
  };
  @Local draftNickname: string = '';
  @Local draftSignature: string = '';
  @Local draftTitle: string = '';
  @Local draftAvatar: string = '';
  @Local busyKey: string = '';
  @Local showSourceSheet: boolean = false;
  @Local isLoading: boolean = true;
  private navStack: NavPathStack | null = null;
  private store: ProfileStore | null = null;

  private async load(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.isLoading = false;
      return;
    }
    try {
      this.store = await ProfileStore.open(context);
      await profileCache.ensure(context);
      this.profile = profileCache.profile;
      this.draftNickname = this.profile.nickname;
      this.draftSignature = this.profile.signature;
      this.draftTitle = this.profile.title;
      this.draftAvatar = this.profile.avatarPath;
    } catch (error) {
      this.profile = DEFAULT_PROFILE;
    } finally {
      this.isLoading = false;
    }
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

  private async save(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'save';
    try {
      const store = this.store ?? await ProfileStore.open(context);
      const next = sanitizeProfile({
        nickname: this.draftNickname,
        signature: this.draftSignature,
        title: this.draftTitle,
        avatarPath: this.draftAvatar
      });
      await store.save(next);
      profileCache.set(next);
      if (this.profile.avatarPath.length > 0 && this.profile.avatarPath !== next.avatarPath) {
        removeAvatar(this.profile.avatarPath);
      }
      notifyProfileRefresh(next);
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.toast('保存失败，请重试');
    } finally {
      this.busyKey = '';
    }
  }

  private cancel(): void {
    if (this.draftAvatar.length > 0 && this.draftAvatar !== this.profile.avatarPath) {
      removeAvatar(this.draftAvatar);
    }
    if (this.navStack !== null) {
      this.navStack.pop(true);
    }
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  build() {
    AppDestination({
      route: 'identity_edit',
      title: '编辑身份',
      content: () => {
        this.body();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        this.load();
      },
      onDestinationBackPressed: () => {
        this.cancel();
        return true;
      }
    })
  }

  @Builder
  body() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(AppTheme.color.primary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            this.avatarPreview()
            Column({ space: 6 }) {
              Text('头像')
                .fontSize(AppTheme.font.body)
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

          this.field('昵称', this.draftNickname, 12, (value: string) => {
            this.draftNickname = value;
          })
          this.field('签名', this.draftSignature, 24, (value: string) => {
            this.draftSignature = value;
          })
          this.field('头衔', this.draftTitle, 8, (value: string) => {
            this.draftTitle = value;
          })

          Row({ space: 10 }) {
            Text('取消')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(AppTheme.color.textSecondary)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 10 })
              .backgroundColor(AppTheme.color.surfaceAlt)
              .borderRadius(10)
              .onClick(() => {
                this.cancel();
              })
            Text(this.busyKey === 'save' ? '保存中…' : '保存')
              .fontSize(AppTheme.font.bodyStrong)
              .fontColor(Color.White)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 10 })
              .backgroundColor(AppTheme.color.primary)
              .borderRadius(10)
              .accessibilityText('保存身份信息')
              .onClick(() => {
                this.save();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppTheme.spacing.page)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .bindSheet($$this.showSourceSheet, this.sourceSheet(), {
        height: 300,
        dragBar: false,
        backgroundColor: AppTheme.color.surface
      })
    }
  }

  @Builder
  sourceSheet() {
    ImageSourceSheet({
      onPick: (source: BackgroundImageSource) => {
        this.showSourceSheet = false;
        this.pickAvatar(source);
      }
    })
  }

  @Builder
  avatarPreview() {
    if (this.draftAvatar.length > 0) {
      Image(fileUri.getUriFromPath(this.draftAvatar))
        .width(56)
        .height(56)
        .objectFit(ImageFit.Cover)
        .borderRadius(28)
    } else {
      Column() {
        Text(this.draftNickname.slice(0, 1))
          .fontSize(AppTheme.font.headline)
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
      .fontSize(AppTheme.font.body)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(AppTheme.color.tint)
      .borderRadius(8)
      .accessibilityText(label)
      .onClick(() => {
        this.showSourceSheet = true;
      })
  }

  @Builder
  field(label: string, value: string, limit: number, onChange: (value: string) => void) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(AppTheme.font.body)
        .fontColor(AppTheme.color.textSecondary)
      TextInput({ text: value })
        .fontSize(AppTheme.font.bodyStrong)
        .maxLength(limit)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(8)
        .padding({ left: 10, right: 10 })
        .onChange((text: string) => {
          onChange(text);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
