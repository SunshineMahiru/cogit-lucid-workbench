/** What the author chose to include in one Markdown export. Sealed records are never included. */
export interface ExportOptions {
  /** Local-only text is left out until the author opts in */
  includeLocalOnly: boolean;
  /** Other people's statements appear as placeholders until the author opts in */
  includeOtherStatements: boolean;
  /** Synthetic demo rows are left out by default */
  includeDemoRecords: boolean;
}

/** Defaults: analyzable content only, statements masked, no demo rows. */
export function defaultExportOptions(): ExportOptions {
  return {
    includeLocalOnly: false,
    includeOtherStatements: false,
    includeDemoRecords: false
  };
}

/** One line per category telling the author where the content ends up. */
export function describeExportOptions(): string[] {
  return [
    '可分析内容：始终写入导出文件',
    '仅本地内容：默认不写入，勾选后才写入；文件会离开应用沙箱',
    '对方陈述：默认写成「仅保存在本机」，勾选后才写入原文',
    '示例数据：默认不写入，勾选后才写入',
    '封存内容：始终不写入，也不进入备份'
  ];
}

/** Reports whether any choice makes the file carry content that stays local by default. */
export function carriesLocalContent(options: ExportOptions): boolean {
  return options.includeLocalOnly || options.includeOtherStatements;
}
