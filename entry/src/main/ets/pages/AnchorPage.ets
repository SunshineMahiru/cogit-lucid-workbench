import { Anchor } from '../model/Anchor';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { AnchorService } from '../anchor';
import { AnchorCard } from '../components/AnchorCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ROUTES } from '../navigation/Routes';
import { PlanAttachParams } from '../navigation/RouteParams';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PREVIEW_ANCHORS } from '../preview/PreviewData';
import { PREVIEW_WRITE_BLOCKED } from '../preview/PreviewMode';

/** Read-only value anchor library with a shortcut into the review flow. */
@ComponentV2
export struct AnchorPage {
  @Local service: AnchorService | null = null;
  @Local anchors: Anchor[] = [];
  @Local isLoading: boolean = true;
  @Local isSeeding: boolean = false;
  @Local isPreview: boolean = false;
  @Local newAnchorText: string = '';
  @Local isAdding: boolean = false;
  @Local reviseVisible: boolean = false;
  @Local reviseText: string = '';
  @Local reviseContext: string = '';
  @Local reviseReason: string = '';
  @Local reviseError: string = '';
  @Local isRevising: boolean = false;
  @Local retireVisible: boolean = false;
  @Local isRetiring: boolean = false;
  @Local versionsAnchorId: string = '';
  @Local versions: Anchor[] = [];
  private revisingAnchor: Anchor | null = null;
  private retiringAnchor: Anchor | null = null;
  @Local keyboardHeight: number = 0;
  private navStack: NavPathStack | null = null;
  private hasShownOnce: boolean = false;
  private windowRef: window.Window | null = null;

  aboutToAppear(): void {
    this.load();
    this.bindKeyboard();
  }

  aboutToDisappear(): void {
    if (this.windowRef !== null) {
      this.windowRef.off('keyboardHeightChange');
      this.windowRef = null;
    }
  }

