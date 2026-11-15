import { AppTheme } from '../theme/AppTheme';
import { common } from '@kit.AbilityKit';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { ReviewDetailView, ReviewService } from '../review';
import { ReviewDecisionItem } from '../review/ReviewService';
import { Anchor } from '../model/Anchor';
import { CostDimension, CostNote } from '../model/CostNote';
import { EvidenceEffect, EvidenceItem, EvidenceSource } from '../model/EvidenceItem';
import { ReviewMaterial } from '../model/ReviewMaterial';
import { ReviewPayload } from '../model/ReviewPayload';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { SecurityLevel } from '../model/SecurityLevel';
import { ReviewDetailParams, PlanNodeParams, PlanAttachParams } from '../navigation/RouteParams';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { ROUTES } from '../navigation/Routes';
import { previewStore } from '../preview/PreviewStore';
import { DbHelper } from '../db/DbHelper';
import { EvidenceItemDao } from '../db/dao/EvidenceItemDao';
import { ReviewResultDao } from '../db/dao/ReviewResultDao';

/** Read-only review: six zones when the record carries them, otherwise the four legacy steps. */
@ComponentV2
export struct ReviewDetailPage {
  @Local detail: ReviewDetailView = {
    id: '',
    period: ReviewPeriod.WEEK,
    periodLabel: '',
    rangeLabel: '',
    action: '',
    createdAtLabel: '',
    anchorCount: 0,
    facts: '',
    interpretation: '',
    contradiction: '',
    anchors: []
  };
  @Local payload: ReviewPayload | null = null;
  @Local cited: ReviewMaterial[] = [];
  @Local citedDecisions: ReviewDecisionItem[] = [];
  @Local evidence: EvidenceItem[] = [];
  @Local costs: CostNote[] = [];
  @Local isLoading: boolean = true;
  @Local missing: boolean = false;
  private navStack: NavPathStack | null = null;

