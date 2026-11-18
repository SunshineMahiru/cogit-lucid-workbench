# UI 冻结记录

冻结日期：2026-10-27。此后视觉改动只允许通过 `theme/AppTheme.ets` 与本文档同步进行，禁止页面级一次性色值。

## 1. 色板（已锁定）

`ThemePalette` 共 32 个语义色。15 个引用系统令牌，深浅色由系统资源自动切换：

| 语义 | 系统令牌 | 用途 |
|---|---|---|
| page | `sys.color.background_primary` | 页面底色 |
| surface | `sys.color.comp_background_list_card` | 卡片、输入框 |
| text | `sys.color.font_primary` | 主文字 |
| textStrong | `sys.color.font_primary` | 次级标题 |
| textSecondary | `sys.color.font_secondary` | 说明文字 |
| textSecondaryStrong | `sys.color.font_secondary` | 表单标签 |
| textMuted | `sys.color.font_tertiary` | 时间、脚注 |
| border | `sys.color.comp_divider` | 默认描边 |
| borderStrong | `sys.color.comp_outline_color` | 虚线空态 |
| tint | `sys.color.comp_background_secondary` | 标签底、选中 chip |
| surfaceAlt | `sys.color.comp_background_gray` | 输入框底、浅色块 |
| surfaceTint | `sys.color.comp_background_tertiary` | 正文输入底 |
| selectedSurface | `sys.color.interactive_select` | 选中行底 |
| chip | `sys.color.comp_background_secondary` | 未选中 chip |
| track | `sys.color.comp_background_gray` | 进度条轨道 |

其余 17 个保留应用自定双套，由 `applyTheme` 按深浅切换：

| 语义 | 浅色 | 深色 | 用途 |
|---|---|---|---|
| primary | `#4A6FA5` | `#8FB4E3` | 主按钮、选中态 |
| primaryDeep | `#185FA5` | `#B8D3F0` | 链接、强调文字 |
| borderSelected | `#B7CDE8` | `#4F6F91` | 选中卡片描边 |
| surfaceWarm | `#FFFDF5` | `#2A2418` | 锚点对照底 |
| primaryDisabled | `#8FA6C4` | `#586574` | 禁用按钮 |
| accentPurple | `#6B5B95` | `#A99BD2` | 模块图标点缀 |
| accentGold | `#E8A93C` | `#D8B25E` | 模块图标点缀 |
| warning | `#B0761E` | `#E0A85C` | 待结算、受限 |
| warningSurface | `#FFF4E0` | `#3A2C18` | 警示标签底 |
| success | `#2E7D32` | `#78C98A` | 命中、允许 |
| successSurface | `#E8F5E9` | `#1E3424` | 成功标签底 |
| danger | `#A32D2D` | `#F08A8A` | 失败、禁分析 |
| dangerSurface | `#FCEBEB` | `#3E2020` | 危险标签底 |
| heatEmpty | `#EDEBE4` | `#23272C` | 热力图空格 |
| heatLow | `#B7D3E8` | `#1F3A52` | 热力图低档 |
| heatMid | `#6FA8CC` | `#2E6F9E` | 热力图中档 |
| heatHigh | `#2E6F9E` | `#6FA8CC` | 热力图高档 |

四个语义色保留自定的依据是白字压底或色块压底的对比度：

- primary：白字压 `#4A6FA5` 为 5.11:1，白字压官方 `brand` `#007DFF` 为 3.91:1，低于正文要求的 4.5:1；
- warning：官方 `alert` `#FF7500` 压 `warningSurface` `#FFF4E0` 约 2.5:1，低于 4.5:1；
- danger：官方 `warning` `#FA2A2D` 压 `dangerSurface` `#FCEBEB` 约 3.4:1，低于 4.5:1；
- borderSelected 与保留的 primary 配套，选中描边不会变成官方鲜蓝而与主色脱节。

系统色板的语义槽少于本项目的 32 槽，由此产生四组合并，已在设计上接受：

- `text` 与 `textStrong` 同为 `font_primary`；
- `textSecondary` 与 `textSecondaryStrong` 同为 `font_secondary`；
- `tint` 与 `chip` 同为 `comp_background_secondary`，选中与未选中 chip 靠文字色区分；
- `surfaceAlt` 与 `track` 同为 `comp_background_gray`。

`selectedSurface` 取 `interactive_select`，`borderSelected` 保留自定，两者来源不同，选中块的填充与描边不会同色而失去边界。

## 2. 字号

七档字阶，定义在 `theme/AppTheme.ets` 的 `AppTheme.font`，全部引用系统 fp 令牌。新代码只引用令牌，不写字面字号。

