import { common } from '@kit.AbilityKit';
import { AppTheme } from '../theme/AppTheme';
import { AppDestination } from '../components/AppDestination';
import { SectionCard } from '../components/SectionCard';
import { notifyHomeRefresh } from '../app/HomeRefreshBus';
import { notifyProfileRefresh } from '../app/ProfileRefreshBus';
import { profileCache } from '../profile/ProfileCache';
import {
  AppSettings,
  LlmProvider,
  LlmSpendStore,
  MAX_MONTHLY_BUDGET,
  SettingsStore,
  defaultAppSettings,
  sanitizeAppSettings
} from '../settings';
import {
  PAGE_BACKGROUND_GROUPS,
  PageBackgroundService
} from '../settings/PageBackgroundService';
import { BackupService, RestoreOutcome, RestoreReport } from '../settings/BackupService';
import { BackupOptionsStore } from '../settings/BackupOptionsStore';
import { BackupInventory } from '../settings/BackupInventory';
import { ROUTES } from '../navigation/Routes';
import { ExportService, totalExportRecords, ExportOptions, carriesLocalContent, describeExportOptions } from '../export';
import { SecurityLevel } from '../model/SecurityLevel';
import { DbHelper, getSchemaIssues } from '../db/DbHelper';
import { DebugFaults } from '../app/DebugFaults';
import BuildProfile from 'BuildProfile';
import { DebugPanel } from '../components/settings/DebugPanel';
import { DataManagementCard } from '../components/settings/DataManagementCard';
import { securityLevelText } from '../note';

interface ModelOption {
  id: string;
  label: string;
}

interface BackgroundRowState {
  key: string;
  label: string;
  path: string;
}

