import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanLink } from '../model/PlanLink';
import { PlanService } from '../plan';
import { LinkCandidate } from '../plan/PlanLinkCandidate';
import { loadPlanLinkCandidates, planLinkModuleLabel } from '../plan/PlanLinkCatalog';
import { PlanLinkPickerParams } from '../navigation/RouteParams';
import { planPreviewStore } from '../preview/PlanPreviewStore';

const MODULES: PlanLinkModule[] = [
  PlanLinkModule.NOTE,
  PlanLinkModule.PREDICTION,
  PlanLinkModule.REVIEW,
  PlanLinkModule.ANCHOR,
  PlanLinkModule.RELATION,
  PlanLinkModule.STATUS
];

/** Selects records from the six modules for one plan node. */
@ComponentV2
export struct PlanLinkPickerPage {
  @Local module: PlanLinkModule = PlanLinkModule.NOTE;
  @Local candidates: LinkCandidate[] = [];
  @Local selectedKeys: string[] = [];
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local isPreview: boolean = false;
  private planId: string = '';
  private nodeId: string = '';
  private weekStart: string = '';
  private weekEnd: string = '';
  private service: PlanService | null = null;
  private navStack: NavPathStack | null = null;

  private keyOf(item: LinkCandidate): string {
    return `${item.module}:${item.targetId}`;
  }

  private async load(planId: string, nodeId: string, weekStart: string, weekEnd: string): Promise<void> {
    this.planId = planId;
    this.nodeId = nodeId;
    this.weekStart = weekStart;
    this.weekEnd = weekEnd;
    const hostContext = this.getUIContext().getHostContext();
    let links: PlanLink[] = [];
    if (hostContext === undefined) {
      this.isPreview = true;
      links = planPreviewStore.links(nodeId);
    } else {
      try {
        this.service = await PlanService.open(hostContext);
        links = await this.service.listLinks(nodeId);
      } catch (error) {
        this.isPreview = true;
        links = planPreviewStore.links(nodeId);
      }
    }
    const keys: string[] = [];
    for (const link of links) {
      keys.push(`${link.module}:${link.targetId}`);
    }
    this.selectedKeys = keys;
    try {
      this.candidates = await loadPlanLinkCandidates(hostContext, weekStart, weekEnd);
    } catch (error) {
      this.candidates = [];
    }
    this.isLoading = false;
  }

  private visibleCandidates(): LinkCandidate[] {
    const rows: LinkCandidate[] = [];
    for (const item of this.candidates) {
      if (item.module === this.module) {
        rows.push(item);
      }
    }
    return rows;
  }

  private isSelected(item: LinkCandidate): boolean {
    return this.selectedKeys.includes(this.keyOf(item));
  }

  private toggle(item: LinkCandidate): void {
    const key = this.keyOf(item);
    const next: string[] = [];
    let removed = false;
    for (const existing of this.selectedKeys) {
      if (existing === key) {
        removed = true;
      } else {
        next.push(existing);
      }
    }
    if (!removed) {
      next.push(key);
    }
    this.selectedKeys = next;
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    try {
      if (this.isPreview || this.service === null) {
        planPreviewStore.clearLinks(this.nodeId);
        for (const key of this.selectedKeys) {
          const item = this.findByKey(key);
          if (item !== null) {
            planPreviewStore.addLink(this.planId, this.nodeId, item.module, item.targetId, item.title);
          }
        }
      } else {
        const existing = await this.service.listLinks(this.nodeId);
        for (const link of existing) {
          await this.service.removeLink(link.id);
        }
        for (const key of this.selectedKeys) {
          const item = this.findByKey(key);
          if (item !== null) {
            await this.service.addLink(this.planId, this.nodeId, item.module, item.targetId, item.title);
          }
        }
      }
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '关联保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private findByKey(key: string): LinkCandidate | null {
    for (const item of this.candidates) {
      if (this.keyOf(item) === key) {
        return item;
      }
    }
    return null;
  }

  @Builder
  saveMenu() {
    Text(this.isSaving ? '保存中' : '保存')
      .id('plan_link_save')
      .fontSize(14)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 12, right: 16 })
      .height(56)
      .onClick(() => {
        this.save();
      })
  }

  @Builder
  moduleChip(module: PlanLinkModule) {
    Text(planLinkModuleLabel(module))
      .fontSize(11)
      .fontColor(this.module === module ? Color.White : AppTheme.color.textSecondary)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.module === module ? AppTheme.color.primary : AppTheme.color.surfaceAlt)
      .borderRadius(14)
      .onClick(() => {
        this.module = module;
      })
  }

  @Builder
  candidateRow(item: LinkCandidate) {
    Row({ space: 8 }) {
      Text(this.isSelected(item) ? '✓' : '○')
        .fontSize(16)
        .fontColor(this.isSelected(item) ? AppTheme.color.primary : AppTheme.color.textMuted)
        .width(24)
        .textAlign(TextAlign.Center)
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(item.title.length > 0 ? item.title : '未命名记录')
            .fontSize(12)
            .fontColor(AppTheme.color.text)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (item.suggested) {
            Text('本周')
              .fontSize(9)
              .fontColor(AppTheme.color.primaryDeep)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .backgroundColor(AppTheme.color.tint)
              .borderRadius(4)
          }
        }
        .width('100%')
        Text(item.subtitle.length > 0 ? item.subtitle : '暂无说明')
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .onClick(() => {
      this.toggle(item);
    })
  }

  @Builder
  pickerBody() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(32).height(32).color(AppTheme.color.primary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Column({ space: 10 }) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(MODULES, (module: PlanLinkModule) => {
              this.moduleChip(module)
            }, (module: PlanLinkModule) => module)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        if (this.visibleCandidates().length === 0) {
          Column() {
            NoteEmptyState({
              title: `${planLinkModuleLabel(this.module)}暂无记录`,
              hint: '先到对应模块记一条，再回来关联',
              dashed: true
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.visibleCandidates(), (item: LinkCandidate) => {
                this.candidateRow(item)
              }, (item: LinkCandidate) => this.keyOf(item))
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
        }

        Text(`已选 ${this.selectedKeys.length} 条`)
          .fontSize(10)
          .fontColor(AppTheme.color.textMuted)
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 16 })
    }
  }

  build() {
    AppDestination({
      route: 'plan_link_picker',
      title: '关联记录',
      content: () => {
        this.pickerBody()
      },
      menus: () => {
        this.saveMenu()
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        const params = context.pathInfo.param as PlanLinkPickerParams;
        this.load(params.planId, params.nodeId, params.weekStart, params.weekEnd);
      }
    })
  }
}
