import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { RelationTrustBadge } from '../components/RelationTrustBadge';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { RelationDetail, RelationService, formatInteractionTime, trustLevelText, relationTrustDecision } from '../relation';
import { InteractionLog } from '../model/Relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';
import { securityLevelText } from '../note';
import { RelationDetailParams, RelationEditParams } from '../navigation/RouteParams';
import { ROUTES } from '../navigation/Routes';
import { findPreviewRelation } from '../preview/PreviewData';

/** Read-only relation detail: tier, flags, notes and the interaction timeline. */
@ComponentV2
export struct RelationDetailPage {
  @Local detail: RelationDetail = {
    id: '',
    name: '',
    trustLevel: TrustLevel.FRIENDLY,
    interactionCount: 0,
    lastInteractionLabel: '',
    lastInteractionAt: 0,
    rawMaterialTest: false,
    forbidAnalysis: false,
    level: SecurityLevel.LOCAL_ONLY,
    notes: '',
    interactionLog: [],
    linkedEvents: [],
    linkedDecisions: []
  };
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local trustAllowed: boolean = false;
  @Local trustReason: string = '';
  @Local isPreview: boolean = false;
  @Local deleted: boolean = false;
  @Local undoVisible: boolean = false;
  private navStack: NavPathStack | null = null;
  private service: RelationService | null = null;

