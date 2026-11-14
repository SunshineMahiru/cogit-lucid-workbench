import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { RelationTrustBadge } from '../components/RelationTrustBadge';
import { NoteEmptyState } from '../components/NoteEmptyState';
import {
  RelationDetail,
  RelationService,
  formatInteractionTime,
  trustLevelText,
  disclosureBoundaryOf,
  SOURCE_OPTIONS,
  CITATION_OPTIONS,
  sourceText,
  citationText,
  toInteractionSource,
  toCitationScope,
  isOtherStatement
} from '../relation';
import { CitationScope, InteractionLog, InteractionSource } from '../model/Relation';
import { SecurityLevel } from '../model/SecurityLevel';
import { TrustLevel } from '../model/TrustLevel';
import { securityLevelText } from '../note';
import { RelationDetailParams, RelationEditParams, PlanAttachParams } from '../navigation/RouteParams';
import { PlanLinkModule } from '../model/PlanLinkModule';
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
    correction: '',
    correctionAt: 0,
    linkedEvents: [],
    linkedDecisions: []
  };
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  @Local boundaryShare: string = '';
  @Local boundaryRule: string = '';
  @Local isPreview: boolean = false;
  @Local deleted: boolean = false;
  @Local undoVisible: boolean = false;
  @Local newInteraction: string = '';
  @Local newSource: InteractionSource = 'observation';
  @Local newCitation: CitationScope = 'hidden';
  @Local newAllowContext: boolean = false;
  @Local isAdding: boolean = false;
  private navStack: NavPathStack | null = null;
  private service: RelationService | null = null;
  private hasShownOnce: boolean = false;

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
        const boundary = disclosureBoundaryOf(detail.trustLevel, detail.forbidAnalysis);
        this.boundaryShare = boundary.shareable;
        this.boundaryRule = boundary.rule;
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
      const boundary = disclosureBoundaryOf(detail.trustLevel, detail.forbidAnalysis);
      this.boundaryShare = boundary.shareable;
      this.boundaryRule = boundary.rule;
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

  private openAttach(): void {
    if (this.navStack === null || this.detail.id.length === 0) {
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.RELATION,
      targetId: this.detail.id,
      label: this.detail.name
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  private async addInteraction(): Promise<void> {
    const text = this.newInteraction.trim();
    if (text.length === 0 || this.isAdding) {
      return;
    }
    this.isAdding = true;
    try {
      if (this.isPreview) {
        const now = Date.now();
        const entry: InteractionLog = {
          timestamp: now,
          content: text,
          source: this.newSource,
          citation: this.newCitation,
          allowContext: this.newAllowContext
        };
        const log: InteractionLog[] = [entry].concat(this.detail.interactionLog);
        this.detail = {
          id: this.detail.id,
          name: this.detail.name,
          trustLevel: this.detail.trustLevel,
          interactionCount: log.length,
          lastInteractionLabel: formatInteractionTime(now),
          lastInteractionAt: now,
          rawMaterialTest: this.detail.rawMaterialTest,
          forbidAnalysis: this.detail.forbidAnalysis,
          level: this.detail.level,
          notes: this.detail.notes,
          interactionLog: log,
          correction: this.detail.correction,
          correctionAt: this.detail.correctionAt,
          linkedEvents: this.detail.linkedEvents,
          linkedDecisions: this.detail.linkedDecisions
        };
      } else if (this.service !== null) {
        this.detail = await this.service.addInteraction(this.detail.id, text,
          this.newSource, this.newCitation, this.newAllowContext);
      }
      this.newInteraction = '';
      this.newSource = 'observation';
      this.newCitation = 'hidden';
      this.newAllowContext = false;
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '互动记录保存失败，请重试' });
    } finally {
      this.isAdding = false;
    }
  }

  private async cycleCitation(log: InteractionLog): Promise<void> {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '演示模式下不能修改引用范围' });
      return;
    }
    if (this.service === null) {
      return;
    }
    const current = toCitationScope(log.citation ?? '');
    const next: CitationScope = current === 'hidden' ? 'paraphrase' : (current === 'paraphrase' ? 'quote' : 'hidden');
    try {
      this.detail = await this.service.updateInteractionScope(this.detail.id, log.timestamp, next,
        log.allowContext === true);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '引用范围保存失败，请重试' });
    }
  }

  private async toggleContext(log: InteractionLog): Promise<void> {
    if (this.isPreview) {
      this.getUIContext().getPromptAction().showToast({ message: '演示模式下不能修改上下文许可' });
      return;
    }
    if (this.service === null) {
      return;
    }
    try {
      this.detail = await this.service.updateInteractionScope(this.detail.id, log.timestamp,
        toCitationScope(log.citation ?? ''), log.allowContext !== true);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '上下文许可保存失败，请重试' });
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
      Text('计划')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s6 })
        .onClick(() => {
          this.openAttach();
        })
      Text('编辑')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.primary)
        .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s8 })
        .accessibilityText('编辑关系')
        .onClick(() => {
          this.openEditor();
        })
      Text('删除')
        .fontSize(AppTheme.font.subtitle)
        .fontColor(AppTheme.color.danger)
        .padding({ left: AppTheme.spacing.s4, right: AppTheme.spacing.s16 })
        .accessibilityText('删除关系，可撤销')
        .onClick(() => {
          this.deleteRelation();
        })
    }
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.textSecondary)
      Text(value)
        .fontSize(AppTheme.font.bodyStrong)
        .fontColor(AppTheme.color.text)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
  }

  build() {
    AppDestination({
      route: 'relation_detail',
      title: '关系详情',
      content: () => {
        this.relationDetailBody();
      },
      menus: () => {
        this.editMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          this.missing = true;
          return;
        }
        const params = context.pathInfo.param as RelationDetailParams;
        this.load(params.relationId);
      },
      onDestinationShown: () => {
        if (!this.hasShownOnce) {
          this.hasShownOnce = true;
          return;
        }
        if (this.detail.id.length > 0) {
          this.load(this.detail.id);
        }
      }
    })
  }

  @Builder
  relationDetailBody() {
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
        .backgroundColor(Color.Transparent)
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
        .backgroundColor(Color.Transparent)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            if (this.undoVisible) {
              SectionCard() {
                Row({ space: 8 }) {
                  Text('关系已删除')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.textSecondary)
                  Blank()
                  Text('撤销')
                    .fontSize(AppTheme.font.bodyStrong)
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
                    .fontSize(AppTheme.font.headline)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.color.text)
                    .layoutWeight(1)
                  RelationTrustBadge({ level: this.detail.trustLevel })
                }
                .width('100%')

                Row({ space: 6 }) {
                  if (this.detail.forbidAnalysis) {
                    Text('禁分析')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.danger)
                      .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                      .backgroundColor(AppTheme.color.dangerSurface)
                      .borderRadius(AppTheme.radius.sm)
                  }
                  Blank()
                  Text(this.detail.lastInteractionLabel)
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textMuted)
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column() {
                this.infoRow('披露层级', trustLevelText(this.detail.trustLevel))
                this.infoRow('密级', securityLevelText(this.detail.level))
                this.infoRow('互动次数', `${this.detail.interactionCount} 次`)
                this.infoRow('最近互动', this.detail.lastInteractionLabel)
              }
              .width('100%')
            }

            SectionCard() {
              Column({ space: 5 }) {
                Text('披露与引用边界')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Text(this.boundaryShare)
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontWeight(FontWeight.Medium)
                  .lineHeight(20)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
                Text(this.boundaryRule)
                  .fontSize(AppTheme.font.body)
                  .lineHeight(18)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.detail.correction.length > 0) {
              SectionCard() {
                Column({ space: 5 }) {
                  Text('对方怎样纠正了我的理解')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text(this.detail.correction)
                    .fontSize(AppTheme.font.bodyStrong)
                    .lineHeight(20)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }

            SectionCard() {
              Column({ space: 5 }) {
                Text('关联记录')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                if (this.detail.linkedEvents.length === 0 && this.detail.linkedDecisions.length === 0) {
                  Text('暂无速记或决策引用这条关系')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                } else {
                  ForEach(this.detail.linkedEvents, (title: string, index: number) => {
                    Text(`速记 · ${title}`)
                      .fontSize(AppTheme.font.bodyStrong)
                      .lineHeight(19)
                      .fontColor(AppTheme.color.text)
                      .width('100%')
                  }, (title: string, index: number) => `ev_${index}_${title}`)
                  ForEach(this.detail.linkedDecisions, (title: string, index: number) => {
                    Text(`决策 · ${title}`)
                      .fontSize(AppTheme.font.bodyStrong)
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
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text(this.detail.notes)
                    .fontSize(AppTheme.font.bodyStrong)
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
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Text('先选这条属于谁的：自己的观察、对方明确说过的话、共同做的事，还是自己的推测。')
                  .fontSize(AppTheme.font.caption)
                  .lineHeight(15)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(SOURCE_OPTIONS, (option: InteractionSource) => {
                    Text(sourceText(option))
                      .fontSize(AppTheme.font.caption)
                      .fontColor(this.newSource === option ? Color.White : AppTheme.color.text)
                      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                      .backgroundColor(this.newSource === option ? AppTheme.color.primary : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.md)
                      .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
                      .id(`relation_source_${option}`)
                      .onClick(() => {
                        this.newSource = option;
                        if (option !== 'stated') {
                          this.newCitation = 'hidden';
                          this.newAllowContext = false;
                        }
                      })
                  }, (option: InteractionSource) => option)
                }
                .width('100%')
                if (this.newSource === 'stated') {
                  Text('对方的话默认只留在本机；引用范围与上下文许可按这一条单独选择。')
                    .fontSize(AppTheme.font.caption)
                    .lineHeight(15)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(CITATION_OPTIONS, (option: CitationScope) => {
                      Text(citationText(option))
                        .fontSize(AppTheme.font.caption)
                        .fontColor(this.newCitation === option ? Color.White : AppTheme.color.text)
                        .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                        .backgroundColor(this.newCitation === option ? AppTheme.color.primary : AppTheme.color.chip)
                        .borderRadius(AppTheme.radius.md)
                        .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s4 })
                        .id(`relation_citation_${option}`)
                        .onClick(() => {
                          this.newCitation = option;
                        })
                    }, (option: CitationScope) => option)
                  }
                  .width('100%')
                  Text(this.newAllowContext ? '可进入模型上下文 · 已允许' : '可进入模型上下文 · 未允许')
                    .fontSize(AppTheme.font.caption)
                    .fontColor(this.newAllowContext ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                    .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s4, bottom: AppTheme.spacing.s4 })
                    .backgroundColor(this.newAllowContext ? AppTheme.color.tint : AppTheme.color.chip)
                    .borderRadius(AppTheme.radius.md)
                    .id('relation_context_toggle')
                    .onClick(() => {
                      this.newAllowContext = !this.newAllowContext;
                    })
                }
                Row({ space: 8 }) {
                  TextInput({ text: this.newInteraction, placeholder: '补一条互动记录' })
                    .id('relation_interaction_input')
                    .maxLength(200)
                    .layoutWeight(1)
                    .backgroundColor(AppTheme.color.surfaceAlt)
                    .onChange((value: string) => {
                      this.newInteraction = value;
                    })
                  Text(this.isAdding ? '保存中' : '添加')
                    .id('relation_interaction_add')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.primary)
                    .onClick(() => {
                      this.addInteraction();
                    })
                }
                .width('100%')
                if (this.detail.interactionLog.length === 0) {
                  Text('暂无互动记录')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                } else {
                  ForEach(this.detail.interactionLog, (log: InteractionLog, index: number) => {
                    Column({ space: 3 }) {
                      Row({ space: 6 }) {
                        Text(sourceText(toInteractionSource(log.source ?? '')))
                          .fontSize(AppTheme.font.caption)
                          .fontColor(isOtherStatement(log) ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                          .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                          .backgroundColor(isOtherStatement(log) ? AppTheme.color.tint : AppTheme.color.chip)
                          .borderRadius(AppTheme.radius.sm)
                        Blank()
                        Text(formatInteractionTime(log.timestamp))
                          .fontSize(AppTheme.font.caption)
                          .fontColor(AppTheme.color.textMuted)
                      }
                      .width('100%')
                      Text(log.content)
                        .fontSize(AppTheme.font.bodyStrong)
                        .lineHeight(20)
                        .fontColor(AppTheme.color.text)
                        .width('100%')
                      if (isOtherStatement(log)) {
                        Row({ space: 6 }) {
                          Text(citationText(toCitationScope(log.citation ?? '')))
                            .fontSize(AppTheme.font.caption)
                            .fontColor(AppTheme.color.primary)
                            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                            .backgroundColor(AppTheme.color.surfaceAlt)
                            .borderRadius(AppTheme.radius.sm)
                            .accessibilityText('切换引用范围')
                            .onClick(() => {
                              this.cycleCitation(log);
                            })
                          Text(log.allowContext === true ? '可进上下文' : '不进上下文')
                            .fontSize(AppTheme.font.caption)
                            .fontColor(log.allowContext === true ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                            .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                            .backgroundColor(log.allowContext === true ? AppTheme.color.tint : AppTheme.color.chip)
                            .borderRadius(AppTheme.radius.sm)
                            .onClick(() => {
                              this.toggleContext(log);
                            })
                        }
                        .width('100%')
                      }
                    }
                    .width('100%')
                    .padding({ bottom: AppTheme.spacing.s6 })
                  }, (log: InteractionLog, index: number) =>
                    `${log.timestamp}_${index}_${log.citation ?? ''}_${log.allowContext === true ? 1 : 0}`)
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
        .backgroundColor(Color.Transparent)
      }
  }
}
