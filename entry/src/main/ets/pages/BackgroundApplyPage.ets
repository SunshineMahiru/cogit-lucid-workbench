import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { ImageSourceSheet } from '../components/ImageSourceSheet';
import { fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import {
  BackgroundGroupState,
  BackgroundImageSource,
  PageBackgroundService
} from '../settings/PageBackgroundService';
import { PageBackgroundStore } from '../settings/PageBackgroundStore';

/** Lets the user send one staged image to a single page group, several groups, or all of them. */
@ComponentV2
export struct BackgroundApplyPage {
  @Local pendingPath: string = '';
  @Local states: BackgroundGroupState[] = [];
  @Local imageOpacity: number = 0.1;
  @Local isLoading: boolean = true;
  @Local busyKey: string = '';
  @Local selectedKeys: string[] = [];
  @Local showSourceSheet: boolean = false;
  @Local globalApplied: boolean = false;
  @Local surfaceAlpha: number = 1;
  private navStack: NavPathStack = new NavPathStack();
  private hostContext: common.Context | null = null;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.hostContext = this.getUIContext().getHostContext() ?? null;
    if (this.hostContext === null) {
      this.isLoading = false;
      return;
    }
    try {
      this.pendingPath = await PageBackgroundService.getPending(this.hostContext);
      this.states = await PageBackgroundService.groupStates(this.hostContext);
      this.globalApplied = (await PageBackgroundService.getGlobal(this.hostContext)).length > 0;
      const store = await PageBackgroundStore.open(this.hostContext);
      this.imageOpacity = await store.getOpacity();
      await this.refreshAlpha();
    } catch (error) {
      this.states = [];
    } finally {
      this.isLoading = false;
    }
  }

  private async refreshStates(): Promise<void> {
    if (this.hostContext === null) {
      return;
    }
    this.states = await PageBackgroundService.groupStates(this.hostContext);
    this.globalApplied = (await PageBackgroundService.getGlobal(this.hostContext)).length > 0;
    await this.refreshAlpha();
  }

  /** Slider mirrors the group being edited, or the global value when nothing is selected. */
  private async refreshAlpha(): Promise<void> {
    if (this.hostContext === null) {
      return;
    }
    const key = this.selectedKeys.length > 0 ? this.selectedKeys[0] : '';
    this.surfaceAlpha = await PageBackgroundService.resolveAlpha(this.hostContext, key);
  }

  private async updateSurfaceAlpha(value: number): Promise<void> {
    this.surfaceAlpha = 1 - value / 100;
    if (this.hostContext === null) {
      return;
    }
    try {
      if (this.selectedKeys.length > 0) {
        for (const key of this.selectedKeys) {
          await PageBackgroundService.setGroupAlpha(this.hostContext, key, this.surfaceAlpha);
        }
      } else {
        await PageBackgroundService.setGlobalAlpha(this.hostContext, this.surfaceAlpha);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '透明度保存失败，请重试' });
    }
  }

  private async resetSurfaceAlpha(): Promise<void> {
    if (this.hostContext === null) {
      return;
    }
    try {
      if (this.selectedKeys.length > 0) {
        for (const key of this.selectedKeys) {
          await PageBackgroundService.clearGroupAlpha(this.hostContext, key);
        }
      } else {
        await PageBackgroundService.resetAlpha(this.hostContext);
      }
      await this.refreshAlpha();
      this.getUIContext().getPromptAction().showToast({ message: '已恢复跟随' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '恢复失败，请重试' });
    }
  }

  private async pickAgain(source: BackgroundImageSource): Promise<void> {
    if (this.hostContext === null || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'pick';
    try {
      const path = await PageBackgroundService.replacePending(source, this.hostContext);
      if (path.length > 0) {
        this.pendingPath = path;
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '图片读取失败，换一张或换格式再试' });
    } finally {
      this.busyKey = '';
    }
  }

  private async applyToGlobal(): Promise<void> {
    if (this.hostContext === null || this.pendingPath.length === 0 || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'global';
    try {
      await PageBackgroundService.applyToGlobal(this.pendingPath, this.hostContext);
      this.selectedKeys = [];
      await this.refreshStates();
      this.getUIContext().getPromptAction().showToast({ message: '已设为全部页面的默认背景' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '设置失败，请重试' });
    } finally {
      this.busyKey = '';
    }
  }

  private async applyTo(group: string, label: string): Promise<void> {
    if (this.hostContext === null || this.pendingPath.length === 0 || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = group;
    try {
      await PageBackgroundService.applyToGroup(group, this.pendingPath, this.hostContext);
      await this.refreshStates();
      this.getUIContext().getPromptAction().showToast({ message: `已应用到${label}` });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '应用失败，请重试' });
    } finally {
      this.busyKey = '';
    }
  }

  private async applyToEveryGroup(): Promise<void> {
    if (this.hostContext === null || this.pendingPath.length === 0 || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'all';
    try {
      await PageBackgroundService.applyToAll(this.pendingPath, this.hostContext);
      this.selectedKeys = [];
      await this.refreshStates();
      this.getUIContext().getPromptAction().showToast({ message: '已应用到全部页面' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '应用失败，请重试' });
    } finally {
      this.busyKey = '';
    }
  }

  private isSelected(key: string): boolean {
    return this.selectedKeys.includes(key);
  }

  private toggleSelected(key: string): void {
    const next: string[] = [];
    let removed = false;
    for (const item of this.selectedKeys) {
      if (item === key) {
        removed = true;
      } else {
        next.push(item);
      }
    }
    if (!removed) {
      next.push(key);
    }
    this.selectedKeys = next;
    this.refreshAlpha();
  }

  private async applyToSelected(): Promise<void> {
    if (this.hostContext === null || this.pendingPath.length === 0 || this.busyKey.length > 0 ||
      this.selectedKeys.length === 0) {
      return;
    }
    this.busyKey = 'selected';
    try {
      for (const key of this.selectedKeys) {
        await PageBackgroundService.applyToGroup(key, this.pendingPath, this.hostContext);
      }
      const count = this.selectedKeys.length;
      this.selectedKeys = [];
      await this.refreshStates();
      this.getUIContext().getPromptAction().showToast({ message: `已应用到 ${count} 个页面` });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '应用失败，请重试' });
    } finally {
      this.busyKey = '';
    }
  }

  private async clearGroup(group: string, label: string): Promise<void> {
    if (this.hostContext === null || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = group;
    try {
      await PageBackgroundService.clear(group, this.hostContext);
      await this.refreshStates();
      this.getUIContext().getPromptAction().showToast({ message: `已清除${label}的背景` });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '清除失败，请重试' });
    } finally {
      this.busyKey = '';
    }
  }

  private async clearGlobalImage(): Promise<void> {
    if (this.hostContext === null || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'clearGlobal';
    try {
      await PageBackgroundService.clearGlobal(this.hostContext);
      await this.refreshStates();
      this.getUIContext().getPromptAction().showToast({ message: '已清除全局默认背景' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '清除失败，请重试' });
    } finally {
      this.busyKey = '';
    }
  }

  private async clearEveryGroup(): Promise<void> {
    if (this.hostContext === null || this.busyKey.length > 0) {
      return;
    }
    this.busyKey = 'clearAll';
    try {
      await PageBackgroundService.clearAll(this.hostContext);
      await this.refreshStates();
      this.getUIContext().getPromptAction().showToast({ message: '已清除全部页面背景' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '清除失败，请重试' });
    } finally {
      this.busyKey = '';
    }
  }

  private async updateOpacity(value: number): Promise<void> {
    this.imageOpacity = value / 100;
    if (this.hostContext === null) {
      return;
    }
    try {
      await PageBackgroundService.setOpacity(this.hostContext, this.imageOpacity);
    } catch (error) {
    }
  }

  private async finish(): Promise<void> {
    if (this.hostContext !== null) {
      await PageBackgroundService.discardPending(this.hostContext);
    }
    this.navStack.pop();
  }

  private appliedCount(): number {
    let total = 0;
    for (const state of this.states) {
      if (state.applied) {
        total += 1;
      }
    }
    return total;
  }

  @Builder
  sourceSheet() {
    ImageSourceSheet({
      onPick: (source: BackgroundImageSource) => {
        this.showSourceSheet = false;
        this.pickAgain(source);
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(AppTheme.color.primary)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(Color.Transparent)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              SectionCard() {
                Column({ space: 10 }) {
                  Text('待应用的图片')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  if (this.pendingPath.length > 0) {
                    Image(fileUri.getUriFromPath(this.pendingPath))
                      .width('100%')
                      .height(190)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(10)
                      .opacity(this.imageOpacity + 0.35)
                      .accessibilityText('待应用的页面背景预览')
                      .onError(() => {
                        this.pendingPath = '';
                      })
                  } else {
                    Column() {
                      Text('还没有可应用的图片')
                        .fontSize(12)
                        .fontColor(AppTheme.color.textSecondary)
                      Text('从相册、相机或文件选一张，再决定用在哪几个页面')
                        .fontSize(11)
                        .fontColor(AppTheme.color.textMuted)
                        .margin({ top: 4 })
                    }
                    .width('100%')
                    .height(96)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .borderRadius(10)
                  }
                  Row({ space: 8 }) {
                    Text(this.busyKey === 'pick' ? '读取中…' : '重新选择图片')
                      .fontSize(12)
                      .fontColor(AppTheme.color.primary)
                      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                      .backgroundColor(AppTheme.color.tint)
                      .borderRadius(8)
                      .accessibilityText('重新选择背景图片来源')
                      .onClick(() => {
                        this.showSourceSheet = true;
                      })
                    Blank()
                    Text(`已应用 ${this.appliedCount()} 个页面`)
                      .fontSize(11)
                      .fontColor(AppTheme.color.textMuted)
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('全部页面（默认）')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('设为默认后，没有单独设置的模块都跟这张图；以后新增的模块也自动继承。')
                    .fontSize(11)
                    .lineHeight(17)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row({ space: 8 }) {
                    Text(this.globalApplied ? '已设置' : '未设置')
                      .fontSize(10)
                      .fontColor(this.globalApplied ? AppTheme.color.success : AppTheme.color.textMuted)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(this.globalApplied ? AppTheme.color.successSurface : AppTheme.color.surfaceAlt)
                      .borderRadius(6)
                    Blank()
                    if (this.globalApplied) {
                      Text('清除')
                        .fontSize(11)
                        .fontColor(AppTheme.color.danger)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .accessibilityText('清除全局默认背景')
                        .onClick(() => {
                          this.clearGlobalImage();
                        })
                    }
                    Text(this.busyKey === 'global' ? '设置中…' : '设为默认')
                      .fontSize(11)
                      .fontColor(Color.White)
                      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                      .backgroundColor(this.pendingPath.length > 0 ? AppTheme.color.primary : AppTheme.color.primaryDisabled)
                      .borderRadius(8)
                      .accessibilityText('把背景设为全部页面的默认背景')
                      .onClick(() => {
                        this.applyToGlobal();
                      })
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 10 }) {
                  Text('应用到哪些页面')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('点右侧按钮把这张图设为该模块所有页面的背景；同一模块内共享一张图。')
                    .fontSize(11)
                    .lineHeight(17)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  ForEach(this.states, (state: BackgroundGroupState) => {
                    Row({ space: 8 }) {
                      Text(this.isSelected(state.key) ? '✓' : '')
                        .fontSize(12)
                        .fontColor(Color.White)
                        .width(22)
                        .height(22)
                        .textAlign(TextAlign.Center)
                        .borderRadius(6)
                        .border({
                          width: 1,
                          color: this.isSelected(state.key) ? AppTheme.color.primary : AppTheme.color.borderStrong
                        })
                        .backgroundColor(this.isSelected(state.key) ? AppTheme.color.primary : Color.Transparent)
                        .accessibilityText(this.isSelected(state.key) ? `取消选择${state.label}` : `选择${state.label}`)
                        .onClick(() => {
                          this.toggleSelected(state.key);
                        })
                      Text(state.label)
                        .fontSize(13)
                        .fontColor(AppTheme.color.text)
                      Text(state.own ? '单独设置' : (state.following ? '跟随全局' : '未应用'))
                        .fontSize(10)
                        .fontColor(state.own ? AppTheme.color.success :
                          (state.following ? AppTheme.color.primary : AppTheme.color.textMuted))
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor(state.own ? AppTheme.color.successSurface :
                          (state.following ? AppTheme.color.tint : AppTheme.color.surfaceAlt))
                        .borderRadius(6)
                      Blank()
                      if (state.own) {
                        Text('清除')
                          .fontSize(11)
                          .fontColor(AppTheme.color.danger)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .accessibilityText(`清除${state.label}的页面背景`)
                          .onClick(() => {
                            this.clearGroup(state.key, state.label);
                          })
                      }
                      Text(this.busyKey === state.key ? '处理中…' :
                        (this.pendingPath.length > 0 ? '应用' : '选图'))
                        .fontSize(11)
                        .fontColor(Color.White)
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .backgroundColor(this.pendingPath.length > 0 ? AppTheme.color.primary : AppTheme.color.primaryDisabled)
                        .borderRadius(8)
                        .accessibilityText(`把背景应用到${state.label}`)
                        .onClick(() => {
                          if (this.pendingPath.length === 0) {
                            this.showSourceSheet = true;
                          } else {
                            this.applyTo(state.key, state.label);
                          }
                        })
                    }
                    .width('100%')
                    .padding({ top: 6, bottom: 6 })
                  }, (state: BackgroundGroupState) => `${state.key}-${state.applied}`)

                  Row({ space: 8 }) {
                    Text(this.busyKey === 'selected' ? '应用中…' : `应用到已选（${this.selectedKeys.length}）`)
                      .fontSize(12)
                      .fontColor(Color.White)
                      .textAlign(TextAlign.Center)
                      .layoutWeight(1)
                      .padding({ top: 9, bottom: 9 })
                      .backgroundColor(this.selectedKeys.length > 0 && this.pendingPath.length > 0 ?
                        AppTheme.color.primary : AppTheme.color.primaryDisabled)
                      .borderRadius(10)
                      .accessibilityText('把背景应用到已勾选的页面')
                      .onClick(() => {
                        this.applyToSelected();
                      })
                    Text(this.busyKey === 'all' ? '应用中…' : '全部应用')
                      .fontSize(12)
                      .fontColor(AppTheme.color.primary)
                      .textAlign(TextAlign.Center)
                      .layoutWeight(1)
                      .padding({ top: 9, bottom: 9 })
                      .backgroundColor(AppTheme.color.tint)
                      .borderRadius(10)
                      .accessibilityText('把背景应用到全部页面')
                      .onClick(() => {
                        this.applyToEveryGroup();
                      })
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('页面透明度')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text(this.selectedKeys.length > 0 ?
                    `作用于已选的 ${this.selectedKeys.length} 个页面；取消勾选后改的是全局值。` :
                    '作用于全部页面；勾选上面的页面可以对单个模块单独设置。')
                    .fontSize(11)
                    .lineHeight(17)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row({ space: 8 }) {
                    Text('不透明')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textMuted)
                    Slider({
                      value: (1 - this.surfaceAlpha) * 100,
                      min: 0,
                      max: 60,
                      step: 1
                    })
                      .layoutWeight(1)
                      .selectedColor(AppTheme.color.primary)
                      .onChange((value: number) => {
                        this.updateSurfaceAlpha(value);
                      })
                    Text(`${Math.round((1 - this.surfaceAlpha) * 100)}%`)
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                      .width(36)
                      .textAlign(TextAlign.End)
                  }
                  .width('100%')
                  Row() {
                    Text('没有图片也生效，透出页面后方的底色或壁纸。')
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                      .layoutWeight(1)
                    Text('恢复跟随')
                      .fontSize(11)
                      .fontColor(AppTheme.color.primary)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .accessibilityText('把页面透明度恢复为跟随全局或不透明')
                      .onClick(() => {
                        this.resetSurfaceAlpha();
                      })
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('背景浓淡')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Row({ space: 8 }) {
                    Text('淡')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textMuted)
                    Slider({
                      value: this.imageOpacity * 100,
                      min: 4,
                      max: 30,
                      step: 1
                    })
                      .layoutWeight(1)
                      .selectedColor(AppTheme.color.primary)
                      .onChange((value: number) => {
                        this.updateOpacity(value);
                      })
                    Text(`${Math.round(this.imageOpacity * 100)}%`)
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                      .width(36)
                      .textAlign(TextAlign.End)
                  }
                  .width('100%')
                  Text('数值越高图片越明显，正文可读性会相应下降。')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Row({ space: 8 }) {
                    Text('清除全部背景图片')
                      .fontSize(13)
                      .fontColor(AppTheme.color.danger)
                      .accessibilityText('清除全部页面的背景图片')
                      .onClick(() => {
                        this.clearEveryGroup();
                      })
                    Blank()
                    Text('恢复默认纯色底')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textMuted)
                  }
                  .width('100%')
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Column() {
            Text('完成')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 })
              .backgroundColor(AppTheme.color.primary)
              .borderRadius(12)
              .accessibilityText('完成背景设置并返回')
              .onClick(() => {
                this.finish();
              })
          }
          .width('100%')
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: 8, bottom: 24 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .bindSheet($$this.showSourceSheet, this.sourceSheet(), {
        height: 300,
        dragBar: false,
        backgroundColor: AppTheme.color.surface
      })
    }
    .title('页面背景')
    .backgroundColor(Color.Transparent)
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
    .onShown(() => {
      this.refreshStates();
    })
  }
}
