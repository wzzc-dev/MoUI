# Plan: MoUI Studio 能力升级——向成熟 IDE 靠拢的八切片改造

- **Status**: active
- **Goal**: 依据 2026-10-02 的差距分析（`artifacts/studio-gap-analysis.md` + 本轮复检），把 MoUI Studio 从「可视化 DSL 教学 IDE」升级为具备成熟 IDE 四根支柱的工具：真代码编辑器、运行时检查器、诊断面板、项目卫生（键盘/无障碍/确认/进程管理），并扩展语言与控件域（用户自定义函数、数组、整数、属性 schema、新控件与新事件）。
- **Non-goals**: 多窗体、移动端、RTL、真实网络外发（沿用 v1 冻结）；引入通用 LSP 客户端框架（切片 H 用 in-app 情报 + 工具链挂钩替代）。

## 切片与验收

| # | 切片 | 内容 | 验收 |
|---|---|---|---|
| A | 真编辑器 | 接入 `wzzc-dev/moui_richtext`(+`code_editor`)：`controlled_rich_text_editor` 取代只读行渲染 + `text_area` 草稿框；DSL token→`RichTextRun` 着色；`input_transform` 自动缩进；IR 竖尺与滚动同步保留 | Code 视图可点击定位光标、选区、撤销/重做、自动缩进；行号尺随滚动同步；`moon test examples/moui_studio/app --target native` 全绿 |
| B | 诊断面板 | `check_syntax` 实时结构化诊断（range 化）+ 行内标记 + 行号尺错误点 + 底部 Problems 面板（bottom Bool→枚举）；`moon check` 编译诊断并入同一面板 | 编辑即见行内错误与 Problems 计数；编译诊断可点击跳转 |
| C | 运行时检查器 | `moui_devtools` 接入：平台入口注入 `() -> String` 快照回调（app 不 import runtime，守住依赖边界）；右栏新增 Runtime tab：summary + 分节报告 + 有界历史 | 两个入口编译通过；native 可刷新真实快照；web 优雅降级提示 |
| D | 卫生 | 键盘绑定表扩充（保存/打开/运行/模式切换/面板开关等）；交互面 a11y 标注补齐；破坏性操作（删控件/删变量/模板覆盖/打开覆盖）确认对话框；编译「停止」真正终止 moon 进程（保留子进程句柄 + cancel） | 快捷键实测生效；删除必经确认；停止后 moon 进程消失（进程表证据） |
| E | 积木系统 | 类别化形状（事件帽形/条件六角/变量圆角/命令矩形/流程 C 形）、插入标记与拖放反馈打磨；为 F 的新语句类补积木 | 积木画布按类别呈现不同形状；新语句有积木与骨架 |
| F | 语言层 | 用户自定义函数（带参、返回值、调用深度预算）、数组（字面量、索引读写、长度/追加内建）、整数类型（整数字面量、整除、混合提升）——parser/printer/interp/codegen/compiled_runtime/blocks/codec/signature/invariants 全链路 + `sync_kernel` + 差分门 | 双语往返门、差分矩阵、codec 快照全绿；三构造均有测试 |
| G | 属性 schema | 控件属性 schema 化（`PropertySpec` 注册表 + 类型化存取）；新控件：下拉框/进度条/图片；新事件：完成输入/定时器（虚拟时钟，随运行步进）/广播消息（发送内建 + 接收处理器） | schema 驱动属性面板；三种控件可设计可运行；三个事件可触发 |
| H | MoonBit 情报 | 编辑器内补全（关键字/内建/变量/控件名）、悬停、标识符→IR 定义跳转（结构化等价于「跳转定义」）；评估 native-only `moon ide` 挂钩 | Ctrl+Space 补全可用；点击标识符跳到声明语句 |

## 依赖与顺序

A → B（行内标记依赖真编辑器）；C、D 独立；F → E（新语句类需要积木）、G 依赖 F 的语言底座；H 依赖 A。

## 边界与约束

- app 包不新增 `wzzc-dev/moui/runtime` 依赖（C 用字符串回调注入）；`moui_richtext`/`moui_devtools`/`moui_agent` 为模块级依赖。
- 不新增 core view enum 变体；新内置控件须为 `@core.ViewNode` 具体实现（若 G 需要）。
- 语言层改动必须同步三份执行语义（interp / moonbit_codegen / compiled_runtime.lower）+ kernel 副本（`tools/sync_kernel`）+ 差分门，缺一即 P0。
- i18n 新键必须走 `app/i18n/{zh-Hans,en}.json` + `scripts/generate-i18n-catalogs.mjs --check`。

## Acceptance

