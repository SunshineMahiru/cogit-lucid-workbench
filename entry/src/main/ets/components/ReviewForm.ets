import { Anchor } from '../model/Anchor';
import { ExperienceMaterial } from '../model/ExperienceMaterial';
import { ReviewPeriod } from '../model/ReviewPeriod';
import { AppTheme } from '../theme/AppTheme';
import { formatHitRate } from '../model/HomeModel';
import { MaterialPicker } from './MaterialPicker';
import { ReviewPromptPanel } from './ReviewPromptPanel';
import { ReviewAgentPanel } from './ReviewAgentPanel';
import { hasAnyZone, ReviewPayload } from '../model/ReviewPayload';
import {
  ReviewDraft,
  ReviewService,
  ReviewStats,
  emptyReviewStats
} from '../review';
import { PREVIEW_ANCHORS, PREVIEW_REVIEW_STATS } from '../preview/PreviewData';
import { previewStore } from '../preview/PreviewStore';
import { ReviewDraftStore } from '../review/ReviewDraftStore';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';

const ZONE_LABELS: string[] = [
  '现场与既有行动',
  '当前模型',
  '关系与主要矛盾',
  '多源校正',
  '成本与动机',
  '调节与修订'
];
const ZONE_HINTS: string[] = [
  '先写现场：发生了什么，我已经做了什么。',
  '我现在的解释、预测、适用范围，以及什么能证明它错。',
  '这件事牵涉哪些人，主要矛盾在哪一条关系上。',
  '实践、他人、身体、时间、书里的说法，哪里和我的模型不一致。',
  '维持现状的代价是什么，我为什么要改。',
  '下一次遇到类似情况，准备怎么做。'
];
const ZONE_PLACEHOLDERS: string[] = [
  '例如：连续四天睡不到 7 小时，周三临时改期两次。',
  '例如：我把它归因于「最近状态差」，但没有具体证据。',
  '例如：我答应同事的事一拖再拖，和我在意的可靠冲突。',
  '例如：记录显示熬夜后的第二天效率更低。',
  '例如：拖延让我每天多耗两小时，代价是不被信任。',
  '例如：晚上十点后不再安排需要集中注意力的事。'
];
const LAST_ZONE: number = 5;

