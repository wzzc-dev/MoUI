///|
/// Studio 壳收敛预算(ADR 0039):app 包 = 壳 + 组合根,四项只降不升。
///
/// 口径:`moui_studio/app` 下的 .mbt 源文件,排除 `*_test.mbt`、
/// `*wbtest.mbt`、`i18n_catalog_generated.mbt`(测试与生成物不占源码预算)。
/// Model 字段 = `pub(all) struct Model` 块内的字段行(含 `mut` 字段);
/// Msg 变体 = `pub(all) enum Msg` 块内的变体声明行(载荷可跨行,只数声明行)。
///
/// 预算只降不升:上调必须改下表并写 reason(即审计记录,见 ADR 0039 与
/// docs/plans/active/moui-studio-shell-completion.md)。
///
/// 注:上表的 `max_count` 始终绑定**当前实测值**(每次提取完成即降),它与
/// ADR 0040 的完成线分档是两件事——分档是目标,棘轮是上限,不混用。

///|
fn studio_shell_budgets() -> Array[CountBudget] {
  [
    {
      kind: "studio shell lines",
      label: "moui_studio/app",
      path: "moui_studio/app",
      // 基线冻结(2026-10-12 实测 37,279;ADR 0039 完成线 ≤ 18,000)。
      // S1 chrome 出壳(2026-10-12):theme.mbt(606)+ ide_chrome 共享原子
      // (~910,含 fit_label)迁出 moui_studio/chrome → 35,721。
      // S2a 工程域出壳(2026-10-12):行模型/纯工具/工程类型迁
      // plugins/project(壳留包装),app 35,721 → 35,034。
      // S2b-1 状态切片(2026-10-12):17 字段并入 ProjectState → 35,251;S2b-2 子消息臂迁出 → 34865
      // 壳卫生清理(2026-10-12):删 2 个切片后遗留的未用包装
      // (section_collapsed / collapse_all_tree_keys) → 33,535。
      // S5 blocks 捆绑出壳(2026-10-12):blocks_slot_hit 全文 + blocks_canvas 的
      // 15 个纯几何函数 + BlocksDrawOp + BlocksDragState + 2 常量 + row_arrow
      // 迁 plugins/blocks(1,054 行);壳侧 blocks_pane.mbt 收画布视图函数
      // → 32,481。
      // 右栏 VS Code 侧栏分页(2026-10-13):检查器页与 AI 页分开,新增页块
      // 切换器 / 对象条 / 圆角输入卡;同时把子页签条、对象条、页切换头三个
      // **通用**原子搬进 chrome(无预算)——净 32,481 → 32,341。
      // 同日真机复查三轮修了四个缺陷(转录宽与裁剪区不同源导致文字被切、
      // diff 长行不截断、卡标题不吃徽标宽、恢复会话残留 in-flight 卡) →
      // 32,341 → 32,421;仍在 S5 之后的下降通道内,低于本轮起点 32,480。
      // S6a 设计域开包(2026-10-13):canvas.mbt 的纯几何/绘制计划(命中/
      // 吸附/底板/覆盖层/手柄半径)+ StageLayout 节点 + fit_scale +
      // 泛型化 design_stage 视图(回调 on_tap/on_drag、底色注入)迁
      // plugins/design(945 行);壳侧删 canvas.mbt、stage_layout.mbt,
      // 仅留一个 design_stage 薄壳包装(手势→Canvas* Msg) → 31,489。
      // S5c 语句面板整文件出壳(2026-10-13):statement_palette.mbt(480 行,
      // StatementTemplate/ExpressionTemplate 模板数据 + 分类查询,纯数据零
      // Model/Msg)整文件迁 plugins/blocks;域内 @blocks.→@blk.、
      // text(t,..)→t.translate(..),壳调用点重限定 @blk. → 31,009。
      // S6c 布局设计器画布出壳(2026-10-13):form_design_canvas 的命中/手柄/
      // 尺寸纯几何 + 拖拽提交判定 + 自绘视图迁 plugins/design(视图 [Msg]
      // 泛型、FormModel 入参、noop/on_select/on_drag/on_resize 回调,新依赖
      // services/form_designer);壳删文件,form_design_session 收两个薄壳包装
      // → 30,790。
      // S7 code 域开包(2026-10-13):code_intel.mbt 的补全/跳转声明 + 纯
      // split_line_texts 迁 plugins/code(新建,依赖 domain/ir + studio_lang);
      // completions_for/declaration_line_of 参数化(语言/控件/草稿显式传入,
      // 不再读 app Model),壳仅 update_shell 调用点重限定 → 30,636。
      // S7b 代码工程生成器出壳(2026-10-13):code_project.mbt 的纯生成链
      // (双腿 code_project_files/text、code_project_target、行级 diff、
      // .studio.json 迁移器、dirname)迁 plugins/project(新依赖 domain/codec +
      // services/export + services/form_designer,ProjectRecord 归本地);
      // 仅 code_project_write_effect 壳侧写盘编排(Effect[Msg])并入
      // new_project.mbt,6 个纯逻辑单测随迁插件 → 30,463。
      // S4 AI 会话列表出壳(2026-10-13):ai_sessions_pane.mbt 的整列自绘视图
      // (表头/搜索行/分组/项目组/行 + 行高常量 + relative_time_bucket)泛型化
      // 为 [Msg] 纯视图迁 plugins/ai(AiSessionListParams 显式注入 11 个 on_*
      // 回调 + 状态),text(t,..)→t.translate(..);壳删文件,ide_shell 收一个
      // 投影薄壳包装,ide_ai 行高常量重限定 @ai. → 29,996。
      // S4c AI 工作区面板出壳(2026-10-13):ai_workspace_panel.mbt(371 行,
      // 双页签「更改/文件」+ 提案历史 + 待采纳卡)泛型化 [Msg] 迁
      // plugins/ai(AiWorkspaceParams 注入 show_changes/history/pending/
      // 四个 on_* 动作;工程树作为 files_view 插槽由壳构建注入);壳删文件,
      // ide_root 收一个投影薄壳包装 → 29,662。
      // S7d 编译轨视图出壳(2026-10-13):views_compile.mbt(642 行,真编译
      // 动作条/报告卡/进度卡/产物旁路/诊断行 + 中间省略 + 进度归并纯函数)
      // 泛型化 [Msg] 迁 plugins/run(CompileViewsParams 注入 compile_* 状态
      // 与 on_* 动作;产物幽灵按钮经 ghost_icon 回调由壳注入,新依赖
      // services/export + views/style);compile_step_state/progress_counts/
      // active_phase 三个纯函数随迁,5 个纯逻辑白盒单测随迁;壳删文件,
      // update_run 收一个 compiled_run_header 投影薄壳包装 → 29,011。
      // S4b AI 浮动层视图族出壳(2026-10-13):ide_ai.mbt(1544 行,中心/
      // 右栏 AI 页 + 转录时间线 + 工作卡归组 + 输入条 + 决策条 + 上下文芯片)
      // 与 markdown_view.mbt(markdown 渲染)泛型化 [Msg] 迁 plugins/ai
      //(AiViewParams 注入 20+ AI 域状态/跨域读数与 on_* 回调,幽灵按钮经
      // ghost_icon 回调由壳注入,ComposerMode/PendingProposal 移插件,新依赖
      // geometry/graphics/services/markdown/plugins/code);壳删两文件,
      // 新建 ide_ai_views.mbt 投影薄壳(参数构造 + 常量/高度/has_decision
      // 转发) → 27,476 / 39 文件。
      // S4d AI 域 UI 状态切片(2026-10-13):composer/provider/转录受控滚动/
      // 左栏会话列表搜索悬停改名/对话框开合/工作卡折叠 17 个纯 UI 字段并入
      // plugins/ai 的 AiUiState(壳持单一 ai_ui 字段,RightPanelTab 移插件),
      // 16 个纯态臂并入 AiUiMsg(壳持单一 AiUiOp 委托臂,Feature::scope 挂载);
      // 改名 Start/Commit 与生成/采纳/存储等跨域或服务臂按契约留壳。
      // update_ai 纯态臂随迁 → 27,319 / 39 文件。
      // S5e 积木域 UI 状态切片(2026-10-13,ADR 0041):7 个纯 UI 字段(语句面板
      // 开合/分类、画布滚动、值编辑草稿、语句/表达式拖放骨架、右键菜单锚点)
      // 并入 plugins/blocks 的 BlocksUiState(壳持单一 blocks_ui 字段),9 个
      // 纯态臂并入 BlocksUiMsg(壳持单一 BlocksUiOp 委托臂,Feature::scope
      // 挂载);画布手势/值提交/落拖/打开菜单等读 program 或提交 IR 的臂按
      // 契约留壳,经组合根直接读写切片嵌套字段 → 27,269 / 39 文件。
      // S5f 工程域 UI 状态切片(2026-10-13,ADR 0041):4 个纯 UI 字段(结构树
      // 搜索查询/分组折叠集/「新建」菜单分组/全文搜索草稿)并入 plugins/project
      // 的 ProjectState,11 个纯态臂(tab 切换/关闭、文件 CRUD 输入态、结构树
      // 搜索/折叠/新建菜单、搜索草稿)并入 ProjectMsg(复用既有 ProjectOp,0 新
      // 委托);SelectProjectFile/At/SearchHitClicked 读盘/开文件的服务臂与
      // 提交/回执留壳。close_open_file 纯态随迁插件,8 个白盒单测随包
      // → 27,120 / 39 文件。
      // S5g 代码编辑器 UI 状态切片(2026-10-13,ADR 0041):受控编辑面的光标/
      // 选区/滚动 + 补全弹层(候选词/开关)5 个字段并入 plugins/code 的
      // CodeUiState(壳持单一 code_ui 字段),3 个纯态臂(光标/选区回传、受控
      // 滚动、补全弹层关闭)并入 CodeUiMsg(壳持单一 CodeUiOp 委托臂,净 −2);
      // 编辑代码/采纳补全/触发补全/跳转声明(读 code_draft/program)与 IR
      // 高亮/悬停(跨域)留壳,经切片 SetCompletions/ApplyCompletion/GoToLine
      // 内部消息回写 UI 态,6 个白盒单测随包 → 27,106 / 39 文件。
      // S5h AI 会话 composer 草稿切片(2026-10-13,ADR 0041):SetPrompt 写
      // 当前会话 prompt_draft,并入既有 AiSessionMsg(SetPromptDraft,复用
      // AiSessionOp 委托,壳在委托后清跨域 prompt_error);S4d 已把改名放弃
      // 迁 ClearRename、遗留的死枚举 AiSessionRenameDismiss 一并删除(净 −2)。
      // EditUserPrompt/RetryUserPrompt 读时间线卡片回填(内容耦合)留壳,
      // 1 个白盒单测随包 → 27,101 / 39 文件。
      // S5i 运行域 UI 切片(2026-10-13,ADR 0041):编译输出展开 + 预览 Frame/Web
      // 2 个纯态臂并入 plugins/run 的 RunUiMsg(壳持单一 RunUiOp,净 −1),
      // 2 字段(compile_output_open/preview_mode)并入 RunUiState(预览档位在
      // 插件存 web_preview 布尔,壳保留 PreviewMode 枚举并经 Model::preview_mode
      // 边界换转);PreviewNavigate/PreviewReload 与 TabClose(kill PTY)等
      // 服务/Effect 编排留壳。终端手动滚动 TerminalScrolled 为无承接死消息
      //(scroll_view 自管手动位置,受控 offset 仅 PTY 输出自动跟随)已删(−1)。
      // design_zoom 仅 1 个标量且在画布视图密集读取、独立切片净增 0 变体,
      // 实测留壳。另去重 same_path→@blk.blocks_same_path、删死 clone_path
      // 抵消切片样板,行数持平 27,101 / 39 文件,3 个白盒单测随包。
      // S7c 代码视图纯函数下沉(2026-10-13,ADR 0041):空关键字表工厂(全 NUL
      // 的 Keywords)移入 domain/studio_lang 的 Keywords::empty();DSL 换行缩进
      // dsl_indent_for_newline 改按 Language 纯文本化后移入 plugins/code
      //(code_indent.mbt,壳仅传 model.language.dsl_language());mono 字体与
      // tab 标签两纯函数移入 plugins/code(code_view_helpers.mbt,新增 moui/text
      // 依赖)。富文本输入变换 code_newline_transform 因依赖 moui_richtext
      // 视图输入层、避免向状态插件引入渲染依赖而留壳;CodeTokenKind/token 配色
      // 是壳模型类型与 chrome 主题映射,留壳。净降 101 行 → 27,000 / 39 文件。
      // 骨架生成面出壳(2026-10-14):新建工程骨架的落盘计划(模块名归一 +
      // 文件集 + IR 快照常量)、目录守卫与 mkdir、模板下标映射迁
      // services/scaffold;布局探测 is_studio_app_bundle 迁 plugins/project
      // (与 code_project_target 同域);计划→工程身份合成迁 services/project
      // (project_source_from_plan)、删空壳包装 app.empty_program
      // → 26,819 / 39 文件。
      // P4b 写盘事务(2026-10-14):写盘队列加删除相(NewProjectQueueResult
      // 复用同一游标,中断回滚已写前缀)+30;同批清掉 5 个零调用者的遗留
      // 包装(other_language_label / center_width_of / tree_group_has_children
      // / block_category_first / clamp_bottom_height,-42) → 26,807 / 39 文件。
      // 调色板拖拽换算(2026-10-16):update_blocks 增视口→链换算
      // (palette_pointer_to_chain / update_palette_drag_pointer /
      // update_palette_drop_at / palette_expression_drop_at)+blocks_pane
      // 的行手势相位映射;SHELLDBG 调试残留同步移除(负抵扣)→ 27,750。
      max_count: 27750,
    },
    {
      kind: "studio shell files",
      label: "moui_studio/app",
      path: "moui_studio/app",
      // 基线冻结(2026-10-12 实测 53;完成线 ≤ 30)。
      // S1 chrome 出壳:theme.mbt 整文件迁出 → 52。
      // 壳卫生清理(2026-10-12):仅删函数不动文件 → 51。
      // S5 blocks 捆绑出壳(2026-10-12):blocks_canvas.mbt(视图函数并入
      // blocks_pane.mbt)与 blocks_slot_hit.mbt(整文件迁插件)两个文件消失 → 49。
      // S6a 设计域开包(2026-10-13):canvas.mbt、stage_layout.mbt 两个文件
      // 整体迁 plugins/design(design_stage 薄壳包装并入 workspace.mbt) → 47。
      // S5c 语句面板整文件迁 plugins/blocks → 46。
      // S6c form_design_canvas.mbt 整文件迁 plugins/design(薄壳包装并入
      // form_design_session.mbt) → 45。
      // S7 code_intel.mbt 整文件迁 plugins/code(新建) → 44。
      // S7b code_project.mbt 整文件迁 plugins/project(写盘 effect 并入
      // new_project.mbt,不新增壳文件) → 43。
      // S4 ai_sessions_pane.mbt 整文件迁 plugins/ai(投影薄壳包装并入
      // ide_shell.mbt,不新增壳文件) → 42。
      // S4c ai_workspace_panel.mbt 整文件迁 plugins/ai(投影薄壳包装并入
      // ide_root.mbt,不新增壳文件) → 41。
      // S7d views_compile.mbt 整文件迁 plugins/run(投影薄壳包装并入
      // update_run.mbt,不新增壳文件) → 40。
      // S4b ide_ai.mbt + markdown_view.mbt 两个文件迁 plugins/ai;壳新建
      // ide_ai_views.mbt 投影薄壳(删 2 增 1) → 39。
      max_count: 39,
    },
    {
      kind: "studio model fields",
      label: "moui_studio/app/model.mbt",
      path: "moui_studio/app/model.mbt",
      // 基线冻结(2026-10-12 实测 161,含 6 个 mut 字段;完成线 ≤ 55)。
      // S2b-1 工程域状态切片(2026-10-12):17 个工程/资源管理器字段并入
      // plugins/project 的 ProjectState(壳持单一 project_state 字段)→ 145。
      // 棘轮复核(2026-10-13):实测 144(S2b-1 迁移后切片结构体少计 1 个
      // 包装字段),收紧到实测值;S6a 设计域出壳不触及 Model 字段 → 144。
      // S4d AI 域 UI 状态切片(2026-10-13):17 个纯 UI 字段(composer/provider/
      // 转录滚动/会话列表 UI/对话框开合/工作卡折叠)并入 plugins/ai 的
      // AiUiState,壳持单一 ai_ui 字段(净 −16)→ 128。
      // S5e 积木域 UI 状态切片(2026-10-13):7 个纯 UI 字段并入 plugins/blocks
      // 的 BlocksUiState,壳持单一 blocks_ui 字段(净 −6)→ 122。
      // S5f 工程域 UI 状态切片(2026-10-13):4 个纯 UI 字段(结构树搜索/分组
      // 折叠/新建菜单分组/全文搜索草稿)并入 ProjectState(净 −4)→ 118。
      // S5g 代码编辑器 UI 状态切片(2026-10-13):光标/选区/滚动/补全候选/
      // 补全开关 5 个字段并入 CodeUiState,壳持单一 code_ui 字段(净 −4)→ 114。
      // S5i 运行域切片(2026-10-13):编译输出展开 + 预览档位 2 字段并入
      // RunUiState(壳持单一 run_ui 字段,净 −1)→ 113。
      max_count: 113,
    },
    {
      kind: "studio msg variants",
      label: "moui_studio/app/model.mbt",
      path: "moui_studio/app/model.mbt",
      // 基线冻结(2026-10-12 实测 291;完成线 ≤ 90)。
      // S2b-2 工程域子消息(2026-10-12):14 个纯态臂迁 plugins/project
      // 的 ProjectMsg,壳持单一 ProjectOp 委托臂 → 278。
      // S4d AI 域 UI 状态切片(2026-10-13):16 个纯 UI 态臂(composer/provider/
      // 转录滚动/会话搜索悬停改名草稿/设置与历史开合/工作卡折叠)迁
      // plugins/ai 的 AiUiMsg,壳持单一 AiUiOp 委托臂(净 −15)→ 263。
      // S5e 积木域 UI 状态切片(2026-10-13):9 个纯 UI 态臂(面板开合/分类、
      // 画布滚动/自动滚、值编辑草稿/取消、语句/表达式拖放开始、菜单关闭)迁
      // plugins/blocks 的 BlocksUiMsg,壳持单一 BlocksUiOp 委托臂(净 −8)→ 255。
      // S5f 工程域 UI 状态切片(2026-10-13):11 个纯 UI 态臂(tab 切换/关闭、
      // 文件 CRUD 输入态 6 个、结构树搜索/折叠/新建菜单 3 个、搜索草稿)并入
      // 既有 ProjectMsg(复用 ProjectOp,0 新委托,净 −11);SearchHitClicked/
      // SelectProjectFile/At 因有读盘/开文件 effect 臂留壳 → 244。
      // S5g 代码编辑器 UI 状态切片(2026-10-13):EditorCaretMoved/EditorScrolled/
      // DismissCompletion 3 个纯态臂并入 CodeUiMsg,壳持单一 CodeUiOp 委托
      // 臂(净 −2)→ 242;触发/采纳补全/跳转声明读 code_draft/program 留壳,
      // 经切片内部消息回写 UI 态,不占壳变体。
      // S5h AI composer 草稿(2026-10-13):SetPrompt 并入 AiSessionMsg(复用
      // AiSessionOp,0 新委托,−1),删除 S4d 遗留死枚举 AiSessionRenameDismiss
      //(−1)→ 240;EditUserPrompt/RetryUserPrompt 读时间线卡片回填,内容耦合留壳。
      // S5i 运行域切片(2026-10-13):ToggleCompileOutput/SetPreviewMode 2 纯态
      // 臂并入 RunUiMsg,壳持单一 RunUiOp 委托(净 −1);删除终端死消息
      // TerminalScrolled(−1)→ 238;PreviewNavigate/PreviewReload 与 TabClose
      //(kill PTY)、SetPreviewDesignOpen(打开时派发 FormDesignOpen)有 Effect
      // 留壳;design_zoom 单标量独立切片净 0 变体,实测留壳。
      // 目标模式切片(2026-10-15):InsertCustomFunction(自制积木
      // 组插入函数调用)+ CopyAiCodeBlock(块级复制)两个新壳臂;同批
      // CopyAiMessage 复用既有通道,无新增委托 → 240。
      // 调色板拖拽换算(2026-10-16):PaletteDragPointer/PaletteDropAt 两个
      // 新壳臂——调色板行持有指针捕获(runtime 语义),画布手势收不到
      // 移动/松手;行只能上报**视口坐标**,视口→链的换算需要画布布局帧
      // (组合根注入的锚点回调),只有 update_with_provider 的闭包拿得到,
      // 所以这两臂必须留壳、不能并入 BlocksUiMsg(切片 update 无 Model)
      // → 242。
      max_count: 242,
    },
  ]
}