- [x] 切片 A：真编辑器落地（richtext 受控编辑器 + DSL 着色 + 缩进 + 滚动同步）
- [x] 切片 B：诊断面板 + 行内标记（实时校验/行号红点/run 底色/问题页签/跳转）
- [x] 切片 C：运行时检查器（devtools 快照注入 + Runtime 页签 + 有界历史）
- [x] 切片 D：键盘/无障碍/确认/进程终止（with_commands 全局表/确认卡/真杀进程）
- [x] 切片 F：整数/数组/用户自定义函数（IntLit/VInt、VArr/索引/内建、FuncDef/Return/帧隔离，双轨差分一致）
- [x] 切片 E：积木形状（变量胶囊/条件徽标/返回箭头）
- [x] 切片 G：下拉框/进度条/图片 + 完成输入/定时器(虚拟时钟)/广播消息 + items 载荷 schema + 窗体级处理器创作
- [x] 切片 H：Ctrl+Space 补全 + 跳转声明（DSL 自身即语言服务器）
- [x] 全量：studio 模块 4526/4526 测试绿；静态六件套全过；`docs/moui-studio.md` 已同步

## 遗留与后续

- 用户自定义函数的**创作 UI**（树分组/编辑面）未做——语言层、codec、两轨执行
  与测试已就绪，函数目前只能经程序 JSON 引入。
- 编辑器内补全以底部胶囊行呈现（未做光标处弹出层）；悬停文档待框架
  tooltip 视觉覆盖落地后接入。
- 进度条/图片的 items 载荷语义是属性 schema 的数据面；通用 schema 驱动的
  属性面板重构（PropertySpec 注册表）留待下一轮。

## Progress

| Date | Note |
|------|------|
| 2026-10-02 | 计划创建；资产勘察完成（richtext/devtools/studio 域三份报告） |
| 2026-10-02 | 切片 A 完成：`controlled_rich_text_editor` 取代只读行渲染 + 草稿框；DSL token run 着色（ranged tokenizer）；换行 DSL 缩进（关键字分类驱动）；行号槽/编辑面/竖尺滚动同步（`EditorScrolled` 单向汇聚）；悬停与驻留高亮在竖尺上可区分（新增 `ide_ir_hover`）；196/196 |
| 2026-10-02 | 切片 B 完成：编辑即校验（`with_draft_diagnostics`）；行号槽红点 + 行内 run 淡红底；底栏 `bottom_audit: Bool` → `BottomTab` 枚举，新增问题页签（`problem_rows` 逐 handler 归因 + 草稿实时诊断 + 全程序语言校验，`GotoProblem` 跳转）；201/201 |
| 2026-10-02 | 切片 C 完成：`moui_devtools` 接入（app 只见格式化文本，runtime 类型止步组合根）；右栏第六页签 Runtime（summary + 分节报告 + 有界去重历史）；native/web 双入口注入；`runtime_refresh_attached` 只在开页签/显式刷新时采样；204/204 前夜（199+测试增量） |
| 2026-10-02 | 切片 D 完成：编译「停止」改真终止（`CompileOwner.active` 登记句柄 + `compile_cancel`；run_tool 改 spawn+双管道，shared 管道双接 stdout/stderr 会死锁——已用最小复现排除）；确认对话框（DeleteControl/DeleteVariable/模板/新建/打开 覆盖守卫，`update_confirm_msgs` 挂链首 + `update_pure_inner` 同步续行；open 走一次性放行标记）；全局键盘命令表（`with_commands`：S/O/E/Enter/1/2/J/D，meta+control 双注册）；a11y 标注（底栏页签/右栏页签/问题行/胶囊）。app 201/201 |

| 2026-10-02 | 「点击运行没反应」排查：消息探针 + 真实 CGEvent 系统级点击端到端验证——当前构建的运行链路（物理点击→AppKit→RunStart→订阅→RunTick→视图切换）完全正常。顺带修复三个真问题：(1) wrapper fallback 丢弃 update_pure 的 effect（CkOpen 确认续行的 dispatch 被吞）；(2) run_handler/start_run 事件派发未传 `functions=`（含用户函数的程序在解释轨必然 UnknownBuiltin）；(3) 清理全部 lint 告警后 macos_skia 闭包 0 告警。若用户仍复现，需确认其重建了二进制（旧二进制含 effect-drop bug） |

| 2026-10-02 | UI 打磨轮（用户反馈四项）：① 左侧活动栏 VS Code 化——去分隔线、统一 40px 节奏、选中项左缘 3px 强调条纹、设置钉底；② toast 自动消失——ToastEntry 携带存活秒数，1s ToastTick 老化订阅（与运行订阅 Subscription::batch 合并），满 4s 自动消失；③ 顶栏撤销/重做/命令面板图标与芯片垂直对齐——快捷键从按钮壳（stack 顶对齐导致偏上）迁移到全局命令表，按钮恢复 icon_button；④ 移除顶栏「中/EN」切换（设置面板已有完整双语切换），宽度预算同步（-34，gap 7→6）。回归 4528/4528 全绿 |