  /** Keeps the sheet above the keyboard by tracking its height. */
  private bindKeyboard(): void {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return;
    }
    try {
      window.getLastWindow(hostContext).then((win: window.Window) => {
        this.windowRef = win;
        win.on('keyboardHeightChange', (height: number) => {
          this.keyboardHeight = height;
        });
      }).catch(() => {
      });
    } catch (error) {
    }
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await AnchorService.open(hostContext);
      this.anchors = await this.service.list();
      this.isLoading = false;
    } catch (error) {
      this.loadPreview();
      this.getUIContext().getPromptAction().showToast({ message: '锚点加载失败，已切换到演示数据' });
    }
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.anchors = PREVIEW_ANCHORS.slice();
    this.isLoading = false;
  }

  private async seed(): Promise<void> {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: PREVIEW_WRITE_BLOCKED });
      return;
    }
    if (this.service === null || this.isSeeding) {
      return;
    }
    this.isSeeding = true;
    try {
      const added = await this.service.seedDemoAnchors();
      this.anchors = await this.service.list();
      this.getUIContext().getPromptAction().showToast({
        message: added > 0 ? `已载入 ${added} 条示例锚点` : '已有锚点，未重复载入'
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '载入失败，请重试' });
    } finally {
      this.isSeeding = false;
    }
  }

  private async addAnchor(): Promise<void> {
    const text = this.newAnchorText.trim();
    if (text.length === 0 || this.isAdding) {
      return;
    }
    this.isAdding = true;
    try {
      if (this.isPreview) {
        const next = this.anchors.slice();
        next.push({
          id: `local_anchor_${Date.now()}`,
          text: text,
          source: '自写',
          order: next.length
        });
        this.anchors = next;
      } else if (this.service !== null) {
        await this.service.create(text);
        this.anchors = await this.service.list();
      }
      this.newAnchorText = '';
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '锚点保存失败，请重试' });
    } finally {
      this.isAdding = false;
    }
  }

  private openReview(): void {
    if (this.navStack === null) {
      return;
    }
    this.navStack.pushPathByName(ROUTES.REVIEW, null);
  }

  private openRevise(anchor: Anchor): void {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: PREVIEW_WRITE_BLOCKED });
      return;
    }
    this.revisingAnchor = anchor;
    this.reviseText = anchor.text;
    this.reviseContext = anchor.context ?? '';
    this.reviseReason = '';
    this.reviseError = '';
    this.reviseVisible = true;
  }

  private async confirmRevise(): Promise<void> {
    if (this.revisingAnchor === null || this.isRevising) {
      return;
    }
    if (this.reviseText.trim().length === 0) {
      this.reviseError = '写一句新的锚点';
      return;
    }
    if (this.reviseReason.trim().length === 0) {
      this.reviseError = '写一句这次修订的原因';
      return;
    }
    if (this.service === null) {
      this.reviseError = '数据库尚未就绪';
      return;
    }
    this.reviseError = '';
    this.isRevising = true;
    try {
      const next = await this.service.revise(this.revisingAnchor.id, this.reviseText,
        this.reviseContext, this.reviseReason);
      this.reviseVisible = false;
      await this.reloadAnchors();
      this.getUIContext().getPromptAction().showToast({ message: `已生成第 ${next.version ?? 1} 版` });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '修订失败，请重试' });
    } finally {
      this.isRevising = false;
    }
  }

  private openRetire(anchor: Anchor): void {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: PREVIEW_WRITE_BLOCKED });
      return;
    }
    this.retiringAnchor = anchor;
    this.retireVisible = true;
  }

  private async confirmRetire(): Promise<void> {
    if (this.retiringAnchor === null || this.isRetiring) {
      return;
    }
    if (this.service === null) {
      return;
    }
    this.isRetiring = true;
    try {
      await this.service.retire(this.retiringAnchor.id);
      this.retireVisible = false;
      await this.reloadAnchors();
      this.getUIContext().getPromptAction().showToast({ message: '已停用' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '停用失败，请重试' });
    } finally {
      this.isRetiring = false;
    }
  }

  private async toggleVersions(anchor: Anchor): Promise<void> {
    if (this.versionsAnchorId === anchor.id) {
      this.versionsAnchorId = '';
      this.versions = [];
      return;
    }
    if (this.isPreview || this.service === null) {
      this.versions = [anchor];
      this.versionsAnchorId = anchor.id;
      return;
    }
    try {
      const rows = await this.service.versions(anchor.id);
      this.versions = rows;
      this.versionsAnchorId = anchor.id;
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '版本读取失败，请重试' });
    }
  }

  private async reloadAnchors(): Promise<void> {
    if (this.service !== null) {
      this.anchors = await this.service.list();
    }
    this.versionsAnchorId = '';
    this.versions = [];
  }

  private openAttach(anchor: Anchor): void {
    if (this.navStack === null) {
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.ANCHOR,
      targetId: anchor.id,
      label: anchor.text
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  @Builder
  headerCard() {
    Column({ space: 6 }) {
      Row() {
        Text('北极星句段库')
          .fontSize(AppTheme.font.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.color.text)
        Blank()
        Text(`${this.anchors.length} 条`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
      }
      .width('100%')

      Text('复盘第三步用来对照的稳定句子；新建后只读。')
        .fontSize(AppTheme.font.bodyStrong)
        .lineHeight(18)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.newAnchorText, placeholder: '写一条自己的锚点' })
          .id('anchor_input')
          .maxLength(80)
          .layoutWeight(1)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .onChange((value: string) => {
            this.newAnchorText = value;
          })
        Text(this.isAdding ? '保存中' : '添加')
          .id('anchor_add')
          .fontSize(AppTheme.font.bodyStrong)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.addAnchor();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  reviseSheet() {
    Column({ space: AppTheme.spacing.s8 }) {
      Text('修订锚点')
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      TextArea({ text: this.reviseText, placeholder: '句子（必填）' })
        .id('anchor_revise_text')
        .height(72)
        .maxLength(80)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .onChange((value: string) => {
          this.reviseText = value;
          this.reviseError = '';
        })
      TextInput({ text: this.reviseContext, placeholder: '适用情境（可空）' })
        .id('anchor_revise_context')
        .backgroundColor(AppTheme.color.surfaceAlt)
        .onChange((value: string) => {
          this.reviseContext = value;
        })
      TextArea({ text: this.reviseReason, placeholder: '修订原因（必填）' })
        .id('anchor_revise_reason')
        .height(56)
        .maxLength(120)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .onChange((value: string) => {
          this.reviseReason = value;
          this.reviseError = '';
        })
      if (this.reviseError.length > 0) {
        Text(this.reviseError)
          .fontSize(AppTheme.font.caption)
          .fontColor(AppTheme.color.danger)
          .width('100%')
      }
      Row({ space: AppTheme.spacing.s8 }) {
        Text('取消')
          .id('anchor_revise_cancel')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.reviseVisible = false;
          })
        Text(this.isRevising ? '修订中…' : '确认修订')
          .id('anchor_revise_confirm')
          .fontSize(AppTheme.font.body)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(this.isRevising ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.confirmRevise();
          })
      }
      .width('100%')
    }
    .id('anchor_revise_panel')
    .width('100%')
    .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s16,
      bottom: AppTheme.spacing.s16 + this.keyboardHeight })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  retireSheet() {
    Column({ space: AppTheme.spacing.s8 }) {
      Text('停用这条锚点？')
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text('停用后不再出现在新复盘里，历史复盘仍保留这句话。')
        .fontSize(AppTheme.font.body)
        .lineHeight(18)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
      Row({ space: AppTheme.spacing.s8 }) {
        Text('取消')
          .id('anchor_retire_cancel')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.retireVisible = false;
          })
        Text(this.isRetiring ? '停用中…' : '确认停用')
          .id('anchor_retire_confirm')
          .fontSize(AppTheme.font.body)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
          .backgroundColor(this.isRetiring ? AppTheme.color.primaryDisabled : AppTheme.color.danger)
          .borderRadius(AppTheme.radius.sm)
          .onClick(() => {
            this.confirmRetire();
          })
      }
      .width('100%')
    }
    .id('anchor_retire_panel')
    .width('100%')
    .padding(AppTheme.spacing.s16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  versionList() {
    Column({ space: AppTheme.spacing.s6 }) {
      Text('历史版本')
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
        .width('100%')
      ForEach(this.versions, (item: Anchor) => {
        Column({ space: 3 }) {
          Row({ space: AppTheme.spacing.s8 }) {
            Text(`v${item.version ?? 1}`)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.primaryDeep)
            Text(item.status === 'retired' ? '已停用' : '在用')
              .fontSize(AppTheme.font.caption)
              .fontColor(item.status === 'retired' ? AppTheme.color.textMuted : AppTheme.color.success)
            Text(item.source)
              .fontSize(AppTheme.font.caption)
              .fontColor(AppTheme.color.textMuted)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          Text(item.text)
            .fontSize(AppTheme.font.body)
            .lineHeight(18)
            .fontColor(AppTheme.color.text)
            .width('100%')
          if (item.revisionReason !== undefined && item.revisionReason.length > 0) {
            Text(`原因：${item.revisionReason}`)
              .fontSize(AppTheme.font.caption)
              .lineHeight(17)
              .fontColor(AppTheme.color.textMuted)
              .width('100%')
          }
        }
        .width('100%')
        .padding(AppTheme.spacing.s10)
        .backgroundColor(AppTheme.color.surfaceAlt)
        .borderRadius(AppTheme.radius.sm)
        .alignItems(HorizontalAlign.Start)
      }, (item: Anchor) => item.id)
    }
    .id('anchor_version_list')
    .width('100%')
    .padding(AppTheme.spacing.s12)
    .backgroundColor(AppTheme.color.surface)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    AppDestination({
      route: 'anchor',
      title: '价值锚点',
      content: () => {
        this.anchorBody();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
      },
      onDestinationShown: () => {
        if (this.hasShownOnce) {
          this.load();
        } else {
          this.hasShownOnce = true;
        }
      }
    })
  }

  @Builder
  anchorBody() {
      Column() {
        Column() {
          this.headerCard()
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s12 })
        .bindSheet($$this.retireVisible, this.retireSheet(), {
          height: 240,
          dragBar: false,
          backgroundColor: AppTheme.color.surface
        })

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
        } else if (this.anchors.length === 0) {
          Column() {
            NoteEmptyState({
              title: '锚点库还是空的',
              hint: '锚点用于复盘时对照；示例数据仅用于演示',
              actionLabel: this.isSeeding ? '载入中…' : '载入示例锚点',
              dashed: true,
              onAction: () => {
                this.seed();
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16 })
        } else {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.anchors, (anchor: Anchor, index: number) => {
                Column({ space: AppTheme.spacing.s8 }) {
                  AnchorCard({
                    anchor: anchor,
                    index: index + 1,
                    onAttachPlan: () => {
                      this.openAttach(anchor);
                    },
                    onRevise: () => {
                      this.openRevise(anchor);
                    },
                    onRetire: () => {
                      this.openRetire(anchor);
                    },
                    onVersions: () => {
                      this.toggleVersions(anchor);
                    }
                  })
                  if (this.versionsAnchorId === anchor.id) {
                    this.versionList()
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }, (anchor: Anchor) => anchor.id)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })

          Column() {
            Text('用它做一次复盘')
              .fontSize(AppTheme.font.subtitle)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(AppTheme.color.primary)
              .borderRadius(AppTheme.radius.md)
              .onClick(() => {
                this.openReview();
              })
          }
          .width('100%')
          .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, bottom: AppTheme.spacing.s24, top: AppTheme.spacing.s4 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .bindSheet($$this.reviseVisible, this.reviseSheet(), {
        height: 420 + this.keyboardHeight,
        dragBar: false,
        backgroundColor: AppTheme.color.surface
      })
  }
}