///|
/// 源文件口径:排除测试与 i18n 生成物(它们由各自机制独立治理——
/// source-file-policy 的 generated 清单与测试自身的预算)。
fn studio_shell_source_file(path : String) -> Bool {
  !path.has_suffix("_test.mbt") &&
  !path.has_suffix("wbtest.mbt") &&
  !path.has_suffix("i18n_catalog_generated.mbt")
}

///|
fn collect_studio_shell_files(
  repo_root : String,
  files : Array[String],
  failures : Array[String],
) -> Unit {
  let all : Array[String] = []
  collect_mbt_files(repo_root, "moui_studio/app", all, failures)
  for path in all {
    if studio_shell_source_file(path) {
      files.push(path)
    }
  }
}

///|
/// `String[index]` 的返回类型是 UTF-16 码元(UInt16);与 Char 字面量的
/// 比较(如 `>= 'a'`)是合法的,这里保持同一形态。
fn studio_shell_is_ascii_ident_char(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
/// Model 字段行:恰两空格缩进 + 可选 `mut ` + 小写/下划线开头的标识符 +
/// 空白 + `:`。更深缩进(载荷续行)与注释行天然不匹配。
fn studio_shell_is_model_field_line(line : String) -> Bool {
  if line.length() < 3 || line[0] != ' ' || line[1] != ' ' || line[2] == ' ' {
    return false
  }
  let mut pos = 2
  if line.has_prefix("  mut ") {
    pos = 6
  }
  if pos >= line.length() {
    return false
  }
  let lead = line[pos]
  if !((lead >= 'a' && lead <= 'z') || lead == '_') {
    return false
  }
  while pos < line.length() && studio_shell_is_ascii_ident_char(line[pos]) {
    pos += 1
  }
  while pos < line.length() && line[pos] == ' ' {
    pos += 1
  }
  pos < line.length() && line[pos] == ':'
}

///|
/// Msg 变体声明行:恰两空格缩进 + 大写开头标识符,其后是行尾、载荷 `(`、
/// 空白(注释前)或 `/`(行注释)。载荷跨行续行的缩进更深,不匹配。
fn studio_shell_is_msg_variant_line(line : String) -> Bool {
  if line.length() < 3 || line[0] != ' ' || line[1] != ' ' || line[2] == ' ' {
    return false
  }
  let lead = line[2]
  if !(lead >= 'A' && lead <= 'Z') {
    return false
  }
  let mut pos = 2
  while pos < line.length() && studio_shell_is_ascii_ident_char(line[pos]) {
    pos += 1
  }
  if pos >= line.length() {
    return true
  }
  let c = line[pos]
  c == '(' || c == ' ' || c == '/'
}

///|
/// 取 `decl` 声明行之后、配对 `}` 之前的所有行。找不到声明返回 None
/// (由调用方记 failure,不让预算静默通过)。
fn studio_shell_decl_span_lines(text : String, decl : String) -> Array[String]? {
  let mut inside = false
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if !inside {
      if line == decl {
        inside = true
      }
    } else if line == "}" {
      return Some(lines)
    } else {
      lines.push(line)
    }
  }
  if inside {
    // 无配对右括号:按文件尾处理(计数继续),语法问题由 moon check 兜底。
    Some(lines)
  } else {
    None
  }
}

