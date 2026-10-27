import { common } from '@kit.AbilityKit';
import { AppTheme } from '../theme/AppTheme';
import { SectionCard } from '../components/SectionCard';
import {
  AppSettings,
  MAX_MONTHLY_BUDGET,
  SettingsStore,
  defaultAppSettings,
  sanitizeAppSettings
} from '../settings';
import { ExportService, totalExportRecords } from '../export';
import { SecurityLevel } from '../model/SecurityLevel';
import { securityLevelText } from '../note';

interface ModelOption {
  id: string;
  label: string;
}

const MODEL_OPTIONS: ModelOption[] = [
  { id: 'glm-4.7-flash', label: 'GLM-4.7-Flash' },
  { id: 'deepseek-v4-flash', label: 'DeepSeek V4-Flash' }
];

/** Settings: review LLM, default security level, Markdown export and privacy notes. */
@ComponentV2
export struct SettingsPage {
  @Local settings: AppSettings = defaultAppSettings();
  @Local isLoading: boolean = true;
  @Local isSaving: boolean = false;
  @Local isDirty: boolean = false;
  @Local isExporting: boolean = false;
  @Local lastExportName: string = '';
  @Local lastExportChars: number = 0;
  @Local lastExportTotal: number = 0;
  private store: SettingsStore | null = null;
  private hostContext: common.Context | null = null;

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.isLoading = false;
      return;
    }
    this.hostContext = context;
    try {
      this.store = await SettingsStore.open(context);
      this.settings = await this.store.load();
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.getUIContext().getPromptAction().showToast({ message: '设置读取失败，已使用默认值' });
    }
  }

  private withLlm(enabled: boolean): void {
    this.settings = {
      llmEnabled: enabled,
      llmModel: this.settings.llmModel,
      llmMonthlyBudget: this.settings.llmMonthlyBudget,
      defaultLevel: this.settings.defaultLevel
    };
    this.isDirty = true;
  }

  private withModel(model: string): void {
    this.settings = {
      llmEnabled: this.settings.llmEnabled,
      llmModel: model,
      llmMonthlyBudget: this.settings.llmMonthlyBudget,
      defaultLevel: this.settings.defaultLevel
    };
    this.isDirty = true;
  }

  private withBudget(budget: number): void {
    this.settings = {
      llmEnabled: this.settings.llmEnabled,
      llmModel: this.settings.llmModel,
      llmMonthlyBudget: Math.round(budget),
      defaultLevel: this.settings.defaultLevel
    };
    this.isDirty = true;
  }

  private withLevel(level: SecurityLevel): void {
    this.settings = {
      llmEnabled: this.settings.llmEnabled,
      llmModel: this.settings.llmModel,
      llmMonthlyBudget: this.settings.llmMonthlyBudget,
      defaultLevel: level
    };
    this.isDirty = true;
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.store === null) {
      this.getUIContext().getPromptAction().showToast({ message: '设置存储未就绪' });
      return;
    }
    this.isSaving = true;
    try {
      this.settings = sanitizeAppSettings(this.settings);
      await this.store.save(this.settings);
      this.isDirty = false;
      this.getUIContext().getPromptAction().showToast({ message: '设置已保存' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private async exportMarkdown(): Promise<void> {
    if (this.isExporting) {
      return;
    }
    if (this.hostContext === null) {
      this.getUIContext().getPromptAction().showToast({ message: '运行环境未就绪' });
      return;
    }
    this.isExporting = true;
    try {
      const service = await ExportService.open(this.hostContext);
      const result = await service.exportMarkdown(this.hostContext);
      this.lastExportName = result.fileName;
      this.lastExportChars = result.charCount;
      this.lastExportTotal = totalExportRecords(result.counts);
      this.getUIContext().getPromptAction().showToast({ message: `已导出 ${result.fileName}` });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败，预览器可能不支持文件写入' });
    } finally {
      this.isExporting = false;
    }
  }

  @Builder
  modelChip(option: ModelOption) {
    Text(option.label)
      .fontSize(12)
      .fontColor(this.settings.llmModel === option.id ? Color.White : AppTheme.color.text)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.settings.llmModel === option.id ? AppTheme.color.primary : '#F1EFE8')
      .borderRadius(14)
      .onClick(() => {
        this.withModel(option.id);
      })
  }

  @Builder
  levelChip(level: SecurityLevel) {
    Text(securityLevelText(level))
      .fontSize(12)
      .fontColor(this.settings.defaultLevel === level ? Color.White : AppTheme.color.text)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.settings.defaultLevel === level ? AppTheme.color.primary : '#F1EFE8')
      .borderRadius(14)
      .onClick(() => {
        this.withLevel(level);
      })
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
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              SectionCard() {
                Column({ space: 10 }) {
                  Row() {
                    Column({ space: 2 }) {
                      Text('复盘 LLM')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.color.text)
                      Text('关闭时使用离线模板，开启后调用所选模型')
                        .fontSize(11)
                        .fontColor(AppTheme.color.textSecondary)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Toggle({ type: ToggleType.Switch, isOn: this.settings.llmEnabled })
                      .selectedColor(AppTheme.color.primary)
                      .onChange((isOn: boolean) => {
                        this.withLlm(isOn);
                      })
                  }
                  .width('100%')

                  if (this.settings.llmEnabled) {
                    Text('模型')
                      .fontSize(11)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(MODEL_OPTIONS, (option: ModelOption) => {
                        this.modelChip(option)
                      }, (option: ModelOption) => option.id)
                    }
                    .width('100%')

                    Row() {
                      Text('月预算')
                        .fontSize(11)
                        .fontColor(AppTheme.color.textSecondary)
                      Blank()
                      Text(`¥${this.settings.llmMonthlyBudget}`)
                        .fontSize(12)
                        .fontColor(AppTheme.color.primary)
                    }
                    .width('100%')

                    Slider({
                      value: this.settings.llmMonthlyBudget,
                      min: 0,
                      max: MAX_MONTHLY_BUDGET,
                      step: 10
                    })
                      .width('100%')
                      .selectedColor(AppTheme.color.primary)
                      .onChange((value: number) => {
                        this.withBudget(value);
                      })

                    Text('上限 500 元；0 表示不进行付费调用')
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 10 }) {
                  Text('新速记默认密级')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('仅影响新建记录；已有记录保持原密级')
                    .fontSize(11)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    this.levelChip(SecurityLevel.ANALYZABLE)
                    this.levelChip(SecurityLevel.LOCAL_ONLY)
                    this.levelChip(SecurityLevel.SEALED)
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 10 }) {
                  Text('导出')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('把全部可导出记录写成 Markdown，保存在应用沙箱内。')
                    .fontSize(11)
                    .lineHeight(17)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')

                  Text(this.isExporting ? '导出中…' : '导出 Markdown')
                    .fontSize(13)
                    .fontColor(AppTheme.color.primary)
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .backgroundColor(AppTheme.color.tint)
                    .borderRadius(10)
                    .onClick(() => {
                      this.exportMarkdown();
                    })

                  if (this.lastExportName.length > 0) {
                    Text(`已写入 ${this.lastExportName}`)
                      .fontSize(11)
                      .fontColor(AppTheme.color.text)
                      .width('100%')
                    Text(`${this.lastExportChars} 字符 · 共 ${this.lastExportTotal} 条记录`)
                      .fontSize(10)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('数据与隐私')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('业务数据只保存在本机；LLM 默认关闭，开启后仅发送复盘所需文本。')
                    .fontSize(11)
                    .lineHeight(18)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text('密级为「已封存」的记录不会进入导出与模型上下文。')
                    .fontSize(11)
                    .lineHeight(18)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }
            .width('100%')
            .padding(AppTheme.spacing.page)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Column() {
            Text(this.isSaving ? '保存中…' : '保存设置')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 })
              .backgroundColor(this.isDirty && !this.isSaving ? AppTheme.color.primary : '#8FA6C4')
              .borderRadius(12)
              .onClick(() => {
                if (!this.isSaving && this.isDirty) {
                  this.save();
                }
              })
          }
          .width('100%')
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: 8, bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(AppTheme.color.page)
      }
    }
    .title('设置')
  }
}
