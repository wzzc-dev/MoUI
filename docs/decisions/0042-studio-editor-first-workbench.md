# ADR 0042: MoUI Studio 编辑器优先工作台——workbench 独立包与窄扩展点

- **Date**: 2026-10-24
- **Status**: Accepted（M0–M6 全部落地；workbench/app/kernel 三包测试双目标全绿，四项预算棘轮到实测值）
- **Deciders**: Agent-assisted（编辑器优先 IDE 升级轮）
- **Related**: [ADR 0038](0038-studio-plugin-kernel.md)、
  [ADR 0039](0039-studio-shell-completion-line.md)、
  [ADR 0040](0040-studio-shell-completion-stages.md)、
  [ADR 0041](0041-studio-shell-variant-structural-floor.md)、
  `docs/plans/active/moui-studio-shell-completion.md`、
  `tools/moui/validate_maintenance_baseline/studio_shell_budgets.mbt`

## Context

Studio 的五种中心形态（可视化 / 设计 / 积木 / 代码 / 预览）此前是壳里的硬编码
分支：`workspace_content` 按 perspective 与 workspace 两层 switch 决定渲染哪个
全幅面板。三个结构性问题随之而来：

1. **文档态没有统一所有者**。打开的 `.mbt` / `.md` 文件的草稿、光标、脏标记
   散落在 `ProjectState` 与壳字段之间，资源管理器、标签条、编辑器各自持有一份
   可写副本，靠消息同步。
2. **窗格布局态是壳私有**。live pane / blocks pane / 分割比三个字段直接躺在
   `Model` 上，设计工作台与组合工作区各自拼装中心形态，复用靠约定。
3. **面板与命令是两份手抄表**。底栏页签头（选中态/徽标/正文）与命令面板
   （40 条 `StudioCommand`）各写各的，`run_studio_command` 是一个 90 行的
   switch——表与处理器靠纪律成对出现（M4 之前模板四件套就曾是有处理器没
   入口的死命令）。

产品诉求：把 Studio 升级成**编辑器优先**的 IDE——编辑区是主面，各模式成为
编辑器 provider / 插件（对标 VS Code / IntelliJ / Zed 的骨架，不照搬其运行时
插件机制）。选定方向 A + workbench 独立包 + 窄扩展点（Document /
EditorProvider / Panel / Command），按 M0–M6 六个里程碑落地。

## Decision

1. **新建 `moui_studio/workbench` 包**（只依赖 moui core/views 与 chrome，
   不依赖 app/plugins/domain），持有四样东西：
   - `DocumentStore`：文档条目（常驻 Studio 文档 + 可关闭文件文档）、
     `TextBuffer`（草稿/已存/光标/选区/md 会话）、脏标记、按 id 的
     激活/编辑/关闭/改名收敛。文档是唯一事实源，explorer 与标签条只拿
     只读投影。
   - `WorkbenchState`：窗格布局（live / blocks 开合、分割比及其 clamp）。
   - `EditorProvider[Ctx, Msg]` + `resolve_provider`：id / priority / accepts /
     render；解析顺序 = preferred 命中 → 最高优先级 → 同优先级先注册者。
   - `editor_area` 视图：标签条 + provider 渲染体；以及两个贡献点类型
     `PanelContribution`（id / location / label_key / badge / selected /
     on_select / render）与 `CommandContribution`（id / label_key / group_key /
     run → Apply | Dispatch | Unavailable）+ `panels_at` / `selected_panel` /
     `find_command` 查询器。

2. **app 是组合根与策略层**：provider 表、面板表、命令表在 app 静态装配
   （MoonBit 无反射/动态加载，与 ADR 0038 的静态装配同一口径）。中心统一走
   `editor_area(model.workbench, ctx, editor_providers(), preferred, …)`；
   底栏页签头与正文由面板表派生（M4 先只做底栏——左/右栏全量注册会越过
   行数棘轮，左/右栏维持硬编码分支，见 Consequences）；命令面板描述符由
   命令表派生（`label_key == ""` = 不进面板的内部命令），`run_studio_command`
   收缩为查表执行：Apply 走纯更新、Dispatch 走效果派发回服务环。

3. **删除内核死贡献类型**。`kernel/contributions.mbt` 的
   `PanelView` / `ActivityItem` / `BottomTab` / `CommandContribution` /
   `Perspective` 与 `plugin.mbt` 的 `PluginDescriptor` 自 M0 以来没有任何
   插件或壳消费（workbench 类型才是真实扩展面），整体删除；kernel 保留
   事件总线 / 服务容器 / PTY / provider 契约。`kernel/plugin.mbt` 的插件
   契约文档改为指向 workbench 贡献点。

4. **文档/窗格消息并入 `WorkbenchMsg`**：壳持单一 `WorkbenchOp(@wb.WorkbenchMsg)`
   委托臂，窗格与文档的纯态臂（激活/编辑/关闭/光标/md 事务/窗格开合/分割比）
   迁入 workbench update；服务臂（读盘回执、保存落盘）与跨域臂留壳。

## Consequences

- **预算（棘轮到实测，见 `studio_shell_budgets.mbt` 审计记录）**：
  app 源码 27,750 → **27,374** 行（39 文件不变）、Model 字段 113 → **111**、
  Msg 变体 242 → **238**；`line_budget_catalog.mbt` 同步结算 app.mbt /
  app_test.mbt 单文件上限。
- **表与处理器不再可能漂移**：命令 id 不在表里就是未知命令（no-op），
  面板可见性与执行通道共用同一份定义。
- **M4 的部分完成**：面板贡献表只覆盖底栏。左/右栏注册表的行数代价
  （~110 行）会顶破当时棘轮，按计划回退为硬编码分支；后续左/右栏页块
  迁移到注册表时行数预算需先有下降空间。
- **markdown 插件缺席自动降级**：`.md` 文档由 provider 解析回退 mono
  编辑面（`file.mono` provider 认领），不丢文档不丢草稿。
- **kernel 公共面收窄**：删除 6 个从未被消费的贡献类型，插件契约文档
  与测试同步收敛（kernel 测试 11 → 10）。
- **测试**：workbench 11 单测（store/provider/layout/panel/command）；
  app 新增 `panel_registry_wbtest.mbt`（底栏五页签/徽标/终端开合语义/
  插件缺席）与 `command_registry_wbtest.mbt`（43 id 全覆盖、面板 40 条
  顺序与文案、隐藏命令不进面板但可派发、代表命令状态转移）；app 460 /
  workbench 11 / kernel 10 双目标全绿。

## Verification

- `moon test moui_studio/workbench --target native|wasm-gc`
- `moon test moui_studio/app --target native|wasm-gc`
- `moon test moui_studio/kernel --target native`
- `node scripts/validate-maintenance-baseline.mjs`（四项棘轮生效）
- macOS 真机首帧冒烟：`MOUI_FIRST_FRAME_EXIT=1 moon run moui_studio/macos_skia --target native`
