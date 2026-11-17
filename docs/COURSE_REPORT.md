# Cogit Lucid 结课设计报告（移动应用开发）

> 题目：HarmonyOS 的元认知外化工作台的设计与实现——基于 ArkTS 的个人复盘移动应用开发实践
> 基线：DevEco Studio 26.0.0 Release（HarmonyOS 7.0.0，API 26），最低兼容 6.0.0(20)；状态管理 V2；Stage 模型。
> 验收口径：课程 100 分细则 + 硬性四项；思想依据为《作者方法论》《整体大改方案》等四份对齐文档。

## 一、选题与需求（10 分）

选题已在班级登记，主题不重复。需求来源不是功能清单，而是作者方法论的三层运行：

1. **经验转化**：把现场、感受、身体、既有行动分别保存，解释默认折叠、可跳过；只写现场即可保存。
2. **实践迭代**：解释成为可失效假设（必填预测/适用范围/失效条件/未知项），行动结果、他者回应、身体反馈、时间经历具有否决权；修订走规定性否定五步。
3. **元监控**：识别动机/成本/方向，允许继续/切换/暂停/退出；监控自身可被暂停，疲惫时应用自动减少要求（减法模式）。

明确不做：心理量表/诊断/治疗承诺、成长评分/等级/排行榜、连续打卡/缺席警告、人格/依恋类型标签、AI 替用户生产终极理由。

## 二、UI 布局与容器组件（20 分）

- 容器：Row/Column/List/Grid/Scroll/Flex/Stack 全覆盖；首页为书写主卡＋痕迹流，模块网格下移为次要。
- 断点响应式：sm/md/lg 栅格；卡片 16vp 圆角、发丝描边、弹簧入场（curves.springMotion）、按压反馈（clickEffect）。
- 原生图标：SymbolGlyph（chevron_forward/plus 等）替换全部文本箭头；悬浮按钮原生 Symbol。
- 空态哲学：核心书写面空白即空白（无占位/骨架），外围列表保留轻量引导；无数字徽章/红点/进度/连续天数。
- 渐进披露：速记三栏并置（现场永远可见/感受可选/解释折叠）；状态/关系/锚点可选字段折叠；复盘六区可横滑跳转折返。

## 三、自定义组件与状态管理（20 分）

- 35+ 自定义组件（SectionCard/NoteCard/ModuleCard/ReviewForm/ReviewPromptPanel/RecentNotesCard/…），全部 @ComponentV2 + @Local/@Param/@Event/@BuilderParam。
- 状态管理 V2：@ObservedV2/@Trace 用于跨组件观察；无 V1 @Link/@Prop 混用。
- 组件复用：SectionCard 统一表面语言；折叠开关模式复用于速记/计划/状态/关系/锚点。

## 四、Navigation 路由（15 分）

- Navigation + NavDestination，33 个 destination，路由字符串稳定（Routes.ts 未改），统一 AppDestination 标题栏。
- 跳转传参（NoteEditParams/PredictionListParams/…），返回栈管理；复盘/计划/预测间明确传参。

## 五、网络交互（15 分，硬性）

- 远端示例看板（合成数据）+ 复盘提示接口 + OpenAI 兼容模型请求，三态（加载/异常/空数据）齐全，失败回退离线模板。
- 三 provider：template（默认离线）/mock/model；请求前清单逐次确认、审计只记元数据不记正文。
- 权限最小化、动态申请、拒绝不退出。

## 六、Git 版本管理（10 分）

分阶段提交，英文 subject + 中文 body，无 attribution。关键提交：
`0b062a4` 官方令牌基线；`8849cc5` 二值口径统一；`cb03f73` 首页书写台；`16c121c` 快速档；`7d0533a` 复盘区导航；`2caadcb` 预测渐进披露；`4f7f28d` DB22；`a57b321` 参与方式/证据栏；`b564650` DB22 界面；`6b3e4d8` 导出来源；`22a0382` 内联书写；`93e7e93` 三栏并置；`c9ae15d` 假设卡+模板隐私修复；`5828542` 减法模式；`fc93500` 原生 Symbol。

## 七、代码规范与文档（10 分）

- 英文标识符、中文注释；analysis/ 纯函数层只 import model/，服务层负责 IO，299 条断言全绿。
- 文档：PROJECT.md/AGENTS.md/README 双语/UI_FREEZE.md/MANUAL_CHECKS.md/COURSE_CHECK.md 同步。

## 八、数据迁移与隐私（加分叙述）

- DB 21→22：prediction 增 missing/explanatory_gain；plan 增 beneficiary/cost_bearer；decision_record 增 participation_mode；experience_material 增 claim_evidence。幂等 ALTER，旧库按默认值读取，三套旧库对照。
- 密级三档（ANALYZABLE/LOCAL_ONLY/SEALED）×动作矩阵；**离线模板路径同样剔除 SEALED 与禁分析关系**（修复了默认 provider 绕过判定的 P0）。
- 他者材料：同意前置、查阅/更正/删除通道；拒绝不可洗白。
- 生成式 AI：默认不生成文本（仅分词/实体抽取/OCR/语音转写+规则词典），避开标识/备案义务；开启 model 时显式标识。

## 九、测试与验证

- 单元/服务/导出/隐私/agent/plan 六组断言 299 条全绿；tsc 0 错；assembleHap/PreviewBuild 通过。
- 不变量测试：现场不可改、无失效条件拒存、空白不推断、拒绝不可洗白、旧版本只读、termOnly 真假分支、减法阈值真假分支、模板密级矩阵。
- 减法模式有效性用作者自身对照检验，不宣称疗效、不做量表。

## 十、课程硬性四项核对

| 项 | 证据 |
|---|---|
| 独立开发 | 全部自建代码，无套用完整开源模板 |
| Previewer 可预览交互 | PreviewBuild 通过；preview/ 演示态不依赖数据库 |
| 网络交互+三态 | 远端看板+提示接口+模型请求，三态齐全 |
| 课程核心技术点 | 容器/自定义组件/V2/Navigation/分阶段 Git |

## 十一、局限与后续

- 门（时间锁）为应用层强制非密码学；他者元服务回应、手表身体否决、端 A2A 依赖真机与上架，列为后续。
- 减法模式触发为启发式，可能误判，可一次性关闭。
- 纯记录工具是否被归入医疗保健服务待上架前向应用市场客服确认。