| 令牌 | 字号 | 系统令牌 | 字重 | 用途 |
|---|---|---|---|---|
| caption | 12 | `sys.float.Caption_L` | Medium | 时间、口径、脚注 |
| body | 14 | `sys.float.Body_M` | Regular | 说明、标签、次要正文 |
| bodyStrong | 16 | `sys.float.Body_L` | Medium | 卡片正文、列表主文字 |
| subtitle | 18 | `sys.float.Subtitle_L` | Medium | 卡片标题、区块小标题 |
| title | 20 | `sys.float.Title_S` | Bold | 页面内主标题、统计数值 |
| headline | 24 | `sys.float.Title_M` | Bold | 强调数值、弹层标题、首页品牌名 |
| display | 38 | `sys.float.Display_S` | Light | 大号读数 |

`display` 只用于 `pages/StatusPage.ets:393` 与 `pages/PredictionStatsPage.ets:162` 两处大号读数；首页时间头用 `title` 排日期、`bodyStrong` 排时刻，首页不再有品牌名区。

## 2.1 字重

`FONT_WEIGHT` 与字阶一一对应，取值来自 ArkUI `FontWeight` 枚举：caption Medium、body Regular、bodyStrong Medium、subtitle Medium、title Bold、headline Bold、display Light。枚举没有 `Light` 成员，display 取 `FontWeight.Lighter`。系统 `sys.float.font_weight_*` 的值是 0–8 的索引，不是 `fontWeight` 接受的取值，不引用。

## 2.2 行高

`LINE_HEIGHT` 与字阶一一对应，单位 vp：caption 18、body 22、bodyStrong 24、subtitle 28、title 30、headline 34、display 48。caption 到 title 取字号 1.5 倍向上取偶数，headline 取 1.42 倍，display 取 1.26 倍。平台只提供行间距增量令牌 `sys.float.ohos_id_text_line_space_s`（1.1vp）与 `_l`（1.4vp），没有绝对行高令牌，因此这一组是自定绝对值。

## 3. 圆角与间距

两套都是标尺，定义在 `theme/AppTheme.ets`。

圆角六档 `AppTheme.radius`：

| 令牌 | 值 | 典型用途 |
|---|---|---|
| xs | 4 | 小标签内衬 |
| sm | 8 | chip、输入框 |
| md | 12 | 卡片、主按钮 |
| lg | 16 | 大卡片、弹层 |
| xl | 24 | 悬浮按钮、胶囊 |
| xxl | 28 | 大头像、特殊圆角 |

图表图例色块写 0，与直角格子保持同形；头像用 `size / 2` 维持正圆。

官方圆角为 card 8vp、button 20vp、dialog 16vp，现有 md 为 12vp，卡片与主按钮都与官方有差值；这一批不改圆角，差异留到 C2 批处理。

间距九档 `AppTheme.spacing`，另保留四个语义别名：`page` 与 `card` 指向 s16，`section` 指向 s12，`gap` 指向 s8。

| 令牌 | 值 |
|---|---|
| s2 / s4 / s6 / s8 / s10 | 2 / 4 / 6 / 8 / 10 |
| s12 / s16 / s20 / s24 | 12 / 16 / 20 / 24 |

保留字面量的三处例外：三张图表的 Y 轴缩进按坐标轴标签宽度定，速记列表底部留 80 给悬浮按钮。

## 4. 组件规则

- 新页面统一 `SectionCard` + `AppTheme`；
- 空态统一 `NoteEmptyState`，四态必须齐全；
- 主按钮满宽 12 圆角，次按钮用 tint 底；
- 不使用阴影、渐变、第三方图标库；
- 速记的记录密级 chip、材料三组 chip、关联关系 chip 均为 `tint` 底 + `primaryDeep` 字，未选中为 `chip` 底 + 正文色；两种底色同取官方 `comp_background_secondary`，靠文字色区分。实测浅色 chip 底 `#E6E6E6`，选中字 5.23:1、未选中字 12.6:1；深色 chip 底 `#191919`，选中字 11.4:1、未选中字 14.4:1，深浅两态都不低于 4.5:1；每个可选 chip 必须带稳定 `id`；其余页面的选中态仍为主色底白字，待后续统一；
- 速记编辑的深度 chip 固定 `note_depth_quick` / `note_depth_normal` / `note_depth_deep`，类型 chip 固定 `quick_kind_scene` / `quick_kind_feeling` / `quick_kind_body` / `quick_kind_existing_action` / `quick_kind_interpretation` / `quick_kind_none`；
- 快速档只渲染正文、类型 chip 与保存条：类别、模板字段、标签、分类补充、关联关系与记录密级都不渲染，切回普通或深入后恢复显示；
- 草稿恢复面板只在存在未处理草稿时出现，占满内容区，两颗按钮固定 `note_draft_resume` / `note_draft_discard`；选「继续上次草稿」回填后进入表单，选「重新开始」得到空白表单；
- 最近标签在标签区内独占一行，每颗标签固定 `tag_recent_<标签文本>`，点击即加入本条标签，已在本条的标签不再列出；
- 状态、证据来源、密级、预测档位一律带文字标签，不允许只用颜色区分。