function initialBackgroundRows(): BackgroundRowState[] {
  const rows: BackgroundRowState[] = [];
  for (const group of PAGE_BACKGROUND_GROUPS) {
    const row: BackgroundRowState = { key: group.key, label: group.label, path: '' };
    rows.push(row);
  }
  return rows;
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
  @Local exportLocalOnly: boolean = false;
  @Local exportStatements: boolean = false;
  @Local exportDemo: boolean = false;
  @Local exportHistory: boolean = false;
  @Local schemaIssueCount: number = 0;
  @Local backupIncludeBackgrounds: boolean = false;
  @Local safetyCount: number = 0;
  @Local safetyLatest: string = '';
  @Local lastExportName: string = '';
  @Local lastExportPath: string = '';
  @Local lastExportChars: number = 0;
  @Local lastExportTotal: number = 0;
  @Local spentYuan: number = 0;
  @Local backgroundBusy: string = '';
  @Local globalApplied: boolean = false;
  @Local dataBusy: boolean = false;
  @Local clearArmed: boolean = false;
  @Local encryptionFallback: boolean = false;
  @Local backgroundRows: BackgroundRowState[] = initialBackgroundRows();
  private store: SettingsStore | null = null;
  private hostContext: common.Context | null = null;
  private navStack: NavPathStack = new NavPathStack();

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (error) {
    }
  }

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.isLoading = false;
      return;
    }
    this.hostContext = context;
    this.encryptionFallback = DbHelper.usesPlaintextFallback() ||
      DebugFaults.encryptionFallback(context);
    try {
      this.store = await SettingsStore.open(context);
      this.settings = await this.store.load();
      try {
        const spend = await LlmSpendStore.open(context);
        this.spentYuan = (await spend.load()).spentYuan;
      } catch (error) {
        this.spentYuan = 0;
      }
      await this.loadBackgrounds(context);
      try {
        this.backupIncludeBackgrounds = await (await BackupOptionsStore.open(context)).includeBackgrounds();
      } catch (error) {
        this.backupIncludeBackgrounds = false;
      }
      await this.loadSafetyCopies();
      this.schemaIssueCount = getSchemaIssues().length;
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.showToast('设置读取失败，已使用默认值');
    }
  }

  private withProvider(provider: LlmProvider): void {
    this.settings = this.copySettings(provider, this.settings.llmModel, this.settings.llmMonthlyBudget,
      this.settings.defaultLevel, this.settings.llmBaseUrl, this.settings.llmApiKey);
    this.isDirty = true;
  }

  private withModel(model: string): void {
    this.settings = this.copySettings(this.settings.llmProvider, model, this.settings.llmMonthlyBudget,
      this.settings.defaultLevel, this.settings.llmBaseUrl, this.settings.llmApiKey);
    this.isDirty = true;
  }

  private withBudget(budget: number): void {
    this.settings = this.copySettings(this.settings.llmProvider, this.settings.llmModel, Math.round(budget),
      this.settings.defaultLevel, this.settings.llmBaseUrl, this.settings.llmApiKey);
    this.isDirty = true;
  }

  private withLevel(level: SecurityLevel): void {
    this.settings = this.copySettings(this.settings.llmProvider, this.settings.llmModel,
      this.settings.llmMonthlyBudget, level, this.settings.llmBaseUrl, this.settings.llmApiKey);
    this.isDirty = true;
  }

  private withBaseUrl(baseUrl: string): void {
    this.settings = this.copySettings(this.settings.llmProvider, this.settings.llmModel,
      this.settings.llmMonthlyBudget, this.settings.defaultLevel, baseUrl, this.settings.llmApiKey);
    this.isDirty = true;
  }

  private withApiKey(apiKey: string): void {
    this.settings = this.copySettings(this.settings.llmProvider, this.settings.llmModel,
      this.settings.llmMonthlyBudget, this.settings.defaultLevel, this.settings.llmBaseUrl, apiKey);
    this.isDirty = true;
  }

  private copySettings(provider: LlmProvider, model: string, budget: number, level: SecurityLevel,
    baseUrl: string, apiKey: string): AppSettings {
    return {
      llmEnabled: provider !== 'template',
      llmProvider: provider,
      llmBaseUrl: baseUrl,
      llmApiKey: apiKey,
      llmModel: model,
      llmMonthlyBudget: budget,
      defaultLevel: level
    };
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.store === null) {
      this.showToast('设置存储未就绪');
      return;
    }
    this.isSaving = true;
    try {
      this.settings = sanitizeAppSettings(this.settings);
      await this.store.save(this.settings);
      this.isDirty = false;
      this.showToast('设置已保存');
    } catch (error) {
      this.showToast('保存失败，请重试');
    } finally {
      this.isSaving = false;
    }
  }

  private async loadBackgrounds(context: common.Context): Promise<void> {
    const rows: BackgroundRowState[] = [];
    const states = await PageBackgroundService.groupStates(context);
    for (const state of states) {
      rows.push({ key: state.key, label: state.label, path: state.applied ? 'applied' : '' });
    }
    this.backgroundRows = rows;
    this.globalApplied = (await PageBackgroundService.getGlobal(context)).length > 0;
  }

  private appliedSummary(): string {
    let total = 0;
    for (const row of this.backgroundRows) {
      if (row.path.length > 0) {
        total += 1;
      }
    }
    if (total === 0) {
      return '尚未设置';
    }
    return this.globalApplied ? `全局默认 · 覆盖 ${total} 个页面` : `已应用到 ${total} 个页面`;
  }

  private shareExport(): void {
    if (this.isExporting || this.hostContext === null || this.lastExportPath.length === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '分享预览',
      message: `文件：${this.lastExportName}\n${this.lastExportChars} 字符 · 共 ${this.lastExportTotal} 条记录\n分享后文件会离开本机，可能被其他应用读取。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '继续分享',
        action: () => {
          this.doShare();
        }
      }
    });
  }

  private async doShare(): Promise<void> {
    if (this.hostContext === null || this.lastExportPath.length === 0) {
      return;
    }
    try {
      const service = await ExportService.open(this.hostContext);
      await service.share(this.hostContext, this.lastExportPath);
    } catch (error) {
      this.showToast('系统分享暂不可用，请使用另存为');
    }
  }

  private async backupData(): Promise<void> {
    if (this.hostContext === null || this.dataBusy) {
      return;
    }
    this.dataBusy = true;
    try {
      const name = await BackupService.backupToUser(this.hostContext);
      this.showToast(name.length > 0 ? `已备份 ${name}` : '已生成备份，但未另存');
    } catch (error) {
      this.showToast('备份失败；请检查存储空间或目录权限');
    } finally {
      this.dataBusy = false;
    }
  }

  private async restoreData(): Promise<void> {
    if (this.hostContext === null || this.dataBusy) {
      return;
    }
    this.dataBusy = true;
    try {
      const report = await BackupService.restoreFromUser(this.hostContext);
      if (report.outcome === RestoreOutcome.CANCELLED) {
        this.showToast('未选择备份文件');
        return;
      }
      this.showRestoreReport(report);
    } catch (error) {
      this.showToast('恢复失败；请确认文件是本应用导出的备份');
    } finally {
      this.dataBusy = false;
    }
  }

  private showRestoreReport(report: RestoreReport): void {
    const lines: string[] = [
      `记录：${report.records ? '已恢复' : '未恢复'}`,
      `设置：${report.settings ? '已恢复' : '未恢复'}`,
      `身份：${report.profile ? '已恢复' : '未恢复'}`,
      `背景：${report.backgrounds ? report.backgroundNote : '未恢复，' + report.backgroundNote}`
    ];
    const allDone = report.outcome === RestoreOutcome.RESTORED;
    this.getUIContext().showAlertDialog({
      title: allDone ? '恢复完成' : '部分恢复完成',
      message: `${lines.join('\n')}\n\n恢复前已保留当前数据库副本。建议重启应用后核对。`,
      primaryButton: {
        value: '知道了',
        action: () => {
        }
      }
    });
  }

  /** Debug only: makes the next launch report an unencrypted store. */
  private simulateEncryptionFailure(): void {
    if (this.hostContext === null) {
      this.showToast('运行环境未就绪');
      return;
    }
    DebugFaults.enableEncryptionFallback(this.hostContext);
    this.showToast('已开启加密失败模拟，重启应用后生效');
  }

  /** Debug only: makes the next restore fail after the database has been replaced. */
  private simulateRestoreFailure(): void {
    if (this.hostContext === null) {
      this.showToast('运行环境未就绪');
      return;
    }
    DebugFaults.enableRestoreFailure(this.hostContext);
    this.showToast('已开启恢复失败模拟，下次恢复会返回部分成功');
  }

  private clearDebugFlags(): void {
    if (this.hostContext === null) {
      this.showToast('运行环境未就绪');
      return;
    }
    const cleared = DebugFaults.clear(this.hostContext);
    this.encryptionFallback = DbHelper.usesPlaintextFallback() || DebugFaults.encryptionFallback(this.hostContext);
    this.showToast(cleared ? '调试标记已清除' : '没有调试标记');
  }

  /** Clears the failed-encryption marker; the next launch retries the rekey. */
  private retryEncryption(): void {
    if (this.hostContext === null) {
      this.showToast('运行环境未就绪');
      return;
    }
    const clearedFlag = DbHelper.clearEncryptionFailure(this.hostContext);
    const clearedDebug = DebugFaults.clear(this.hostContext);
    this.showToast(clearedFlag || clearedDebug ? '已登记重试，重启应用后将再次尝试加密' : '没有需要重试的加密失败记录');
    this.encryptionFallback = DbHelper.usesPlaintextFallback() || DebugFaults.encryptionFallback(this.hostContext);
  }

  /** Re-reads local records so the home header counters reflect the latest data. */
  private refreshHome(): void {
    notifyHomeRefresh();
    this.showToast('首页数据已刷新');
  }

  private async clearData(): Promise<void> {
    if (this.hostContext === null || this.dataBusy) {
      return;
    }
    if (!this.clearArmed) {
      this.clearArmed = true;
      this.showToast('再次点击“确认清空”才会删除全部记录');
      return;
    }
    this.dataBusy = true;
    try {
      await BackupService.clearAll(this.hostContext);
      profileCache.reset();
      notifyHomeRefresh();
      notifyProfileRefresh();
      this.clearArmed = false;
      this.showToast('全部记录、设置与本地文件已清空');
    } catch (error) {
      this.showToast('清空失败，请重试');
    } finally {
      this.dataBusy = false;
    }
  }

  private async loadSafetyCopies(): Promise<void> {
    if (this.hostContext === null) {
      return;
    }
    try {
      const copies = await BackupInventory.list(this.hostContext);
      this.safetyCount = copies.length;
      this.safetyLatest = copies.length > 0 ? formatCopyTime(copies[0].createdAt) : '';
    } catch (error) {
      this.safetyCount = 0;
      this.safetyLatest = '';
    }
  }

  private confirmClearSafetyCopies(): void {
    if (this.safetyCount === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '清理本机安全副本？',
      message: `会删除 ${this.safetyCount} 份恢复前自动保留的数据库副本。删除后无法再从这些副本回退。`,
      primaryButton: {
        value: '清理',
        action: () => {
          this.clearSafetyCopies();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private async clearSafetyCopies(): Promise<void> {
    if (this.hostContext === null) {
      return;
    }
    try {
      const removed = await BackupInventory.deleteAll(this.hostContext);
      await this.loadSafetyCopies();
      this.showToast(`已清理 ${removed} 份安全副本`);
    } catch (error) {
      this.showToast('清理失败，请重试');
    }
  }

  private async toggleBackupBackgrounds(): Promise<void> {
    if (this.hostContext === null) {
      return;
    }
    const next = !this.backupIncludeBackgrounds;
    try {
      await (await BackupOptionsStore.open(this.hostContext)).saveIncludeBackgrounds(next);
      this.backupIncludeBackgrounds = next;
      this.showToast(next ? '背景图片会写入备份' : '背景图片不写入备份');
    } catch (error) {
      this.showToast('保存失败，请重试');
    }
  }

  private currentExportOptions(): ExportOptions {
    return {
      includeLocalOnly: this.exportLocalOnly,
      includeOtherStatements: this.exportStatements,
      includeDemoRecords: this.exportDemo,
      includeHistory: this.exportHistory
    };
  }

  private requestExport(): void {
    if (this.isExporting) {
      return;
    }
    const options = this.currentExportOptions();
    if (!carriesLocalContent(options)) {
      this.exportMarkdown();
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '文件会离开应用沙箱',
      message: '你选择了仅本地内容或对方陈述原文。导出文件可以被其他应用打开，也可能被分享出去。',
      primaryButton: {
        value: '继续导出',
        action: () => {
          this.exportMarkdown();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private async exportMarkdown(): Promise<void> {
    if (this.isExporting) {
      return;
    }
    if (this.hostContext === null) {
      this.showToast('运行环境未就绪');
      return;
    }
    this.isExporting = true;
    try {
      const service = await ExportService.open(this.hostContext);
      const result = await service.exportMarkdown(this.hostContext, Date.now(), this.currentExportOptions());
      this.lastExportName = result.fileName;
      this.lastExportPath = result.filePath;
      this.lastExportChars = result.charCount;
      this.lastExportTotal = totalExportRecords(result.counts);
      const saved = await service.saveAs(this.hostContext, result);
      this.showToast(saved ? `已另存为 ${result.fileName}` : '已生成，但未另存');
    } catch (error) {
      this.showToast('导出失败；请检查存储空间或选择其他目录');
    } finally {
      this.isExporting = false;
    }
  }

  @Builder
  providerChip(label: string, provider: LlmProvider) {
    Text(label)
      .id(`settings_provider_${provider}`)
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.settings.llmProvider === provider ? Color.White : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.settings.llmProvider === provider ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.withProvider(provider);
      })
  }

  @Builder
  modelChip(option: ModelOption) {
    Text(option.label)
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.settings.llmModel === option.id ? Color.White : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.settings.llmModel === option.id ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.withModel(option.id);
      })
  }

  @Builder
  levelChip(level: SecurityLevel) {
    Text(securityLevelText(level))
      .fontSize(AppTheme.font.bodyStrong)
      .fontColor(this.settings.defaultLevel === level ? Color.White : AppTheme.color.text)
      .padding({ left: AppTheme.spacing.s12, right: AppTheme.spacing.s12, top: AppTheme.spacing.s6, bottom: AppTheme.spacing.s6 })
      .backgroundColor(this.settings.defaultLevel === level ? AppTheme.color.primary : AppTheme.color.chip)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        this.withLevel(level);
      })
  }

  build() {
    AppDestination({
      route: 'settings',
      title: '设置',
      content: () => {
        this.settingsBody();
      },
      onDestinationReady: (context: NavDestinationContext) => {
        this.navStack = context.pathStack;
      },
      onDestinationShown: () => {
        if (this.hostContext !== null) {
          this.loadBackgrounds(this.hostContext);
        }
      }
    })
  }

  @Builder
  settingsBody() {
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
      } else {
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              SectionCard() {
                Column({ space: 10 }) {
                  Row() {
                    Column({ space: 2 }) {
                      Text('复盘 Agent 模式')
                        .fontSize(AppTheme.font.subtitle)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.color.text)
                      Text('模板离线可用；本地模拟走 mock-server；模型端点走 OpenAI 兼容接口')
                        .fontSize(AppTheme.font.body)
                        .fontColor(AppTheme.color.textSecondary)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')

                  Row({ space: 6 }) {
                    this.providerChip('模板', 'template')
                    this.providerChip('本地模拟', 'mock')
                    this.providerChip('模型', 'model')
                  }

                  if (this.settings.llmProvider !== 'template') {
                    Text('模型')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(MODEL_OPTIONS, (option: ModelOption) => {
                        this.modelChip(option)
                      }, (option: ModelOption) =>
                        `${option.id}_${this.settings.llmModel === option.id ? 1 : 0}`)
                    }
                    .width('100%')

                    Row() {
                      Text('月预算')
                        .fontSize(AppTheme.font.body)
                        .fontColor(AppTheme.color.textSecondary)
                      Blank()
                      Text(`¥${this.settings.llmMonthlyBudget}`)
                        .fontSize(AppTheme.font.bodyStrong)
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

                    Text('上限 500 元；0 表示不进行付费调用；模型调用按字符估算并记账')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')

                    Text(`本月已记账 ¥${this.spentYuan.toFixed(2)} / 预算 ¥${this.settings.llmMonthlyBudget}`)
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }

                  if (this.settings.llmProvider === 'model') {
                    Text('接口地址')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                    TextInput({ text: this.settings.llmBaseUrl, placeholder: 'http://localhost:4523/v1' })
                      .backgroundColor(AppTheme.color.surfaceAlt)
                      .onChange((value: string) => {
                        this.withBaseUrl(value);
                      })
                    Text('真机请填写宿主机局域网地址；Mock 提示与模型请求共用此主机。')
                      .fontSize(AppTheme.font.caption)
                      .lineHeight(16)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')

                    Text('API Key（可空，仅存本机）')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textSecondary)
                      .width('100%')
                    TextInput({ text: this.settings.llmApiKey, placeholder: 'sk-...' })
                      .type(InputType.Password)
                      .backgroundColor(AppTheme.color.surfaceAlt)
                      .onChange((value: string) => {
                        this.withApiKey(value);
                      })

                    Text('开启模型模式后，事实、解释与锚点会发往该地址；Key 只保存在本机，不进导出。')
                      .fontSize(AppTheme.font.caption)
                      .lineHeight(16)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }

                  Text('小艺接入需要 HarmonyOS 7 与已发布智能体，当前 SDK 不提供，暂不开放。')
                    .fontSize(AppTheme.font.caption)
                    .lineHeight(16)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 10 }) {
                  Text('新速记默认密级')
                    .fontSize(AppTheme.font.subtitle)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('仅影响新建记录；已有记录保持原密级')
                    .fontSize(AppTheme.font.body)
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
                    .fontSize(AppTheme.font.subtitle)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('先选要写进文件的内容，再另存到你选择的位置。')
                    .fontSize(AppTheme.font.body)
                    .lineHeight(17)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')

                  ForEach(describeExportOptions(), (line: string) => {
                    Text(line)
                      .fontSize(AppTheme.font.caption)
                      .lineHeight(16)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }, (line: string) => line)

                  Row() {
                    Text('仅本地内容')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.text)
                    Blank()
                    Text(this.exportLocalOnly ? '纳入 · 已开启' : '不纳入')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(this.exportLocalOnly ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                      .backgroundColor(this.exportLocalOnly ? AppTheme.color.tint : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.sm)
                      .id('settings_export_local')
                  }
                  .width('100%')
                  .height(40)
                  .onClick(() => {
                    this.exportLocalOnly = !this.exportLocalOnly;
                  })

                  Row() {
                    Text('对方陈述原文')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.text)
                    Blank()
                    Text(this.exportStatements ? '纳入 · 已开启' : '不纳入')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(this.exportStatements ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                      .backgroundColor(this.exportStatements ? AppTheme.color.tint : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.sm)
                      .id('settings_export_statement')
                  }
                  .width('100%')
                  .height(40)
                  .onClick(() => {
                    this.exportStatements = !this.exportStatements;
                  })

                  Row() {
                    Text('示例数据')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.text)
                    Blank()
                    Text(this.exportDemo ? '纳入 · 已开启' : '不纳入')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(this.exportDemo ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                      .backgroundColor(this.exportDemo ? AppTheme.color.tint : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.sm)
                      .id('settings_export_demo')
                  }
                  .width('100%')
                  .height(40)
                  .onClick(() => {
                    this.exportDemo = !this.exportDemo;
                  })

                  Row() {
                    Text('包含历史版本')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.text)
                    Blank()
                    Text(this.exportHistory ? '纳入 · 已开启' : '不纳入')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(this.exportHistory ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                      .backgroundColor(this.exportHistory ? AppTheme.color.tint : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.sm)
                      .id('settings_export_history')
                  }
                  .width('100%')
                  .height(40)
                  .onClick(() => {
                    this.exportHistory = !this.exportHistory;
                  })

                  Text(this.isExporting ? '导出中…' : '导出并另存为')
                    .id('settings_export_button')
                    .fontSize(AppTheme.font.bodyStrong)
                    .fontColor(this.isExporting ? AppTheme.color.textMuted : AppTheme.color.primary)
                    .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s8 })
                    .backgroundColor(AppTheme.color.tint)
                    .borderRadius(AppTheme.radius.md)
                    .accessibilityText('导出记录并另存为 Markdown')
                    .onClick(() => {
                      this.requestExport();
                    })

                  if (this.lastExportPath.length > 0) {
                    Text('分享')
                      .fontSize(AppTheme.font.bodyStrong)
                      .fontColor(AppTheme.color.primary)
                      .padding({ left: AppTheme.spacing.s10, right: AppTheme.spacing.s10, top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
                      .onClick(() => {
                        this.shareExport();
                      })
                  }

                  if (this.lastExportName.length > 0) {
                    Text(`已写入 ${this.lastExportName}`)
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.text)
                      .width('100%')
                    Text(`${this.lastExportChars} 字符 · 共 ${this.lastExportTotal} 条记录`)
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textMuted)
                      .width('100%')
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              if (this.schemaIssueCount > 0) {
                SectionCard() {
                  Column() {
                    Text(`数据结构未就绪：${this.schemaIssueCount} 项，请先备份再升级`)
                      .id('settings_schema_issue')
                      .fontSize(AppTheme.font.body)
                      .lineHeight(17)
                      .fontColor(AppTheme.color.danger)
                      .width('100%')
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('备份范围')
                    .fontSize(AppTheme.font.subtitle)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('记录、身份与设置始终写入备份；封存内容只留本机，不进备份，也不支持随备份迁移。')
                    .fontSize(AppTheme.font.body)
                    .lineHeight(17)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row() {
                    Text('备份包含背景图片')
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.text)
                    Blank()
                    Text(this.backupIncludeBackgrounds ? '包含 · 已开启' : '不包含')
                      .fontSize(AppTheme.font.caption)
                      .fontColor(this.backupIncludeBackgrounds ? AppTheme.color.primaryDeep : AppTheme.color.textSecondary)
                      .padding({ left: AppTheme.spacing.s8, right: AppTheme.spacing.s8, top: AppTheme.spacing.s2, bottom: AppTheme.spacing.s2 })
                      .backgroundColor(this.backupIncludeBackgrounds ? AppTheme.color.tint : AppTheme.color.chip)
                      .borderRadius(AppTheme.radius.sm)
                      .id('settings_export_backup_background')
                  }
                  .width('100%')
                  .height(40)
                  .onClick(() => {
                    this.toggleBackupBackgrounds();
                  })
                  Text('背景图片默认只留在本机；开启后才会写进备份文件。')
                    .fontSize(AppTheme.font.caption)
                    .lineHeight(15)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                  Row() {
                    Text(this.safetyCount === 0 ? '本机安全副本：暂无' :
                      `本机安全副本：${this.safetyCount} 份 · 最近 ${this.safetyLatest}`)
                      .fontSize(AppTheme.font.caption)
                      .fontColor(AppTheme.color.textMuted)
                      .layoutWeight(1)
                    if (this.safetyCount > 0) {
                      Text('清理')
                        .fontSize(AppTheme.font.body)
                        .fontColor(AppTheme.color.danger)
                        .id('settings_backup_clean')
                        .onClick(() => {
                          this.confirmClearSafetyCopies();
                        })
                    }
                  }
                  .width('100%')
                  Text('每次恢复前都会先保留一份当前数据库副本；清理后无法再从这些副本回退。')
                    .fontSize(AppTheme.font.caption)
                    .lineHeight(15)
                    .fontColor(AppTheme.color.textMuted)
                    .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              DataManagementCard({
                dataBusy: this.dataBusy,
                clearArmed: this.clearArmed,
                encryptionFallback: this.encryptionFallback,
                onBackup: () => {
                  this.backupData();
                },
                onRestore: () => {
                  this.restoreData();
                },
                onClear: () => {
                  this.clearData();
                },
                onRetryEncryption: () => {
                  this.retryEncryption();
                },
                onRefreshHome: () => {
                  this.refreshHome();
                }
              })

              if (BuildProfile.DEBUG) {
                DebugPanel({
                  onSimulateEncryption: () => {
                    this.simulateEncryptionFailure();
                  },
                  onSimulateRestore: () => {
                    this.simulateRestoreFailure();
                  },
                  onClearFlags: () => {
                    this.clearDebugFlags();
                  }
                })
              }

              SectionCard() {
                Column({ space: 8 }) {
                  Text('页面背景')
                    .fontSize(AppTheme.font.subtitle)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('设置各页面的背景图与应用范围；进入后可选择图片、应用到指定模块或恢复默认。')
                    .fontSize(AppTheme.font.body)
                    .lineHeight(17)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Row({ space: 8 }) {
                    Text(this.backgroundBusy === 'pending' ? '读取中…' : '打开页面背景')
                      .fontSize(AppTheme.font.bodyStrong)
                      .fontColor(Color.White)
                      .padding({ left: AppTheme.spacing.s16, right: AppTheme.spacing.s16, top: AppTheme.spacing.s10, bottom: AppTheme.spacing.s10 })
                      .backgroundColor(AppTheme.color.primary)
                      .borderRadius(AppTheme.radius.sm)
                      .accessibilityText('打开页面背景设置')
                      .onClick(() => {
                        this.navStack.pushPathByName(ROUTES.BACKGROUND_APPLY, null);
                      })
                    Blank()
                    Text(this.appliedSummary())
                      .fontSize(AppTheme.font.body)
                      .fontColor(AppTheme.color.textMuted)
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              SectionCard() {
                Column({ space: 6 }) {
                  Text('数据与隐私')
                    .fontSize(AppTheme.font.subtitle)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.color.text)
                    .width('100%')
                  Text('业务数据只保存在本机；LLM 默认关闭，开启后仅发送复盘所需文本。')
                    .fontSize(AppTheme.font.body)
                    .lineHeight(18)
                    .fontColor(AppTheme.color.textSecondary)
                    .width('100%')
                  Text('密级为「已封存」的记录不会进入导出、备份与模型上下文。')
                    .fontSize(AppTheme.font.body)
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
              .fontSize(AppTheme.font.subtitle)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: AppTheme.spacing.s12, bottom: AppTheme.spacing.s12 })
              .backgroundColor(this.isDirty && !this.isSaving ? AppTheme.color.primary : AppTheme.color.primaryDisabled)
              .borderRadius(AppTheme.radius.md)
              .accessibilityText(this.isSaving ? '正在保存设置' : '保存设置')
              .onClick(() => {
                if (!this.isSaving && this.isDirty) {
                  this.save();
                }
              })
          }
          .width('100%')
          .padding({ left: AppTheme.spacing.page, right: AppTheme.spacing.page, top: AppTheme.spacing.s8, bottom: AppTheme.spacing.s24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
      }
  }
}

/** Formats a safety-copy timestamp as YYYY-MM-DD HH:mm. */
function formatCopyTime(stamp: number): string {
  if (stamp <= 0) {
    return '时间未知';
  }
  const date = new Date(stamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const hour = date.getHours();
  const minute = date.getMinutes();
  const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
  return `${date.getFullYear()}-${pad(month)}-${pad(day)} ${pad(hour)}:${pad(minute)}`;
}