  private async load(reviewId: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview(reviewId);
      return;
    }
    try {
      const service = await ReviewService.open(hostContext);
      const detail = await service.find(reviewId);
      if (detail === null) {
        this.missing = true;
      } else {
        this.detail = detail;
        this.payload = await this.loadPayload(reviewId, hostContext);
        this.cited = await this.loadCited(reviewId, service);
        this.citedDecisions = await this.loadCitedDecisions(reviewId, service);
        this.evidence = await this.loadEvidence(reviewId, hostContext);
        this.costs = await this.loadCosts(reviewId, service);
      }
    } catch (error) {
      this.loadPreview(reviewId);
    } finally {
      this.isLoading = false;
    }
  }

  /** Reads the cited material snapshots; a failed read leaves the section hidden. */
  private async loadCited(reviewId: string, service: ReviewService): Promise<ReviewMaterial[]> {
    try {
      return await service.materials(reviewId);
    } catch (error) {
      return [];
    }
  }

  /** Reads the decisions this review cited; a failed read leaves the section hidden. */
  private async loadCitedDecisions(reviewId: string, service: ReviewService): Promise<ReviewDecisionItem[]> {
    try {
      return await service.reviewDecisions(reviewId);
    } catch (error) {
      return [];
    }
  }

  /** Reads the six-zone payload; older records and failed reads leave it absent. */
  private async loadPayload(reviewId: string, hostContext: common.Context): Promise<ReviewPayload | null> {
    try {
      const store = await DbHelper.init(hostContext);
      const result = await new ReviewResultDao(store).queryById(reviewId);
      if (result === null || result.payload === undefined) {
        return null;
      }
      return result.payload;
    } catch (error) {
      return null;
    }
  }

  /** Reads the evidence rows of one review; a failed read leaves the section hidden. */
  private async loadEvidence(reviewId: string, hostContext: common.Context): Promise<EvidenceItem[]> {
    try {
      const store = await DbHelper.init(hostContext);
      return await new EvidenceItemDao(store).queryByTarget('review', reviewId);
    } catch (error) {
      return [];
    }
  }

  /** Reads the cost rows of one review; a failed read leaves the section hidden. */
  private async loadCosts(reviewId: string, service: ReviewService): Promise<CostNote[]> {
    try {
      return await service.costs(reviewId);
    } catch (error) {
      return [];
    }
  }

  private kindLabelOf(row: ReviewMaterial): string {
    return kindLabel(row.kindSnapshot);
  }

  private loadPreview(reviewId: string): void {
    const detail = previewStore.findReview(reviewId);
    if (detail === null) {
      this.missing = true;
    } else {
      this.detail = detail;
    }
    this.isLoading = false;
  }

  @Builder
  stepSection(title: string, body: string) {
    SectionCard() {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        Text(body.length > 0 ? body : '（未填写）')
          .fontSize(AppTheme.font.bodyStrong)
          .lineHeight(21)
          .fontColor(AppTheme.color.text)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  zoneSection(title: string, body: string) {
    SectionCard() {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        Text(body.trim().length > 0 ? body : '未填写')
          .fontSize(AppTheme.font.bodyStrong)
          .lineHeight(21)
          .fontColor(body.trim().length > 0 ? AppTheme.color.text : AppTheme.color.textMuted)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  miniTag(label: string) {
    Text(label)
      .fontSize(AppTheme.font.caption)
      .fontColor(AppTheme.color.textSecondary)
      .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
      .backgroundColor(AppTheme.color.chip)
      .borderRadius(AppTheme.radius.sm)
  }

  @Builder
  citedSection() {
    SectionCard() {
      Column({ space: 8 }) {
        Text(`引用的材料 · ${this.cited.length} 条`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        ForEach(this.cited, (row: ReviewMaterial) => {
          Column({ space: 4 }) {
            Row({ space: 4 }) {
              this.miniTag(this.kindLabelOf(row))
              if (sourceLabel(row.sourceSnapshot).length > 0) {
                this.miniTag(sourceLabel(row.sourceSnapshot))
              }
              if (levelLabel(row.levelSnapshot).length > 0) {
                this.miniTag(levelLabel(row.levelSnapshot))
              }
            }
            .width('100%')
            if (row.snapshotMissing) {
              Text('来源已删除')
                .fontSize(AppTheme.font.bodyStrong)
                .fontColor(AppTheme.color.textMuted)
                .width('100%')
            } else {
              Text(summaryOf(row.textSnapshot))
                .fontSize(AppTheme.font.bodyStrong)
                .lineHeight(19)
                .fontColor(AppTheme.color.text)
                .width('100%')
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
        }, (row: ReviewMaterial) => row.materialId)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  evidenceSection() {
    SectionCard() {
      Column({ space: 8 }) {
        Text(`证据 · ${this.evidence.length} 条`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        ForEach(this.evidence, (item: EvidenceItem) => {
          Column({ space: 4 }) {
            Row({ space: 4 }) {
              this.miniTag(evidenceSourceLabel(item.sourceType))
              this.miniTag(evidenceEffectLabel(item.effect))
            }
            .width('100%')
            Text(item.note.length > 0 ? item.note : '（未填写说明）')
              .fontSize(AppTheme.font.bodyStrong)
              .lineHeight(19)
              .fontColor(item.note.length > 0 ? AppTheme.color.text : AppTheme.color.textMuted)
              .width('100%')
          }
          .width('100%')
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
        }, (item: EvidenceItem) => item.id)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  costSection() {
    SectionCard() {
      Column({ space: 8 }) {
        Text(`成本 · ${this.costs.length} 条`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        ForEach(this.costs, (note: CostNote) => {
          Column({ space: 4 }) {
            Row({ space: 4 }) {
              this.miniTag(costDimensionLabel(note.dimension))
              this.miniTag(note.bearable ? '可承受' : '不可承受')
            }
            .width('100%')
            Text(note.text.length > 0 ? note.text : '（未填写说明）')
              .fontSize(AppTheme.font.bodyStrong)
              .lineHeight(19)
              .fontColor(note.text.length > 0 ? AppTheme.color.text : AppTheme.color.textMuted)
              .width('100%')
          }
          .width('100%')
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
        }, (note: CostNote) => note.id)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  decisionSection() {
    SectionCard() {
      Column({ space: 8 }) {
        Text(`涉及的决定 · ${this.citedDecisions.length} 条`)
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.textSecondary)
          .width('100%')
        ForEach(this.citedDecisions, (item: ReviewDecisionItem) => {
          Column({ space: 2 }) {
            Text(item.missing ? '来源已删除' : (item.title.length > 0 ? item.title : '（未填写标题）'))
              .fontSize(AppTheme.font.bodyStrong)
              .lineHeight(19)
              .fontColor(item.missing ? AppTheme.color.textMuted : AppTheme.color.text)
              .width('100%')
            if (!item.missing) {
              Text(item.choice.length > 0 ? item.choice : '（未记录选择）')
                .fontSize(AppTheme.font.caption)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.s10)
          .backgroundColor(AppTheme.color.surfaceAlt)
          .borderRadius(AppTheme.radius.sm)
          .id(`review_decision_row_${item.id}`)
        }, (item: ReviewDecisionItem) => `${item.id}_${item.missing ? 1 : 0}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  private openAttach(): void {
    if (this.navStack === null || this.detail.id.length === 0) {
      return;
    }
    const params: PlanAttachParams = {
      module: PlanLinkModule.REVIEW,
      targetId: this.detail.id,
      label: `${this.detail.periodLabel} ${this.detail.rangeLabel}`
    };
    this.navStack.pushPathByName(ROUTES.PLAN_ATTACH, params);
  }

  @Builder
  planMenu() {
    Text('计划')
      .fontSize(AppTheme.font.subtitle)
      .fontColor(AppTheme.color.primary)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s16 })
      .height(56)
      .onClick(() => {
        this.openAttach();
      })
  }

  build() {
    AppDestination({
      route: 'review_detail',
      title: '复盘详情',
      content: () => {
        this.reviewDetailBody();
      },
      menus: () => {
        this.planMenu();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          this.missing = true;
          return;
        }
        const params = context.pathInfo.param as ReviewDetailParams;
        this.load(params.reviewId);
      }
    })
  }

  @Builder
  reviewDetailBody() {
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
            title: '复盘记录不存在',
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
          Column({ space: 10 }) {
            SectionCard() {
              Column({ space: 5 }) {
                Row({ space: 6 }) {
                  Text(this.detail.periodLabel)
                    .fontSize(AppTheme.font.caption)
                    .fontColor(AppTheme.color.primaryDeep)
                    .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                    .backgroundColor(AppTheme.color.tint)
                    .borderRadius(AppTheme.radius.sm)
                  Text(this.detail.rangeLabel)
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .layoutWeight(1)
                }
                .width('100%')
                Text(this.detail.createdAtLabel)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
                Text('已完成记录不可修改')
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.warning)
                  .width('100%')
                if (this.detail.planNodeId !== undefined) {
                  Text('返回计划节点 ›')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.primary)
                    .width('100%')
                    .onClick(() => {
                      if (this.navStack !== null && this.detail.planNodeId !== undefined) {
                        const params: PlanNodeParams = { nodeId: this.detail.planNodeId };
                        this.navStack.pushPathByName(ROUTES.PLAN_NODE, params);
                      }
                    })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.payload !== null) {
              this.zoneSection('1. 现场与既有行动', this.payload.scene)
              if (this.cited.length > 0) {
                this.citedSection()
              }
              this.zoneSection('2. 当前模型', this.payload.model)
              this.zoneSection('3. 关系与主要矛盾', this.payload.relation)
              this.zoneSection('4. 多源校正', this.payload.evidence)
              if (this.evidence.length > 0) {
                this.evidenceSection()
              }
              this.zoneSection('5. 成本与动机', this.payload.cost)
              if (this.costs.length > 0) {
                this.costSection()
              }
              this.zoneSection('6. 调节与修订', this.payload.revision)
              if (this.citedDecisions.length > 0) {
                this.decisionSection()
              }
            } else {
              this.stepSection('1. 事实', this.detail.facts)
              if (this.cited.length > 0) {
                this.citedSection()
              }
              this.stepSection('2. 解释', this.detail.interpretation)
              this.stepSection('3. 矛盾', this.detail.contradiction)

              SectionCard() {
                Column({ space: 6 }) {
                  Text('4. 行动')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text(this.detail.action.length > 0 ? this.detail.action : '（未填写）')
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
              Column({ space: 6 }) {
                Text(`锚点对照 · ${this.detail.anchors.length} 条`)
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                if (this.detail.anchors.length === 0) {
                  Text('本次未选择锚点')
                    .fontSize(AppTheme.font.body)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                } else {
                  ForEach(this.detail.anchors, (anchor: Anchor) => {
                    Column({ space: 2 }) {
                      Text(anchor.text)
                        .fontSize(AppTheme.font.bodyStrong)
                        .lineHeight(19)
                        .fontColor(AppTheme.color.text)
                        .width('100%')
                      Text(anchor.source)
                        .fontSize(AppTheme.font.caption)
                        .fontColor(AppTheme.color.textMuted)
                        .width('100%')
                    }
                    .width('100%')
                  }, (anchor: Anchor) => anchor.id)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.page)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(Color.Transparent)
      }
  }
}

const CITED_SUMMARY_LIMIT: number = 50;

/** Collapses line breaks and cuts a snapshot down to one summary line. */
function summaryOf(text: string): string {
  const flat = text.split('\n').join(' ').trim();
  return flat.length > CITED_SUMMARY_LIMIT ? `${flat.substring(0, CITED_SUMMARY_LIMIT)}…` : flat;
}

function kindLabel(snapshot: string): string {
  if (snapshot === 'scene') {
    return '现场';
  }
  if (snapshot === 'feeling') {
    return '感受';
  }
  if (snapshot === 'body') {
    return '身体';
  }
  if (snapshot === 'existing_action') {
    return '已做';
  }
  if (snapshot === 'interpretation') {
    return '解释';
  }
  return '未分类';
}

function sourceLabel(raw: string): string {
  if (raw === 'direct') {
    return '直接经历';
  }
  if (raw === 'reading') {
    return '阅读';
  }
  if (raw === 'exercise') {
    return '练习';
  }
  if (raw === 'interaction') {
    return '互动';
  }
  if (raw === 'reflection') {
    return '反思';
  }
  if (raw === 'external') {
    return '外部资料';
  }
  return '';
}

function levelLabel(level: SecurityLevel | undefined): string {
  if (level === SecurityLevel.ANALYZABLE) {
    return '可分析';
  }
  if (level === SecurityLevel.LOCAL_ONLY) {
    return '仅本地';
  }
  if (level === SecurityLevel.SEALED) {
    return '已封存';
  }
  return '';
}

function evidenceSourceLabel(source: EvidenceSource): string {
  if (source === 'practice') {
    return '实践';
  }
  if (source === 'other_person') {
    return '他人';
  }
  if (source === 'body') {
    return '身体';
  }
  if (source === 'time') {
    return '时间';
  }
  if (source === 'book') {
    return '书本';
  }
  return '公开资料';
}

function evidenceEffectLabel(effect: EvidenceEffect): string {
  if (effect === 'supports') {
    return '支持';
  }
  if (effect === 'challenges') {
    return '挑战';
  }
  return '不清楚';
}

function costDimensionLabel(dimension: CostDimension): string {
  if (dimension === 'time') {
    return '时间';
  }
  if (dimension === 'attention') {
    return '注意力';
  }
  if (dimension === 'body') {
    return '身体';
  }
  if (dimension === 'relationship') {
    return '关系';
  }
  if (dimension === 'money') {
    return '金钱';
  }
  return '其他';
}