## 4.1 本轮新增的界面元素

| 位置 | 元素 | 说明 |
|---|---|---|
| 复盘 Agent | `RequestConfirmSheet` | 发送前清单，列出材料、密级与被排除项 |
| 速记编辑 | 材料三组 chip | 来源、文体、密级逐条记录；未点过的文体显示「未标注」；材料密级选项按记录密级过滤，不出现宽于记录的选项 |
| 速记编辑 | 三档深度 chip 与快速档类型 chip | 快速只留正文、类型与保存条；普通加类别、标签、分类补充与密级；深入再加解释、关联关系与预测入口 |
| 速记编辑 | 草稿恢复面板与最近标签行 | 未处理草稿时只渲染恢复面板的两颗按钮；最近标签取最近 8 个，点击即加入本条 |
| 速记详情 | 材料区 | 按类型、来源、文体、密级逐条展示；只有一条未分类材料且文本等于正文时整区不渲染 |
| 状态记录 | 不清楚 chip、承受判断 chip、功能/成本两栏 | 读数可缺项，判断由本人选择 |
| 状态面板 | 观察规则卡与设置面板 | 睡眠下限、报警次数、提示开关、恢复默认 |
| 计划列表 | 已暂停分区 | 显示暂停原因与恢复入口 |
| 关系详情 | 来源 chip、引用范围 chip、上下文开关 | 对方陈述默认仅本机 |
| 设置 | 导出清单三个开关、备份背景开关 | 默认均不纳入 |
| 页面背景 | 对比度读数与恢复默认纯色底 | 取黑白两端最低比值 |

## 5. 已知偏差

- 字面宽高共 202 处（`.width` 77 处、`.height` 125 处），分布在 190 行；两处固定尺寸已核对：`views/dashboard/ModuleGridCard.ets:38` 的 height 266、`views/NoteListView.ets` 的 bottom 80（速记列表给悬浮按钮留位）。`PageBackground` 的 `DARK_SCRIM`（18% 黑遮罩）与 `HomeQuickMenuPanel` 的 `SCRIM`（40% 黑遮罩）是叠加层不是语义色，保留字面量；热力图的四档色阶收在 `AppTheme.color.heatEmpty` 到 `heatHigh`，深浅两套各有取值；
- 页面背景使用按模块分组的本机图片；选择后先转 PNG，再选择单个页面组或全部应用，透明度 5%–40% 可调；启动时会迁移旧格式，设置页可手动“修复旧背景”；暂无预览裁剪和原图压缩。
- 浅色下 `page`（`background_primary`）与 `surface`（`comp_background_list_card`）都解析为白色，卡片与页面缺少底色差，只能靠间距与内容分组区分；深色下两者分别为黑与 10% 白，层次正常。
- 字号升到 12/14/16/18 后，`WelcomeCard` 的步骤列与底部隐私行在小屏上重叠（首屏说明卡），该组件不在本批授权范围，待后续调整。
- 已跟随系统深色（启动时读取语义令牌）；应用内手动主题切换未做。
- 模块网格与读数卡已改为主题令牌字符徽章，并补 `accessibilityText`；不再依赖 emoji 字体。

## 6. 阶段 7 目视清单

1. 首页：标题栏、读数、模块网格、待结算，窄屏不换行错位；
2. 速记：三档深度切换、草稿恢复两分支、最近标签点击、模板切换、正文/字段、关联关系 chips、材料三组 chip、详情材料区、保存返回；
3. 预测：新建表单、日期输入、到期/已结算详情、统计趋势与环图；
4. 复盘：六区切换（旧四步只读）、锚点勾选与选择理由、Agent 面板、历史与详情；
5. 关系：筛选、纠正摘录与待回应徽标、详情回应输入、关联记录跳转；
6. 状态：最近读数、七次汇总、历史；
7. 设置：三档 provider、Key 输入、预算记账、导出结果；
8. 全局：加载/空/失败三态、键盘遮挡、返回栈。

## 7. 变更流程