| 2026-10-02 | UI 打磨第二轮（对照 VS Code 截图）：活动栏图标整体缩小（按钮 40→32、图标 18→15，语义树验证 6 项 40px 节奏 + 设置钉底 y≈719）、底栏页签组与状态栏内容右对齐（VS Code 状态栏口径）。回归 4528/4528 全绿 |

| 2026-10-02 | UI 打磨第三轮（VS Code 骨架定稿）：活动栏改为**全高贯通**（从窗口顶到状态栏上沿，图标条纹移除、设置钉底），状态栏横贯底边（左组终端/分支 + 右组编码/语言/诊断/空闲），底栏页签回到左对齐。壳层重构（body 行 = [活动栏, 右列(顶栏+内容+底栏面板)]）暴露一个布局引擎语义坑并修复：**嵌套 column 内 `width~` 容器不按父列 frame 解析，而是逃逸到外层定宽祖先**（内容容器实测 1280 宽，其 1232 宽子行被居中 → 全体内容 +24px 水平偏移，8 个布局回归齐炸）；修法是给这类容器**显式宽度**。同轮清理：删除 6 个布局调试探针测试与死函数 `rail_item`、红色探针容器。回归 4528/4528 全绿；真机截图逐条核对 VS Code 骨架六项通过 |

| 2026-10-02 | UI 打磨第四轮（用户三点修正）：① 壳层再重构——**右栏全高**（顶栏之下直抵状态栏），底栏面板只延伸到右栏左缘（`workspace_row` 只铺左+中，右栏段上移到壳层 `lower_row`；新增 `shell_main_width` 统一主列宽口径）；② 底栏收起/展开按钮移到页签行**最右端**（页签 + weight spacer + 按钮，右缘即右栏左缘，VS Code 面板口径）；③ 状态栏 `status_cells` 增加 `right_align` 参数——左组**贴左**、右组贴右（上一轮误把两组都靠右）；④ 活动栏设置按钮 32→24 高，图标下缘距状态栏 ~4px（贴底边框）。回归 4528/4528 全绿，真机截图三点逐条核对通过 |

| 2026-10-02 | UI 打磨第五轮（VS Code 骨架终稿）：状态栏移入右列——**活动栏通到窗口最底边**（状态栏不再从它下方穿过，设置图标随之贴住窗口底边、与状态栏同行）；**状态栏从活动栏右缘铺到窗口右缘**（宽度口径 `side_width`），其上发丝线同样止于活动栏右缘。回归 4528/4528 全绿，真机截图两处逐条核对通过 |

| 2026-10-02 | UI 打磨第六轮（VS Code 骨架收口）：① **左栏也全高**（顶栏之下直抵状态栏），底栏面板只铺**中心列**——左缘 = 左栏右缘、右缘 = 右栏左缘；`workspace_row` 退役为中心列装配 `center_workspace`（避让带/stack 叠放逻辑原样迁入）。② **活动栏减半**：`ICONBAR_WIDTH` 48→24，按钮 32→16、图标 15→10（测试全部走符号常量，自动跟随）。③ 顺手修一个真缺陷：`blocks_item_rects` 预算下限 `.max(160)` 在窄画布上超过可用宽（1100 窗口实测画布 155、块体 160），块文字越出裁剪区 5px——下限改为「可用宽的一半、至多 160、兜底 80」，不再越过画布。回归 4529/4529 全绿，真机截图逐条核对通过 |

| 2026-10-02 | 活动栏尺寸两连调（用户对照 VS Code 截图）：先按「槽位=栏宽」的 VS Code 比例在减半口径下重排（槽 24/字形 12），用户随后拍板**完整 VS Code 尺寸**——`ICONBAR_WIDTH` 48、按钮 32×32、字形 15（减半前形态），设置图标保持 22×22 钉底。回归 4528/4528 全绿 |

| 2026-10-02 | 活动栏「协调度」修正（用户对比 VS Code 追问根因）：`icon_button` 选中态从**蓝底蓝字**（`ide_selection`+`ide_accent`，多个常开开关导致蓝块连排）改为 VS Code 口径——**深灰微高亮底（`ide_hover`）+ 白色字形（`ide_text`）**，未选中保持灰字形视觉透明，圆角 6→4。回归 4528/4528 全绿 |

| 2026-10-02 | 活动栏底部设置入口协调度修正（用户追问根因）：① 尺寸节奏——设置按钮曾按状态栏口径缩到 22×22，与其余栏按钮（32×32）失谐，恢复同规格；② 字形本体——框架图标集只有「滑杆式」Settings（小尺寸下读作两道杠，像杂讯），**框架新增 `Gear` 图标变体**（8 齿直线齿廓 + 中心圆，24×24 描边路径，icon_path/icon_label 全量登记），Studio 设置入口改用 Gear——与 VS Code 的齿轮同构。回归 4528/4528 全绿 |