///|
fn count_studio_shell_decl(
  repo_root : String,
  path : String,
  decl : String,
  is_member : (String) -> Bool,
  failures : Array[String],
) -> Int {
  match read_repo_text(repo_root, path) {
    Ok(text) =>
      match studio_shell_decl_span_lines(text, decl) {
        Some(lines) => {
          let mut count = 0
          for line in lines {
            if is_member(line) {
              count += 1
            }
          }
          count
        }
        None => {
          failures.push(
            "studio shell budget could not find decl: " + decl + " in " + path,
          )
          0
        }
      }
    Err(message) => {
      failures.push(message)
      0
    }
  }
}

///|
fn collect_studio_shell_overflows(
  repo_root : String,
  failures : Array[String],
) -> Array[CountBudgetOverflow] {
  let overflows : Array[CountBudgetOverflow] = []
  let source_files : Array[String] = []
  collect_studio_shell_files(repo_root, source_files, failures)
  let mut source_lines = 0
  for path in source_files {
    match read_repo_text(repo_root, path) {
      Ok(text) => source_lines += line_count(text)
      Err(message) => failures.push(message)
    }
  }
  let model_fields = count_studio_shell_decl(
    repo_root, "moui_studio/app/model.mbt", "pub(all) struct Model {", studio_shell_is_model_field_line,
    failures,
  )
  let msg_variants = count_studio_shell_decl(
    repo_root, "moui_studio/app/model.mbt", "pub(all) enum Msg {", studio_shell_is_msg_variant_line,
    failures,
  )
  for budget in studio_shell_budgets() {
    let count = if budget.kind == "studio shell lines" {
      source_lines
    } else if budget.kind == "studio shell files" {
      source_files.length()
    } else if budget.kind == "studio model fields" {
      model_fields
    } else {
      msg_variants
    }
    record_count_budget_overflow(budget, count, overflows)
  }
  overflows
}