1. 先改 `AppTheme` 与本文档；
2. 再改组件与页面；
3. 至少跑 `assembleHap` 与 `PreviewBuild`；
4. 目视清单逐项打勾后才算完成。

## 8. 执行记录（2026-10-27）

- 构建级：`assembleHap` 通过（增量 8 s），`PreviewBuild` 通过（51 s）。
- 首次真机目视（模拟器 Mate 70 Pro）：首页、周结算、速记编辑、预测列表/统计、复盘/Agent、关系列表/星图、锚点、状态、设置/导出已逐页截图。
- 已修问题：
  1. 短内容滚动页默认垂直居中，导致速记、周结算、锚点、状态、复盘顶部大段空白；统一改为顶部对齐。
  2. 关系星图 `Path` 连线在真机偏移且只显示一条；改用 Canvas 绘制中心到节点的边。
  3. 锚点表列名 `order` 是 SQLite 保留字，真机 insert 失败；改为 `sort_order` 并迁移旧列。
  4. 预测列表空态仍写“创建入口稍后开放”；改为“点右上角「＋」创建一条”。
  5. 复盘表列名 `action` 也是保留字，完成复盘时 insert 失败；改为 `next_action` 并迁移旧列。
  6. 首页模块摘要只在首次构建时计算，保存速记/关系后仍显示 0；改为刷新时重算 `moduleItems`。
  7. 速记/预测/关系/复盘详情与历史页同样受 Scroll 居中影响，补顶部对齐。
- 联调注意：模拟器访问宿主机 Mock 需 `hdc rport tcp:4523 tcp:4523`，否则 127.0.0.1 指向模拟器自身。
- 已验证：速记列表/详情、预测列表/新建/详情、复盘保存/历史/详情、状态历史、导出文件（含复盘段）。
- 尚未目视：预测结算页（当前示例未到期）、设置保存后的跨页生效。
- 静态风险点：
  1. 首页新增周结算卡后，模块网格高度固定 266，需确认小屏滚动位置；
  2. MPChart 折线/环图已确认可渲染，长月份标签仍需真机确认；
  3. 关系星图固定 320×260，360vp 屏幕可容纳，更窄屏需确认；
  4. 设置页模型模式的地址/Key 输入需确认键盘遮挡；
  5. Agent 候选卡在长文本下的换行与按钮位置需确认。

## 2026-11 新增组件（冻结基线）

| 组件 / 区块 | 位置 | 用途 | 状态 |
|---|---|---|---|
| `MaterialPicker` | `components/MaterialPicker.ets` | 复盘第一区按类型分组选择可引用材料，显示来源、立场、人际来源与密级 | 已上线，真机未验 |
| 证据编辑器 | `components/ReviewForm.ets` 第四区 | 来源六选（实践/他人/身体/时间/书本/公开资料）、作用三选（支持/挑战/不清楚） | 已上线，真机未验 |
| 成本编辑器 | `components/ReviewForm.ets` 第五区 | 维度六选、说明、可承受开关 | 已上线，真机未验 |
| 决定多选 | `components/ReviewForm.ets` 第六区 | 最近 20 条决定多选，写入关联表 | 已上线，真机未验 |
| 引导面板 | `components/WelcomeCard.ets` | 五步方法说明 + 隐私句，整页形态但仍在看板滚动流内 | 半成品，待接入状态与覆盖层 |
| 待校正三行卡 | `pages/HomePage.ets` | 到期预测 / 待修订模型 / 已结束周节点，单项为零置灰 | 已上线，真机未验 |
| 删除撤销条 | `pages/NoteDetailPage.ets` | 删除后 5 秒内可撤销，超时清正文 | 已上线，真机未验 |

冻结规则不变：新增组件只服务材料阅读与校正，不用于装饰、不承载评分或成就；封存内容在任何组件中不得以正文形式出现。

## 9. 令牌迁移运行时验证（2026-11-17）

模拟器 Mate 70 Pro，HarmonyOS 7.0.0（26.0.0），API 26。

- `getColorSync` 传 `Resource` 对象返回 `0xFFFFFFFF`，因为 `$r('sys.color.*')` 返回的对象带的是应用自己的 `bundleName`，系统 id 查不到；改为 `getColorSync(color.id)` 后返回正确值（深色 `background_primary` 为 `0xFF000000`）。三处调用点统一走 `resolveColorHex`。
- 背景应用页的空上下文分支取固定占位文案「对比度待背景就绪后计算」，上下文就绪后显示结论；浅色读数 13.8:1 满足 4.5:1，深色 13.6:1 满足 5:1。
- 关系星图三条连线可见，`strokeStyle` 解析成功；关系信任徽章底色正常。
- 字号放大后固定尺寸未裁切：22vp 勾选框、徽章、`ModuleGridCard` 的 266、`StatusPage` 与 `PredictionStatsPage` 的 display 读数。
- 深浅两套截图已留（首页、设置、页面背景、关系列表与星图、状态、预测统计、速记编辑）。

