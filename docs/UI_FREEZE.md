# UI 冻结记录

冻结日期：2026-10-27。此后视觉改动只允许通过 `theme/AppTheme.ts` 与本文档同步进行，禁止页面级一次性色值。

## 1. 色板（已锁定）

| 语义 | 值 | 用途 |
|---|---|---|
| page | `#F5F6F8` | 页面底色 |
| surface | `#FFFFFF` | 卡片、输入框 |
| primary | `#4A6FA5` | 主按钮、选中态 |
| primaryDeep | `#185FA5` | 链接、强调文字 |
| primaryDisabled | `#8FA6C4` | 禁用按钮 |
| text | `#1F2329` | 主文字 |
| textStrong | `#444441` | 次级标题 |
| textSecondary | `#8A8F99` | 说明文字 |
| textSecondaryStrong | `#5F5E5A` | 表单标签 |
| textMuted | `#B0B4BE` | 时间、脚注 |
| border | `#E0E0E0` | 默认描边 |
| borderStrong | `#D3D1C7` | 虚线空态 |
| borderSelected | `#B7CDE8` | 选中卡片描边 |
| tint | `#E8EFF7` | 浅蓝标签底 |
| chip | `#F1EFE8` | 未选中 chip |
| surfaceAlt | `#F7F6F2` | 输入框底、浅色块 |
| surfaceTint | `#F7F9FC` | 正文输入底 |
| surfaceWarm | `#FFFDF5` | 锚点对照底 |
| selectedSurface | `#F3F7FC` | 选中行底 |
| track | `#EEF0F3` | 进度条轨道 |
| success / surface | `#2E7D32` / `#E8F5E9` | 命中、允许 |
| warning / surface | `#B0761E` / `#FFF4E0` | 待结算、受限 |
| danger / surface | `#A32D2D` / `#FCEBEB` | 失败、禁分析 |
| accentPurple | `#6B5B95` | 模块图标点缀 |
| accentGold | `#E8A93C` | 模块图标点缀 |

## 2. 字号

| 级别 | 字号 | 用途 |
|---|---|---|
| 页面标题 | 22 | 首页品牌名 |
| 区块标题 | 14–16 | 卡片标题、步骤标题 |
| 正文 | 13 | 内容、输入 |
| 辅助 | 11 | 说明、标签 |
| 脚注 | 10 | 时间、口径 |

## 3. 圆角与间距

- 卡片 12，标签 6–8，chip 14–16；
- 页面边距 16，卡片内边距 14，块间距 8–12。

## 4. 组件规则

- 新页面统一 `SectionCard` + `AppTheme`；
- 空态统一 `NoteEmptyState`，四态必须齐全；
- 主按钮满宽 12 圆角，次按钮用 tint 底；
- 不使用阴影、渐变、第三方图标库。

## 5. 已知偏差

- 旧页面仍有硬编码色值，但取值与色板一致；迁移到 token 属纯重构，不改变视觉；
- 未做深色模式；
- 模块网格使用 emoji 图标，属既有风格，暂不替换为图标资源。

## 6. 阶段 7 目视清单

1. 首页：标题栏、读数、模块网格、待结算，窄屏不换行错位；
2. 速记：模板切换、正文/字段、关联关系 chips、保存返回；
3. 预测：新建表单、日期输入、到期/已结算详情、统计趋势与环图；
4. 复盘：四步切换、锚点勾选、Agent 面板、历史与详情；
5. 关系：筛选、详情关联记录、星图节点不重叠；
6. 状态：最近读数、七次汇总、历史；
7. 设置：三档 provider、Key 输入、预算记账、导出结果；
8. 全局：加载/空/失败三态、键盘遮挡、返回栈。

## 7. 变更流程

1. 先改 `AppTheme` 与本文档；
2. 再改组件与页面；
3. 至少跑 `assembleHap` 与 `PreviewBuild`；
4. 目视清单逐项打勾后才算完成。
