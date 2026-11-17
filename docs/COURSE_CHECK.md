# 课程硬性项与人工场景核对

> 2026-11-16 复核。代码与静态检查可复现；Previewer 截图与报告属人工项，未在命令行伪造。

## 1. 六项硬性要求

| 项 | 证据 | 结果 |
|---|---|---|
| Previewer 第一验收环境 | `entry/src/main/ets/preview/` 的 PreviewStore/PreviewData；页面 `isPreview` 分支 | 代码就绪，截图待人工 |
| 网络三态 | `settings/AppSettings.ts` 的 `llmProvider: template / mock / model`；设置页三档切换；`RequestBuilder` 与 `LlmContradictionAnalyzer` 回退 | 已覆盖 |
| 组件化 | `pages/` 34 个页面文件，`components/` 42 个组件文件 | 已覆盖 |
| Navigation | `NavPathStack` 出现在 32 个文件；`Index.pageMap` 集中注册 | 已覆盖 |
| 状态管理 V2 | `@ComponentV2` 出现在 80 个文件；`@Local` / `@Param` / `@Event` | 已覆盖 |
| 可视化 | `SimpleLineChart`、`PlanWeekView`、`PlanMonthView`、`LinkCompositionCard` 等 5 个文件 | 已覆盖 |

## 2. 13 个人工场景

| # | 场景 | 自动化证据 | 人工状态 |
|---|---|---|---|
| 1 | 新建速记并保存 | service 检查、check | 待截图 |
| 2 | 编辑速记与密级 | check、export 检查 | 待截图 |
| 3 | 复盘六区填写 | check 101+、service 92 | 待截图 |
| 4 | 保存决定与承诺 | service 决定事务与回滚 | 待截图 |
| 5 | 创建预测 | agent/service 检查 | 待截图 |
| 6 | 结算预测与命中率 | service 结算检查 | 待截图 |
| 7 | 创建锚点与选择理由 | service 锚点时间/理由 | 待截图 |
| 8 | 关系互动与纠正 | service 关系纠正、check | 待截图 |
| 9 | 状态读数与暂停 | service 状态、check | 待截图 |
| 10 | 计划周节点与清单处置 | service 四类计数 | 待截图 |
| 11 | 导出 Markdown | export 35 | 待截图 |
| 12 | 分享预览 | check 分享预览 | 待截图 |
| 13 | LLM 三态与回退 | agent 16、privacy 12 | 待截图 |

## 3. 当前验证

- tsc：0 错
- check：115
- service：110
- export：40
- agent：16
- privacy：15
- 合计：296
- `assembleHap`：通过
- `PreviewBuild`：通过
- arkts：仅 2 个改前既有的 BuildProfile 模块解析错误，无新增错误

模拟器演示截图（Previewer 走查的代理证据，存 `.workbuddy/auto/shots/`）：
home-v4（书写主卡＋痕迹流）、note-v2（三栏并置）、review-v3（区导航轨＋常驻保存）。
Previewer 13 场景仍需在 IDE 内逐页走查截全，文件名与场景号对应。

## 4. 人工待办

1. 在 DevEco Previewer 逐页走查，按上表截 13 张图，文件名与场景号对应。
2. 报告只使用脱敏数据；关系名、真实姓名、内网地址不得入图。
3. 截图与报告完成后，再决定是否推送；推送需作者单独授权。