/** Six-zone review form for one period; each tab owns its own draft. */
@ComponentV2
export struct ReviewForm {
  @Param period: ReviewPeriod = ReviewPeriod.WEEK;
  @Param planId: string = '';
  @Param planNodeId: string = '';
  @Event onBackToPlan: () => void = () => {};
  @Local stats: ReviewStats = emptyReviewStats();
  @Local anchors: Anchor[] = [];
  @Local materials: ExperienceMaterial[] = [];
  @Local selectedMaterialIds: string[] = [];
  @Local step: number = 0;
  @Local facts: string = '';
  @Local interpretation: string = '';
  @Local contradiction: string = '';
  @Local action: string = '';
  @Local zoneScene: string = '';
  @Local zoneModel: string = '';
  @Local zoneRelation: string = '';
  @Local zoneEvidence: string = '';
  @Local zoneCost: string = '';
  @Local zoneRevision: string = '';
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local saved: boolean = false;
  @Local selectedAnchorIds: string[] = [];
  @Local isPreview: boolean = false;
  private service: ReviewService | null = null;
  private draftStore: ReviewDraftStore | null = null;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.persistDraft();
  }

  private async load(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.loadPreview();
      return;
    }
    try {
      this.service = await ReviewService.open(hostContext);
      this.draftStore = await ReviewDraftStore.open(hostContext);
      this.stats = await this.service.loadStats(this.period);
      this.anchors = await this.service.loadAnchors(3);
      this.selectedAnchorIds = this.anchors.map((anchor: Anchor) => anchor.id);
      this.materials = await this.service.recentMaterials(50);
      const draft = await this.draftStore.loadFor(this.period, this.planNodeId);
      if (draft !== null) {
        this.facts = draft.facts;
        this.interpretation = draft.interpretation;
        this.contradiction = draft.contradiction;
        this.action = draft.action;
        if (draft.payload !== undefined) {
          this.zoneScene = draft.payload.scene;
          this.zoneModel = draft.payload.model;
          this.zoneRelation = draft.payload.relation;
          this.zoneEvidence = draft.payload.evidence;
          this.zoneCost = draft.payload.cost;
          this.zoneRevision = draft.payload.revision;
        }
        if (draft.anchorIds.length > 0) {
          this.selectedAnchorIds = draft.anchorIds.slice();
        }
        if (draft.materialIds !== undefined && draft.materialIds.length > 0) {
          this.selectedMaterialIds = draft.materialIds.slice();
        }
      }
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '复盘数据加载失败' });
    }
  }

  private currentPayload(): ReviewPayload {
    return {
      scene: this.zoneScene,
      model: this.zoneModel,
      relation: this.zoneRelation,
      evidence: this.zoneEvidence,
      cost: this.zoneCost,
      revision: this.zoneRevision
    };
  }

  private buildDraft(): ReviewDraft {
    return {
      facts: this.facts,
      interpretation: this.interpretation,
      contradiction: this.contradiction,
      action: this.action,
      payload: this.currentPayload(),
      materialIds: this.selectedMaterialIds.slice(),
      anchorIds: this.selectedAnchorIds.slice(),
      planId: this.planId,
      planNodeId: this.planNodeId
    };
  }

  private persistDraft(): void {
    if (this.draftStore === null) {
      return;
    }
    const draft: ReviewDraft = this.buildDraft();
    this.draftStore.saveFor(this.period, this.planNodeId, draft).catch(() => {
    });
  }

  private loadPreview(): void {
    this.isPreview = true;
    this.stats = PREVIEW_REVIEW_STATS;
    this.anchors = PREVIEW_ANCHORS.slice(0, 3);
    this.selectedAnchorIds = this.anchors.map((anchor: Anchor) => anchor.id);
    this.isLoading = false;
  }

  private currentText(): string {
    if (this.step === 0) {
      return this.zoneScene;
    }
    if (this.step === 1) {
      return this.zoneModel;
    }
    if (this.step === 2) {
      return this.zoneRelation;
    }
    if (this.step === 3) {
      return this.zoneEvidence;
    }
    if (this.step === 4) {
      return this.zoneCost;
    }
    return this.zoneRevision;
  }

  private updateCurrent(value: string): void {
    if (this.step === 0) {
      this.zoneScene = value;
    } else if (this.step === 1) {
      this.zoneModel = value;
    } else if (this.step === 2) {
      this.zoneRelation = value;
    } else if (this.step === 3) {
      this.zoneEvidence = value;
    } else if (this.step === 4) {
      this.zoneCost = value;
    } else {
      this.zoneRevision = value;
    }
    this.persistDraft();
  }

  private appendRelation(text: string): void {
    const current = this.zoneRelation.trim();
    this.zoneRelation = current.length > 0 ? `${current}\n${text}` : text;
    this.persistDraft();
  }

  private savedSummary(): string {
    if (this.zoneRevision.trim().length > 0) {
      return this.zoneRevision;
    }
    if (this.zoneScene.trim().length > 0) {
      return this.zoneScene;
    }
    return this.action;
  }

  private isAnchorSelected(id: string): boolean {
    return this.selectedAnchorIds.includes(id);
  }

  private toggleAnchor(id: string): void {
    if (this.isAnchorSelected(id)) {
      this.selectedAnchorIds = this.selectedAnchorIds.filter((item: string) => item !== id);
    } else {
      this.selectedAnchorIds = this.selectedAnchorIds.concat([id]);
    }
    this.persistDraft();
  }

  private toggleMaterial(id: string): void {
    if (this.selectedMaterialIds.includes(id)) {
      this.selectedMaterialIds = this.selectedMaterialIds.filter((item: string) => item !== id);
    } else {
      this.selectedMaterialIds = this.selectedMaterialIds.concat([id]);
    }
    this.persistDraft();
  }

  private async complete(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (!hasAnyZone(this.currentPayload())) {
      this.step = 0;
      this.getUIContext().getPromptAction().showToast({ message: '先写一句现场，或填任意一区' });
      return;
    }
    if (this.isPreview) {
      previewStore.saveReview(this.period, this.buildDraft(), this.stats.rangeLabel);
      notifyHomeRefresh();
      this.saved = true;
      this.getUIContext().getPromptAction().showToast({ message: '演示模式：复盘已保存在当前会话' });
      return;
    }
    if (this.service === null) {
      this.getUIContext().getPromptAction().showToast({ message: '数据库尚未就绪' });
      return;
    }
    this.isSaving = true;
    try {
      await this.service.save(this.period, this.buildDraft(), this.stats.rangeLabel, this.planId, this.planNodeId);
      if (this.draftStore !== null) {
        await this.draftStore.clearFor(this.period, this.planNodeId);
      }
      notifyHomeRefresh();
      this.saved = true;
      this.getUIContext().getPromptAction().showToast({ message: '复盘已保存' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private restart(): void {
    this.step = 0;
    this.facts = '';
    this.interpretation = '';
    this.contradiction = '';
    this.action = '';
    this.zoneScene = '';
    this.zoneModel = '';
    this.zoneRelation = '';
    this.zoneEvidence = '';
    this.zoneCost = '';
    this.zoneRevision = '';
    this.saved = false;
    if (this.draftStore !== null) {
      this.draftStore.clearFor(this.period, this.planNodeId).catch(() => {
      });
    }
    this.load();
  }

  @Builder
  statItem(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(AppTheme.font.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.color.text)
      Text(label)
        .fontSize(AppTheme.font.caption)
        .fontColor(AppTheme.color.textSecondary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  zoneTabs() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(ZONE_LABELS, (label: string, index: number) => {
        Row({ space: 4 }) {
          Text(String(index + 1))
            .fontSize(AppTheme.font.caption)
            .fontColor(index === this.step ? Color.White : AppTheme.color.textSecondary)
            .width(18)
            .height(18)
            .textAlign(TextAlign.Center)
            .lineHeight(18)
            .backgroundColor(index === this.step ? AppTheme.color.primary : AppTheme.color.tint)
            .borderRadius(AppTheme.radius.sm)
          Text(label)
            .fontSize(AppTheme.font.caption)
            .fontColor(index === this.step ? AppTheme.color.text : AppTheme.color.textSecondary)
        }
        .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
        .margin({ right: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
        .backgroundColor(index === this.step ? AppTheme.color.selectedSurface : AppTheme.color.surfaceAlt)
        .borderRadius(AppTheme.radius.sm)
        .border({
          width: index === this.step ? 1 : 0,
          color: AppTheme.color.borderSelected
        })
        .onClick(() => {
          this.step = index;
        })
      }, (label: string) => label)
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.planNodeId.length > 0) {
        Row({ space: 8 }) {
          Text('来自计划节点')
            .fontSize(AppTheme.font.caption)
            .fontColor(AppTheme.color.textMuted)
          Blank()
          Text('返回节点 ›')
            .fontSize(AppTheme.font.body)
            .fontColor(AppTheme.color.primary)
            .onClick(() => {
              this.onBackToPlan();
            })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s2 })
      }
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
      } else if (this.saved) {
        Column({ space: 12 }) {
          Text('本期复盘已完成')
            .fontSize(AppTheme.font.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.color.text)
          Text(this.stats.rangeLabel)
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.textSecondary)
          Text(this.savedSummary())
            .fontSize(AppTheme.font.subtitle)
            .lineHeight(22)
            .fontColor(AppTheme.color.text)
            .textAlign(TextAlign.Center)
          Text('再写一条')
            .fontSize(AppTheme.font.bodyStrong)
            .fontColor(AppTheme.color.primary)
            .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
            .backgroundColor(AppTheme.color.tint)
            .borderRadius(AppTheme.radius.lg)
            .margin({ top: AppTheme.spacing.s8 })
            .onClick(() => {
              this.restart();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(AppTheme.spacing.s24)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 8 }) {
              Row() {
                Text(this.period === ReviewPeriod.WEEK ? '本周' : '本月')
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.color.text)
                Blank()
                Text(this.stats.rangeLabel)
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
              }
              .width('100%')

              Row() {
                this.statItem(String(this.stats.noteCount), '速记')
                this.statItem(String(this.stats.decisionCount), '决策')
                this.statItem(String(this.stats.settledPredictions), '已结算')
                this.statItem(formatHitRate(this.stats.hitRate, this.stats.settledPredictions), '命中率')
              }
              .width('100%')
            }
            .width('100%')
            .padding(AppTheme.spacing.s16)
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(AppTheme.radius.md)

            this.zoneTabs()

            if (this.step === 0) {
              ReviewPromptPanel({ period: this.period })
            }

            Text(`${this.step + 1}. ${ZONE_LABELS[this.step]}`)
              .fontSize(AppTheme.font.title)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.color.text)
              .width('100%')
            Text(ZONE_HINTS[this.step])
              .fontSize(AppTheme.font.bodyStrong)
              .lineHeight(18)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')

            if (this.step === 2 && this.anchors.length > 0) {
              Column({ space: 8 }) {
                Text('对照锚点 · 点击选择本次真正用到的')
                  .fontSize(AppTheme.font.body)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                ForEach(this.anchors, (anchor: Anchor) => {
                  Column({ space: 4 }) {
                    Row() {
                      Text(anchor.text)
                        .fontSize(AppTheme.font.bodyStrong)
                        .lineHeight(20)
                        .fontColor(AppTheme.color.text)
                        .layoutWeight(1)
                      if (this.isAnchorSelected(anchor.id)) {
                        Text('已对照')
                          .fontSize(AppTheme.font.caption)
                          .fontColor(AppTheme.color.primary)
                          .padding({ left: AppTheme.spacing.s6, right: AppTheme.spacing.s6, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                          .backgroundColor(AppTheme.color.tint)
                          .borderRadius(AppTheme.radius.sm)
                      }
                    }
                    .width('100%')
                    Text(anchor.source)
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                  .width('100%')
                  .padding(AppTheme.spacing.s10)
                  .backgroundColor(this.isAnchorSelected(anchor.id) ? AppTheme.color.selectedSurface : AppTheme.color.surfaceWarm)
                  .borderRadius(AppTheme.radius.sm)
                  .border({
                    width: this.isAnchorSelected(anchor.id) ? 1 : 0,
                    color: AppTheme.color.borderSelected
                  })
                  .onClick(() => {
                    this.toggleAnchor(anchor.id);
                  })
                }, (anchor: Anchor) => `${anchor.id}_${this.isAnchorSelected(anchor.id) ? 1 : 0}`)
              }
              .width('100%')
              .padding(AppTheme.spacing.s16)
              .backgroundColor(AppTheme.color.surfaceWarm)
              .borderRadius(AppTheme.radius.md)
              .alignItems(HorizontalAlign.Start)
            }

            if (this.step === 2) {
              ReviewAgentPanel({
                facts: this.zoneScene,
                interpretation: this.zoneModel,
                anchors: this.anchors,
                onInsert: (text: string) => {
                  this.appendRelation(text);
                }
              })
            }

            TextArea({ text: this.currentText(), placeholder: ZONE_PLACEHOLDERS[this.step] })
              .fontSize(AppTheme.font.bodyStrong)
              .height(180)
              .padding(AppTheme.spacing.s12)
              .backgroundColor(AppTheme.color.surface)
              .borderRadius(AppTheme.radius.md)
              .border({ width: 0.5, color: AppTheme.color.border })
              .onChange((value: string) => {
                this.updateCurrent(value);
              })

            if (this.step === 0) {
              MaterialPicker({
                materials: this.materials,
                selectedIds: this.selectedMaterialIds,
                onToggle: (id: string) => {
                  this.toggleMaterial(id);
                }
              })
            }
          }
          .width('100%')
          .padding(AppTheme.spacing.s16)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        Row({ space: 12 }) {
          if (this.step > 0) {
            Text('上一步')
              .fontSize(AppTheme.font.subtitle)
              .fontColor(AppTheme.color.textSecondaryStrong)
              .padding({ left: AppTheme.spacing.s20, right: AppTheme.spacing.s20, top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(AppTheme.color.chip)
              .borderRadius(AppTheme.radius.md)
              .onClick(() => {
                this.step -= 1;
              })
          }
          Blank()
          Text(this.step < LAST_ZONE ? '下一步' : '完成复盘')
            .fontSize(AppTheme.font.subtitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: AppTheme.spacing.s24, right: AppTheme.spacing.s24, top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
            .backgroundColor(this.isSaving ? AppTheme.color.primaryDisabled : AppTheme.color.primary)
            .borderRadius(AppTheme.radius.md)
            .accessibilityText(this.step < LAST_ZONE ? '进入下一步' : '完成复盘')
            .onClick(() => {
              if (this.isSaving) {
                return;
              }
              if (this.step < LAST_ZONE) {
                this.step += 1;
              } else {
                this.complete();
              }
            })
        }
        .width('100%')
        .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