## 10. 主分区外壳（2026-11-18）

底栏从「首页 + 五个跳转图标」改为五个常驻主分区；二级页仍压栈并覆盖底栏。全部新组件只使用现有令牌与 `SectionCard`，未新增页面级色值。

### 10.1 底栏

| 位置 | 名称 | 图标（系统 Symbol） | 页面背景分组 |
|---|---|---|---|
| 1 | 工作台 | `house` | home |
| 2 | 日志 | `calendar` | note |
| 3 | 预测 | `scope` | prediction |
| 4 | 抽屉 | `diagnostic_analytics` | home |
| 5 | 我的 | `person_2` | settings |

- `Tabs` 置于 `Navigation` 根内容内，`BarPosition.End` + `BarMode.Fixed` + `AnimationMode.NO_ANIMATION` + `animationDuration(0)` + `scrollable(false)`；页签切换为直接替换，无横向滑入；二级页压栈后底栏不可见。
- 自定义页签根组件宽高 100%，选中态取 `primary`，未选中取 `textMuted`，每个页签带 `accessibilityText`。
- 底栏高度 56vp、底色 `surface`；是否向手势区延伸留待真机目视后决定，当前沿用页面安全区。

### 10.2 工作台

- 顶部只有日期（`title`）与时刻（`bodyStrong`，每分钟刷新）以及一个 36vp 圆角入口（`tint` 底、`primary` 图标、圆角 `radius.lg`），不再有头像、昵称、签名、编辑与设置文字按钮。
- 入口打开自绘底部面板，高度取内容区 22%，只有「自定义顺序」「设置」两项；点遮罩收起。
- 六个区块固定为：快速速记、待处置、最近速记、模块状态、身体读数、复盘提示；时间区不参与排序。
- 排序态：面板「自定义顺序」进入，顶部出现「恢复默认」「完成」；排序分支才挂 `ForEach.onMove`，普通分支不挂，避免正文输入被长按误触。
- 区块顺序存 `Preferences`：`cogit_home_layout` / `block_order_v1`，损坏或为空时回退默认顺序。

### 10.3 其他分区

- 日志：`TabHeader` + 快捷录入条 + 速记列表（筛选、搜索、分页与四态空态），「＋」在标题栏。
- 预测：标题栏「＋」新建；摘要、筛选 chips、预测行、加载更多与数据看板在同一个 `List` 内，看板不再单独成页。
- 抽屉：读数（睡眠/运动/速记 + 命中率/待结算/待回应/开放节点，缺数据取「—」）+ 九个模块入口（计划、关系、价值锚点、状态、复盘、复盘历史、周结算、设置、页面背景）。
- 我的：身份卡（只读 + 编辑入口）+ 身份编辑、设置、页面背景三个入口。

### 10.4 看板折叠

- `ChartSection` 新增 `collapsible`（默认 false）与 `initiallyExpanded`（默认 false）；折叠时只显示标题、图表与「说明」，展开后追加说明、判定与口径。
- 空态与演示标识不受折叠影响，始终可见。

### 10.5 新增组件

| 组件 / 视图 | 位置 | 用途 |
|---|---|---|
| `WorkbenchShell` | `pages/WorkbenchShell.ets` | 五分区 `Tabs` 壳、常驻底栏与分区背景 |
| `WorkbenchView` | `views/WorkbenchView.ets` | 时间头、区块列表、排序态与快捷面板宿主 |
| `LogsView` / `DrawerView` / `MineView` | `views/` | 日志、抽屉、我的三个分区 |
| `PredictionTabView` / `PredictionLogView` | `views/` | 预测分区与内嵌看板的单一滚动流 |
| `AnalyticsView` | `views/AnalyticsView.ets` | 看板内容主体，自身不滚动 |
| `NoteListView` | `views/NoteListView.ets` | 速记列表主体，页面与日志分区共用 |
| `IdentityCard` | `components/IdentityCard.ets` | 身份卡，替换旧 `ProfileHeader` |
| `QuickCaptureBar` | `components/QuickCaptureBar.ets` | 单行速记与保存，工作台与日志共用 |
| `HomeQuickMenuPanel` | `components/HomeQuickMenuPanel.ets` | 右上角面板与遮罩 |
| `TabHeader` | `components/TabHeader.ets` | 分区标题栏与右侧动作槽 |
