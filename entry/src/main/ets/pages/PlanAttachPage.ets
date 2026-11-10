import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { NoteEmptyState } from '../components/NoteEmptyState';
import { PlanLinkModule } from '../model/PlanLinkModule';
import { PlanLink } from '../model/PlanLink';
import { PlanStatus } from '../model/PlanStatus';
import { PlanService } from '../plan';
import { createPlanLink } from '../plan/PlanFactory';
import { planLinkModuleLabel } from '../plan/PlanLinkCatalog';
import { PlanAttachParams } from '../navigation/RouteParams';
import { planPreviewStore } from '../preview/PlanPreviewStore';

interface AttachTarget {
  planId: string;
  nodeId: string;
  title: string;
  weekIndex: number;
  startDate: string;
  selected: boolean;
}

/** Reverse entry: attach one existing record to any plan node. */
@ComponentV2
export struct PlanAttachPage {
  @Local targets: AttachTarget[] = [];
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local errorText: string = '';
  private module: PlanLinkModule = PlanLinkModule.NOTE;
  private targetId: string = '';
  private label: string = '';
  private service: PlanService | null = null;
  private navStack: NavPathStack | null = null;

  private async load(module: PlanLinkModule, targetId: string, label: string): Promise<void> {
    this.module = module;
    this.targetId = targetId;
    this.label = label;
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.targets = this.previewTargets();
      this.isLoading = false;
      return;
    }
    try {
      const service = await PlanService.open(hostContext);
      this.service = service;
      const links = await service.listLinksByTarget(module, targetId);
      const linkedNodeIds: string[] = [];
      for (const link of links) {
        if (link.nodeId !== undefined) {
          linkedNodeIds.push(link.nodeId);
        }
      }
      const rows: AttachTarget[] = [];
      for (const plan of await service.listPlans()) {
        if (plan.status === PlanStatus.ARCHIVED) {
          continue;
        }
        const nodes = await service.listNodes(plan.id);
        for (const node of nodes) {
          rows.push({
            planId: plan.id,
            nodeId: node.id,
            title: plan.title,
            weekIndex: node.weekIndex,
            startDate: node.startDate,
            selected: linkedNodeIds.includes(node.id)
          });
        }
      }
      this.targets = rows;
    } catch (error) {
      this.errorText = '计划节点加载失败';
      this.targets = [];
    } finally {
      this.isLoading = false;
    }
  }

  private previewTargets(): AttachTarget[] {
    const rows: AttachTarget[] = [];
    for (const plan of planPreviewStore.list()) {
      if (plan.status === PlanStatus.ARCHIVED) {
        continue;
      }
      for (const node of planPreviewStore.nodes(plan.id)) {
        rows.push({
          planId: plan.id,
          nodeId: node.id,
          title: plan.title,
          weekIndex: node.weekIndex,
          startDate: node.startDate,
          selected: false
        });
      }
    }
    return rows;
  }

  private toggle(index: number): void {
    const next: AttachTarget[] = [];
    for (let i = 0; i < this.targets.length; i += 1) {
      const row = this.targets[i];
      next.push({
        planId: row.planId,
        nodeId: row.nodeId,
        title: row.title,
        weekIndex: row.weekIndex,
        startDate: row.startDate,
        selected: i === index ? !row.selected : row.selected
      });
    }
    this.targets = next;
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    try {
      const links: PlanLink[] = [];
      for (const row of this.targets) {
        if (row.selected) {
          links.push(createPlanLink(row.planId, row.nodeId, this.module, this.targetId, this.label));
        }
      }
      if (this.service === null) {
        planPreviewStore.replaceLinksForTarget(this.module, this.targetId, links);
        this.getUIContext().getPromptAction().showToast({ message: '预览器仅展示关联列表' });
        this.isSaving = false;
        return;
      }
      await this.service.replaceLinksByTarget(this.module, this.targetId, links);
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '关联保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  saveMenu() {
    Text(this.isSaving ? '保存中' : '保存')
      .id('plan_attach_save')
      .fontSize(AppTheme.font.subtitle)
      .fontColor(AppTheme.color.primary)
      .padding({ left: 12, right: 16 })
      .height(56)
      .onClick(() => {
        this.save();
      })
  }

  @Builder
  body() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(32).height(32).color(AppTheme.color.primary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.errorText.length > 0) {
      Column({ space: 8 }) {
        Text(this.errorText).fontSize(AppTheme.font.bodyStrong).fontColor(AppTheme.color.danger)
        Text('重试')
          .fontSize(AppTheme.font.body)
          .fontColor(AppTheme.color.primary)
          .onClick(() => {
            this.errorText = '';
            this.isLoading = true;
            this.load(this.module, this.targetId, this.label);
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.targets.length === 0) {
      Column() {
        NoteEmptyState({
          title: '还没有计划节点',
          hint: '先在首页创建目标与第一周，再回来关联',
          dashed: true
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column({ space: 8 }) {
          SectionCard() {
            Column({ space: 4 }) {
              Text(`把${planLinkModuleLabel(this.module)}关联到计划`)
                .fontSize(AppTheme.font.bodyStrong)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.color.text)
                .width('100%')
              Text(`当前记录：${this.label}`)
                .fontSize(AppTheme.font.body)
                .fontColor(AppTheme.color.textSecondary)
                .width('100%')
                .maxLines(2)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          ForEach(this.targets, (row: AttachTarget, index: number) => {
            Row({ space: 8 }) {
              Text(row.selected ? '✓' : '○')
                .fontSize(AppTheme.font.title)
                .fontColor(row.selected ? AppTheme.color.primary : AppTheme.color.textMuted)
                .width(24)
                .textAlign(TextAlign.Center)
              Column({ space: 2 }) {
                Text(row.title)
                  .fontSize(AppTheme.font.bodyStrong)
                  .fontColor(AppTheme.color.text)
                  .width('100%')
                Text(`第 ${row.weekIndex} 周 · ${row.startDate}`)
                  .fontSize(AppTheme.font.caption)
                  .fontColor(AppTheme.color.textMuted)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(AppTheme.color.surface)
            .borderRadius(10)
            .onClick(() => {
              this.toggle(index);
            })
          }, (row: AttachTarget) => `${row.nodeId}_${row.selected ? 1 : 0}`)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
    }
  }

  build() {
    AppDestination({
      route: 'plan_attach',
      title: '关联计划',
      content: () => {
        this.body()
      },
      menus: () => {
        this.saveMenu()
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
        if (context.pathInfo.param === undefined) {
          this.isLoading = false;
          return;
        }
        const params = context.pathInfo.param as PlanAttachParams;
        this.load(params.module, params.targetId, params.label);
      }
    })
  }
}
