import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import { RelationService, trustLevelText } from '../relation';
import { RelationEditParams } from '../navigation/RouteParams';
import { TrustLevel } from '../model/TrustLevel';
import { SecurityLevel } from '../model/SecurityLevel';
import { securityLevelText } from '../note';

/** Creates or edits one relation profile; interaction logs stay on the detail page. */
@ComponentV2
export struct RelationEditPage {
  @Local name: string = '';
  @Local trustLevel: TrustLevel = TrustLevel.FRIENDLY;
  @Local notes: string = '';
  @Local rawMaterialTest: boolean = false;
  @Local forbidAnalysis: boolean = false;
  @Local level: SecurityLevel = SecurityLevel.LOCAL_ONLY;
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local errorText: string = '';
  @Local isPreview: boolean = false;
  private relationId: string | null = null;
  private navStack: NavPathStack | null = null;

  private async load(relationId: string | null): Promise<void> {
    this.relationId = relationId;
    if (relationId === null) {
      this.isLoading = false;
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.isPreview = true;
      this.isLoading = false;
      this.errorText = '演示模式下不能编辑关系';
      return;
    }
    try {
      const service = await RelationService.open(hostContext);
      const detail = await service.find(relationId);
      if (detail !== null) {
        this.name = detail.name;
        this.trustLevel = detail.trustLevel;
        this.notes = detail.notes;
        this.rawMaterialTest = detail.rawMaterialTest;
        this.forbidAnalysis = detail.forbidAnalysis;
        this.level = detail.level;
      } else {
        this.errorText = '关系记录不存在';
      }
    } catch (error) {
      this.errorText = '关系加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private async save(): Promise<void> {
    if (this.isSaving || this.isPreview) {
      return;
    }
    if (this.name.trim().length === 0) {
      this.errorText = '请填写关系名称';
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.errorText = '运行环境未就绪';
      return;
    }
    this.isSaving = true;
    this.errorText = '';
    try {
      const service = await RelationService.open(hostContext);
      await service.save(this.relationId, this.name, this.trustLevel, this.rawMaterialTest,
        this.forbidAnalysis, this.level, this.notes);
      this.getUIContext().getPromptAction().showToast({ message: '关系已保存' });
      if (this.navStack !== null) {
        this.navStack.pop(true);
      }
    } catch (error) {
      this.errorText = '保存失败，请重试';
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  trustChip(level: TrustLevel) {
    Text(trustLevelText(level))
      .fontSize(12)
      .fontColor(this.trustLevel === level ? Color.White : AppTheme.color.text)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.trustLevel === level ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(14)
      .onClick(() => {
        this.trustLevel = level;
      })
  }

  @Builder
  levelChip(level: SecurityLevel) {
    Text(securityLevelText(level))
      .fontSize(12)
      .fontColor(this.level === level ? Color.White : AppTheme.color.text)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.level === level ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(14)
      .onClick(() => {
        this.level = level;
      })
  }

  @Builder
  flagChip(label: string, value: boolean, onToggle: () => void) {
    Text(value ? `${label} · 已开启` : `${label} · 未开启`)
      .fontSize(11)
      .fontColor(value ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(value ? AppTheme.color.tint : AppTheme.color.chip)
      .borderRadius(12)
      .onClick(onToggle)
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
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Text('关系名称用脱敏化名；互动记录在详情页维护。')
              .fontSize(11)
              .lineHeight(18)
              .fontColor(AppTheme.color.textSecondary)
              .width('100%')

            SectionCard() {
              Column({ space: 6 }) {
                Text('名称')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextInput({ text: this.name, placeholder: '例如：朋友 A' })
                  .maxLength(40)
                  .backgroundColor('#F7F6F2')
                  .onChange((value: string) => {
                    this.name = value;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 8 }) {
                Text('信任层级')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Row({ space: 8 }) {
                  this.trustChip(TrustLevel.FRIENDLY)
                  this.trustChip(TrustLevel.SINCERE)
                  this.trustChip(TrustLevel.TRANSPARENT)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 8 }) {
                Text('默认密级')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Row({ space: 8 }) {
                  this.levelChip(SecurityLevel.LOCAL_ONLY)
                  this.levelChip(SecurityLevel.ANALYZABLE)
                  this.levelChip(SecurityLevel.SEALED)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 8 }) {
                Text('分析边界')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                Row({ space: 8 }) {
                  this.flagChip('未加工材料测试', this.rawMaterialTest, () => {
                    this.rawMaterialTest = !this.rawMaterialTest;
                  })
                  this.flagChip('禁止动机分析', this.forbidAnalysis, () => {
                    this.forbidAnalysis = !this.forbidAnalysis;
                  })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            SectionCard() {
              Column({ space: 6 }) {
                Text('关系备注')
                  .fontSize(11)
                  .fontColor(AppTheme.color.textSecondary)
                  .width('100%')
                TextArea({ text: this.notes, placeholder: '只写与复盘边界有关的信息' })
                  .height(100)
                  .maxLength(200)
                  .backgroundColor('#F7F6F2')
                  .onChange((value: string) => {
                    this.notes = value;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(11)
                .fontColor(AppTheme.color.danger)
                .width('100%')
            }

            Text(this.isSaving ? '保存中…' : '保存关系')
              .fontSize(14)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 })
              .backgroundColor(this.isPreview ? AppTheme.color.textMuted : AppTheme.color.primary)
              .borderRadius(12)
              .onClick(() => {
                this.save();
              })
          }
          .width('100%')
          .padding(AppTheme.spacing.page)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(AppTheme.color.page)
      }
    }
    .title(this.relationId === null ? '新建关系' : '编辑关系')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
      const params = context.pathInfo.param as RelationEditParams;
      this.load(params.relationId);
    })
  }
}