  private async load(relationId: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview(relationId);
      return;
    }
    try {
      const service = await RelationService.open(hostContext);
      this.service = service;
      const detail = await service.find(relationId);
      if (detail === null) {
        this.missing = true;
      } else {
        this.detail = detail;
        const decision = relationTrustDecision(detail);
        this.trustAllowed = decision.allowMotiveAnalysis;
        this.trustReason = decision.reason;
      }
    } catch (error) {
      this.loadPreview(relationId);
    } finally {
      this.isLoading = false;
    }
  }

  private loadPreview(relationId: string): void {
    this.isPreview = true;
    const detail = findPreviewRelation(relationId);
    if (detail === null) {
      this.missing = true;
    } else {
      this.detail = detail;
      const decision = relationTrustDecision(detail);
      this.trustAllowed = decision.allowMotiveAnalysis;
      this.trustReason = decision.reason;
    }
    this.isLoading = false;
  }

  private async deleteRelation(): Promise<void> {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '演示模式下不能删除关系' });
      return;
    }
    if (this.service === null || this.detail.id.length === 0) {
      return;
    }
    try {
      await this.service.softDelete(this.detail.id);
      this.deleted = true;
      this.undoVisible = true;
      this.getUIContext().getPromptAction().showToast({ message: '已删除，可撤销' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '删除失败，请重试' });
    }
  }

  private async undoDelete(): Promise<void> {
    if (this.service === null || !this.deleted) {
      return;
    }
    try {
      await this.service.restore(this.detail.id);
      this.deleted = false;
      this.undoVisible = false;
      this.getUIContext().getPromptAction().showToast({ message: '已恢复关系' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '恢复失败，请重试' });
    }
  }

  private openEditor(): void {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '演示模式下不能编辑关系' });
      return;
    }
    if (this.navStack === null || this.detail.id.length === 0) {
      return;
    }
    const params: RelationEditParams = { relationId: this.detail.id };
    this.navStack.pushPathByName(ROUTES.RELATION_EDIT, params, () => {
      this.load(this.detail.id);
    });
  }

  @Builder
  editMenu() {
    Row({ space: 4 }) {
      Text('编辑')
        .fontSize(14)
        .fontColor(AppTheme.color.primary)
        .padding({ left: 10, right: 8 })
        .accessibilityText('编辑关系')
        .onClick(() => {
          this.openEditor();
        })
      Text('删除')
        .fontSize(14)
        .fontColor(AppTheme.color.danger)
        .padding({ left: 4, right: 16 })
        .accessibilityText('删除关系，可撤销')
        .onClick(() => {
          this.deleteRelation();
        })
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(12)
        .fontColor(AppTheme.color.textSecondary)
      Text(value)
        .fontSize(12)
        .fontColor(AppTheme.color.text)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    NavDestination() {
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
        .backgroundColor(AppTheme.color.page)
      } else if (this.missing) {
        Column() {
          NoteEmptyState({
            title: '关系记录不存在',
            hint: '可能已经被删除',
            actionLabel: '返回',
            onAction: () => {
              if (this.navStack !== null) {
                this.navStack.pop();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.color.page)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            if (this.undoVisible) {
              SectionCard() {
                Row({ space: 8 }) {
                  Text('关系已删除')
                    .fontSize(12)
                    .fontColor(AppTheme.color.textSecondary)
                  Blank()
                  Text('撤销')
                    .fontSize(12)
                    .fontColor(AppTheme.color.primary)
                    .accessibilityText('撤销删除关系')
                    .onClick(() => {
                      this.undoDelete();
                    })
                }
                .width('100%')
              }
            }

            SectionCard() {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  Text(this.detail.name)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.color.text)
                    .layoutWeight(1)
                  RelationTrustBadge({ level: this.detail.trustLevel })
                }
                .width('100%')

                Row({ space: 6 }) {
                  if (this.detail.rawMaterialTest) {
                    Text('未加工材料')
                      .fontSize(10)
                      .fontColor(AppTheme.color.primaryDeep)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(AppTheme.color.tint)
                      .borderRadius(6)
                  }
                  if (this.detail.forbidAnalysis) {
                    Text('禁分析')
                      .fontSize(10)
                      .fontColor(AppTheme.color.danger)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(AppTheme.color.dangerSurface)
                      .borderRadius(6)
                  }
                  Blank()
                  Text(this.detail.lastInteractionLabel)
                    .fontSize(11)
                    .fontColor(AppTheme.color.textMuted)
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column() {
                this.infoRow('信任层级', trustLevelText(this.detail.trustLevel))
                this.infoRow('密级', securityLevelText(this.detail.level))
                this.infoRow('互动次数', `${this.detail.interactionCount} 次`)
                this.infoRow('最近互动', this.detail.lastInteractionLabel)
              }
              .width('100%')
            }

            SectionCard() {
              Column({ space: 5 }) {
                Text('可分析边界')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Text(this.trustAllowed ? '允许动机分析' : '仅描述，不做动机分析')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.trustAllowed ? AppTheme.color.success : AppTheme.color.warning)
                  .width('100%')
                Text(this.trustReason)
                  .fontSize(11)
                  .lineHeight(18)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 5 }) {
                Text('关联记录')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                if (this.detail.linkedEvents.length === 0 && this.detail.linkedDecisions.length === 0) {
                  Text('暂无速记或决策引用这条关系')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                } else {
                  ForEach(this.detail.linkedEvents, (title: string, index: number) => {
                    Text(`速记 · ${title}`)
                      .fontSize(12)
                      .lineHeight(19)
                      .fontColor(AppTheme.color.text)
                      .width('100%')
                  }, (title: string, index: number) => `ev_${index}_${title}`)
                  ForEach(this.detail.linkedDecisions, (title: string, index: number) => {
                    Text(`决策 · ${title}`)
                      .fontSize(12)
                      .lineHeight(19)
                      .fontColor(AppTheme.color.text)
                      .width('100%')
                  }, (title: string, index: number) => `dc_${index}_${title}`)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.detail.notes.length > 0) {
              SectionCard() {
                Column({ space: 6 }) {
                  Text('备注')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text(this.detail.notes)
                    .fontSize(13)
                    .lineHeight(21)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }

            SectionCard() {
              Column({ space: 10 }) {
                Text('互动记录')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                if (this.detail.interactionLog.length === 0) {
                  Text('暂无互动记录')
                    .fontSize(12)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                } else {
                  ForEach(this.detail.interactionLog, (log: InteractionLog, index: number) => {
                    Column({ space: 3 }) {
                      Text(formatInteractionTime(log.timestamp))
                        .fontSize(10)
                        .fontColor(AppTheme.color.textMuted)
                        .width('100%')
                      Text(log.content)
                        .fontSize(13)
                        .lineHeight(20)
                        .fontColor(AppTheme.color.text)
                        .width('100%')
                    }
                    .width('100%')
                    .padding({ bottom: 6 })
                  }, (log: InteractionLog, index: number) => `${log.timestamp}_${index}`)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.page)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(AppTheme.color.page)
      }
    }
    .title('关系详情')
    .menus(this.editMenu)
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      if (context.pathInfo.param === undefined) {
        this.isLoading = false;
        this.missing = true;
        return;
      }
      const params = context.pathInfo.param as RelationDetailParams;
      this.load(params.relationId);
    })
  }
}
