# MoUI StudioApp Notes

## Package

- `moui_studio`（module `moui_studio`，2026-09-27 建立）：中英双语可视化
  编程 IDE，单一程序 IR 支撑「窗体设计 / 积木编排 / 双语代码」三视图 + 结构化
  AI 提案 + 闸门化运行 + 独立应用导出。计划：`docs/plans/active/moui-studio.md`。
  前身 `examples/moeui_studio` / `examples/moblocks_studio` 已删除（git 历史
  e7cfe78e2 / a29eb8e3d 可查），salvage 映射见计划第 11 节。
- 结构（计划口径）：`domain/{ir,studio_lang,codec,blocks,proposals}` 零 UI 依赖、
  `services/{export,model_provider,provider_native}`、`app/`（TEA + 五视图，
  native+wasm-gc）、`web_wasm/` + `macos_skia/` 薄入口、`tools/{sync_kernel,
  emit_bundle}`。
- 最小循环：`moon test moui_studio/app --target native|wasm-gc`、
  `moon build moui_studio/web_wasm --target wasm-gc`、
  `node scripts/generate-i18n-catalogs.mjs ... --check`、
  `moon run moui_studio/tools/sync_kernel --target native -- --check`。

## 产品决策（重写时不要推翻）

- IR 是语句级（Assign/If/CountLoop/WhileLoop/Break/Call），不是自由图；
  积木与代码都是 IR 的投影，代码视图是文本真身。
- DSL 关键字是 catalog 数据（`domain/studio_lang/keywords.mbt` 中英两张表），
  解释器内禁止 `keyword == "如果"` 式硬编码分支；往返测试
  `parse(render_zh(ir)) == ir == parse(render_en(ir))` 是硬门。
- 内核语言中立：ParseError/RunError 只给结构化 `{kind,line,col,token?}`，
  可读文案全部由界面层经 `moui_i18n` catalog 解析（key 不进领域层）。
- `提交数据` 是闸门化模拟动作（确认卡 + 审计），v1 不发起真实网络请求；
  web 端只走确定性假模型，真实 OpenAI 兼容 provider 仅 native。
- 真实模型默认配置：阶跃星辰 StepFun，endpoint
  `https://api.stepfun.com/step_plan/v1`，model `step-5-preview`。**凭据
  唯一来源是 gitignored 的 `moui_studio/.config.json`**
  （`{provider:{endpoint,model,api_key}}`，根 .gitignore 第 52 行登记）：
  native 组合根启动读取预填面板；`services/provider_native` 的
  `load_provider_config` 解析测试×2（**live smoke 测试从未落地**：
  2026-09-27 验收核验发现早期记录失实，git 历史无此测试，计划验收项 2
  因此留白）。key 禁止进
  源码/项目文件/导出 bundle（有测试断言）；endpoint/model 可改，默认模式
  仍是假模型。
- 可读性是一等目标：AI 生成的每个 handler 必带双语 `note`（意图说明），
  命名必须自解释（`a1`/`tmp` 类被校验拒绝），同一 IR 渲染逐字节稳定，
  AI 面板「解释这个程序」逐语句产出当前语言讲解。
- 框架扩展按需允许：新控件走 `moui/views` 具体 `ViewNode` +
  `View::from_node`（core 不加枚举变体），带测试与文档，decision log 记录
  理由；默认优先用现有控件组合。
- i18n：语言存 app model + settings 快照（mo_desktop 模式），入口经宿主回调
  同步 `Environment.locale`（website 模式）；shared app 不 import runtime。

## 工具链陷阱（2026-09-25/26 实测，moon 0.1.20260920）

- `derive(Eq, Debug)` 在新模块触发 `implicit_impl_as_method` 警告（每个 derive
  一条，原因未定位）。**对策：app 包默认零 derive**（counter 风格），枚举比较
  用 `is` 模式，断言用 `assert_true(x is Variant)`。
- `Map::new()`→`Map([], capacity=16)`；`Array::new(capacity=n)`；
  `Option.or(x)`→`unwrap_or(x)`；`not(expr)`→`!expr`；`derive(Show)` 废弃
  （用 Debug）。`assert_eq` 需要 `Eq + Debug`。
- 测试文件（`*_test.mbt`）是独立包：同包函数须 `@app.` 前缀（否则
  test_unqualified_package 警告），枚举构造器可裸用；跨包 struct 字面量要求
  `pub(all) struct`。
- `@json.parse(text) catch { _ => ... }` 可直接接 String；`Json::stringify()`
  是紧凑格式（断言别带空格）；`Number(Double, repr~)` 双字段。
- `guard` 是关键字不能当变量名；`Array` 没有 `find` 方法（手写 for 循环）；
  `Array::fold` 参数顺序易错；MoonBit 字符串里 `{` 字面量就是 `"{"`。
- 源码行预算：`validate-maintenance-baseline` 默认 1800 行/文件硬线；
  `app.mbt` 超 ~1200 行按架构拆 `view.mbt`。

## 画布 / 指针 / 框架坑（全部实测过）

- `@views.canvas(measure, draw)` + `on_drag_with_frame` 足够做命中/拖拽，
  无需自定义 ViewNode；绘制逻辑拆纯数据 draw-plan 后可断言 op 数量做帧基线。
- canvas measure 不要狮子大开口（column flex 会被撑爆）；Transform2D 组合用
  结构体字面量。
- **`AppServices::new()` 不能在 update 闭包里每次构造**：wasm-gc 下所有指针
  事件静默失效。在 `program()` 构造时捕获一次 `environment.services()`。
- ~~canvas 的 `DrawText.frame` 是画布局部坐标~~ **2026-09-27 实测更正：MoUI
  paint 命令是窗口全局坐标**——`collect_frame_commands`（moui/runtime/
  render_tree.mbt）把各节点命令原样拼接、不做逐层平移，`draw(ctx, frame)`
  的 `frame` 就是给应用自己偏移用的。自绘内容必须加 `frame.origin`，否则
  内容画到窗口原点、被自己的 clip 裁掉（症状：画布空白）。
- **`divider()` 默认 Horizontal 轴按 `constraints.max.width` 测量**（整宽
  横线，为列布局设计）。直接放进 `row` 会占满剩余宽并 `FillRect` 盖住其后
  所有兄弟（画布/右栏全部"消失"、出现大片 `outline_variant` 灰）。row 内
  分隔线必须 `divider(axis=Vertical)`。此坑双端（Skia/web）一致。
- **单击不产生 DragGestureEvent**：识别器 3px slop，Pending→Up 走 Cancelled
  且无事件。画布点选用 `View::on_tap_with_frame`（2026-09-27 新增于
  moui/core，OnTapWithFrameModifier：透明、无语义角色、Up 才触发、带
  position+frame）；与 `on_drag_with_frame` 叠加时把 tap 放前面，app 侧用
  `model.drag is Some(_)` 区分拖拽结束的 tap。
- 受控 `text_field` 的显示值完全由 `value` 参数驱动：运行时输入必须把新值
  写回状态（如 MoUI Studio 的 `run.state.texts`），否则输入回跳、`取文本` 读旧值。
- `DragGesturePhase::Started` 发生在第一次越过 3px 阈值的 Move，不是 Down；
  测试先发小步进再发完整位移。画布同名文本用 `+` 前缀消歧。
- `text_field` 首参是当前值、`on_input` 带新值；`scroll_view(view, width~,
  height~)` 裁剪命中区。

## provider IO 要点

- `moonbitlang/async/http` **只有 native 目标**：wasm-gc 下 `@http.post`
  解析不到 → app 只依赖 provider 包的纯函数部分，native 组合根把
  `provider_submit` 闭包传进 `program(provider_submit~)`。
- **OpenAI 兼容 URL 必须自己拼 `/chat/completions`**：配置里的 endpoint 是
  base URL（`https://api.stepfun.com/step_plan/v1`），SDK 用户自动拼接、
  手写 `@http.post` 不会——2026-09-27 live smoke 首跑抓到 404，现统一走
  `@provider.completion_url`（base 拼/全路径原样/尾斜杠归一）。
- **live smoke**：`provider_native.provider_live_completion(config, prompt)`
  + `worker_test` 跳过式 async test（配置缺失即跳过）。`moon test` 的
  cwd = **module 根**（`moui_studio/`，探针实测），配置路径候选
  `.config.json` + `moui_studio/.config.json`。live 调用会消耗 key
  配额；测试期间出现工具链级 `warning: input verification failed`
  （非仓库源码，异步 IO 时出现，无害）。
- async 组合：`async fn main` + `@async.all([window_task, worker_task])`，
  窗口侧 `run_async_pump()`，worker 侧 `@async.with_task_group` +
  `queue.get()` + `group.spawn_bg`。HTTP：`@http.post(url, body, headers={
  "Authorization": "Bearer " + key })`，响应 `(resp, data)`。
- `Queue::try_put` 会 raise，`ignore(x catch { _ => false })`；结构体字段里的
  回调调用写 `(job.on_result)(result)`。key 只存会话内存，测试断言 encode
  产物不含 key。

## 导出 bundle（两个硬骨头，2026-09-26 实测解决）

1. **Web 运行时 JS 只能来自 `.mooncakes`**：导出的 `index.html` 引用
   `../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js`（相对 web_wasm/），
   其内部 `../moui/backend/web/browser_runtime.js` 才能解析到 bundle 自己的
   `.mooncakes`。不要把 JS 拷进 bundle 或嵌成 MoonBit 常量（1800 行预算 +
   与 moon.mod 固定版本脱钩）。
2. **wasm 链接器只导出可执行包自身定义的函数**：`link.exports` 只登记符号，
   符号必须在可执行包自己的 `.mbt` 里定义，否则静默 DCE（浏览器报
   `must export web_dispatch_event`）。修法：可执行包含一个机械 `abi.mbt`
   逐个 `pub fn web_xxx(...) { @web.web_xxx(...) }` 转发。
- `#|` 多行字符串**不做 `\{x}` 插值**（原样输出）；sync_kernel 同步内核时
  若加倍反斜杠会静默改变语义——bundle 里的 .mbt 与源文件必须 `cmp` 逐字节
  相同。`moon fmt` 也会造成内核漂移，`--check` 门必须常驻。
- 导出自包含应用的最小充要条件：领域内核（ir/studio_lang/codec，零 UI 依赖，
  只允许 `@graphics.Color` 与 `@json`）+ 一个 ~150-200 行通用 TEA runner。
  内核之间可互调，**不能调用非内核文件里的函数**（workspace 外构建才报错，
  例：`auto_layout` 曾被 ai_generation 持有导致 bundle 编译失败）。
- 浏览器里导出应用的逻辑坐标 == CSS 坐标（宿主按画布尺寸重排），不要再按
  DPR 换算。

## 2026-09-27 P1 落地后新增事实

- **模块已成形**：`moui_studio` 独立 module，五个领域包 + services×3 + tools×2 +
  app + web/macos 入口。全量测试：domain 51 + app 14 + model_provider 5 + export 8
  （双目标）+ provider_native 2（native）。
- **最小循环**：`moon test moui_studio/domain/<pkg> --target native|wasm-gc`、
  `moon test moui_studio/app --target native|wasm-gc`、
  `moon run moui_studio/tools/sync_kernel --target native -- --check`、
  `moon run moui_studio/tools/emit_bundle --target native -- <project.json> <name> <dir>`。
- **IR 是语句级**（Declare/Assign/If/CountLoop/WhileLoop/Break/Call；If 带
  else-if 链数组）；内建 14 个（12 + row_count/row_at）；闸门 2 个
  （ask/submit_data）。IR 存规范 id（英文），源码名按语言表渲染。
- **解释器是指令机**（编译 AST→跳转指令），不是树遍历：聚光灯/闸门暂停/单步/
  审计全部由此而来。闸门恢复 = 预置 answer 后重跑同一指令（表达式位只有闸门
  有副作用，重跑安全）。
- **控件名参数**：`取文本(姓名框)` 的姓名框是控件名（Var 裸标识符），不是变量；
  `RunState::control_name` 处理 Var/StrLit/其它。
- **MoonBit 实战坑（新增）**：enum 声明位不接受 `@pkg.Type`（要用类型别名）；
  `?` 操作符本版本不可用（显式 match 传播）；`[...arr, x]` spread 不可用；
  `String.trim()` 返回 StringView（要 `.to_string()`）；`Array` 无 `at/find/
  find_last`；`StringBuilder` 无 `length`；`String` 无 repeat/join（手写）；
  跨块 mut 捕获会被判 unused_mut（分段构造再拼接）；标签参数调用是 `name=value`
  或 `name~` 简写，不是 `name~=value`；`Json` 布尔构造器是 `True/False`；
  `Translator::new` 要 `Locale` 不是 String；`String.replace` 要 `old=/new=`
  标签参数；`Map.get` 读；`parse_*` 位置 `?` 不行。
- **运行期活状态**：app Model 持有 runtime_values/runtime_texts，跨事件累积；
  运行结束时 merge_run_back 并回。
- **导出 bundle**：内核常量按源文件一个常量一条，但**常量文件仍按行预算拆组**
  （kernel_studio_lang + kernel_studio_lang_rt 两组；1800 行/文件硬线）；bundle
  里 kernel .mbt 必须与源逐字节一致（cmp 验证）；独立构建需 `moon update`
  拉 mooncakes.io。emit_bundle 签名：`<project.json> <app-name> <target-dir>`。
- **i18n**：app 自带 230 条中英 Message（手写 catalog，不走 generate 脚本——
  示例包不引入 JSON 加载）；文案全部 key 化（含 DSL 错误 kind 映射）。
- **假模型**：`fake_model_completion(prompt, current_program)` 全量构建语义
  （先 remove 全部再加），关键词路由中英文混合。

## 2026-09-27 收官两项（verifier 补齐）

- **i18n 生成链**：数据在 `moui_studio/app/i18n/{zh-Hans,en}.json`（manifest
  `catalogs.json`），`node scripts/generate-i18n-catalogs.mjs --input … --out …`
  生成 `i18n_catalog_generated.mbt`（GeneratedI18nCatalog + Text/Plural），
  app/i18n.mbt 只做适配（studio_messages 打平成 @i18n.Message）。`--check` 步骤
  名 "studio i18n catalogs"（checks/profiles.json）；生成文件需同时进
  `checks/source-file-policy.json` 的 generated 白名单（header/maxLines/
  checkCommand 三项照抄 website 条目改路径）。
- **积木编辑回写**：`domain/blocks` 的 BlockItem 带 `path : Array[Int]`
  （If: [i,0,j] then / [i,1,k,j] else-if / [i,2,j] else；循环: [i,2,j]）；
  手术函数 replace_stmt_at/delete_stmt_at/stmt_at 是**就地语义**（数组引用），
  测试里先后读同一数组会互相污染——先固定期望值再操作。
- **测试陷阱**：`@ir.Call` 在 Stmt 数组里与 `@ir.Expr::Call` 歧义，写
  `@ir.Stmt::Call` 消歧；MoonBit for 循环里给 `on_click` 传下标要先
  `let row_index = index` 固定（闭包捕获）。

## 2026-09-27 UI 评审修复（点击/拖拽/布局实测验证）

- **web 入口启动 API**：`index.html` 用
  `bootMouiWasmGcApp({ wasmUrl: new URL(...), canvasHost: "#root",
  onStatus })`（具名导出，runtime.js **没有 default 导出**）；canvasHost 是
  容器选择器（canvas 由运行时创建、parent 作测量基准）。打包器
  `rewriteIndexForPackage` 会把 `.mooncakes` 引用与 `_build` wasm 路径改写
  成 `./runtime.js` / `./web_wasm.wasm`。旧版 `import init from ...` 静默
  卡在"正在加载"（模块级失败不进 catch）。
- **主题**：入口跟随系统深浅色（web 走 prefers-color-scheme，native 走系统
  主题）。深色系统 + 无背景的浅色布局 = 白字白底。MoUI Studio 在根视图
  `.theme(@views.light_theme())` 钉浅色（课堂演示确定性外观）。
- **顶栏单行 13 个按钮在 1280 宽溢出**：拆两行 + `container(padding=10)`。
- **布局调试法**：单控件二分（row 逐个换 `@views.text`）+ `screencapture -x
  -l <window_id>` 截原生窗口（CUA 对 MoUI 自定义 surface 截图会失败但 AX
  树可用：macOS 上语义树直接可读，模式切换/检查器字段都能断言）。
- **web 交互测试**：IAB 的 `cua.drag` 不派发中间 pointermove（识别器收不到
  Move，永远不 Started）——用 `playwright.evaluate` 在 canvas 上合成
  `PointerEvent("pointerdown"/"pointermove"…/"pointerup")` 序列（bubbles,
  pointerId, buttons=1）即可驱动完整拖拽链路。首次点击可能只做 webview
  聚焦不派发（观察为"第一下没反应"）。

## 2026-09-27 完善批次新增事实（质量闭环 + UI 全套）

- **update 已拆四文件**：update.mbt（共享助手 + shell/design 域）+
  update_run/update_blocks/update_ai；分发是 `update_pure` 里的链式
  Option 匹配（各域 fn 返回 `(Model, Effect)?`，未命中传链）。消息构造器
  互斥，顺序无关。
- **真实 provider 两个连环 bug（都由补测抓到）**：① endpoint 是 base
  URL，手写 `@http.post` 不会拼 `/chat/completions`（404）——统一走
  `@provider.completion_url`；② `RealGenerationFinished` 原本没有处理器、
  真实生成结果被静默丢弃——现已移入 update_ai 纯域（结果消息是纯状态
  转移，与假模型同走 proposal_from_completion 校验链），并有回归测试。
- **`moon test` 的 cwd = module 根**（`moui_studio/`，探针实测），
  不是仓库根；`moon run` 才是仓库根。`.config.json` 路径候选要两者兼顾。
- **UI 框架要点（B1-B4 实测）**：`@views` facade 的 `pub using` 转发会把
  枚举构造器带进作用域（`variant=Ghost`/`role=Title` 裸写可用），但 match
  臂里的裸构造器不行（BadgeTone 与 FeedbackTone 歧义，要
  `@style.BadgeTone::Success`）；`ColorPalette::from_seed(primary~, scheme)`
  的 **scheme 是位置参数**；`View::on_tap(msg)`（core）给彩色 container 行
  加点击 + Semantics，积木行靠它替代文本按钮；现成控件直接用：card/
  button_group+action_item/checkbox/progress/loading_state/inline_error/
  badge(tone)；品牌主题 `studio_theme()` = 朱砂 `ColorPalette::from_seed`
  + `@views.theme(palette=...)`（app 主导入块加 `wzzc-dev/moui/core` 是
  示例 app 既有先例，pdf_workbench 等都这么干）。
- **导出回归门**：`scripts/studio-export-smoke.sh`（emit_bundle → 临时目录
  `moon update` + 独立 wasm-gc 构建），注册为 smoke/gates.json
  `studio.export-build`（nightly 档，需网络不进 pr）。坑：emit_bundle 产物
  在 `<target-dir>/<app-name>/` 且 app 名被模块名安全化（下划线→连字符），
  用唯一子目录通配进入；脚本退出码会被管道 tail 吃掉，重定向到文件再取。
- 设计画布绘制计划已 pub(all)（GridDot/GuideV/GuideH/SelectionHandle op），
  alignment_guides 纯函数 ≤4px 容差；同宽控件偏移 ≤4px 时左/中/右三条
  参考线全命中（测试按成员断言）。
- app 包曾有 test-block `wzzc-dev/moui/core` 死导入（unused package
  警告），已移除并转入主导入块实际使用。

## 2026-09-27 承诺兑现批次（缩放/吸附/新建子程序）

- **拖拽态二分**：`DragState{control, kind}`，`DragKind.Move(offset_x, offset_y)`
  / `Resize(@ir.DragCorner)`。缩放数学在 `@ir.Control::resize_from_corner`
  （对角固定，四角各自推导，夹取与 with_rect_field 同纪律）；改 domain/ir
  后必须重跑 sync_kernel（本次已同步，--check 零漂移，导出烟测重跑通过）。
- **手柄优先于控件体**：CanvasPress 先对选中控件做 `hit_test_handle`
  （角点 ±6px 命中，绘制是 8x8 方块），命中即 `Resize(corner)` 且不改选中；
  落空才走 hit_test_control 建 Move。**测试按住点若取控件原点 +5px 会落进
  手柄区触发缩放**——移动拖拽测试按下点要距角 >6px（+20/+15 已用）。
- **吸附只在移动**：`snap_move_position`（canvas.mbt，pub）与
  alignment_guides 共用同一目标集（画布三线 + 其他控件左/中/右、上/中/下）
  与 4px 容差，从 (目标, 平移量) 候选取 |平移| 最小者；吸附后仍过
  with_rect_field 夹取（目标全在画布内不会越界）。缩放时参考线仅显示不吸附。
- **CreateHandler(control, event)**：设计域消息；守卫 = 控件存在 + 事件受
  支持 + (控件,事件) 不重复 + MAX_HANDLERS 预算（超限设 notice
  `app.status.handlers_limit`，AddControl 同理 `app.status.controls_limit`）。
  UI 新建的 handler note 留空——双语 note 必填只约束 AI 提案。左栏入口 =
  选中控件「支持但尚无 handler」的事件按钮（`app.handler.new` +
  `event.on_click/on_change` 键早已在 catalog，本次首次接线）。
- **DeleteControl 草稿语义**：仅当被删控件的子程序正是 selected_handler
  时清空选中并 sync_code_draft；删别的控件不动草稿（保未提交编辑）。
- 画布 `semantics_label` 改为 design_canvas 的参数（调用方经
  `text(t, "app.design.canvas")` 传入）——自绘控件的语义标签不要硬编码。
- 设计尺寸常量单一来源 `@ir.DESIGN_WIDTH/HEIGHT`（canvas.mbt 顶层 let
  `.to_double()` 派生），不要再写 640.0/480.0 字面量。

## 2026-09-28 参赛冲刺批次新增事实

- **撤销/重做**：`with_undo_point(model, key, mutate)` 统一入口——先捕获
  UndoEntry 再变更，`@ir.program_signature` 前后相等即视为 no-op 不入栈；
  合并规则 = key 非空且与栈顶相同（连续同控件 text/rect 编辑、整段拖拽手势
  共享一个还原点）。Undo/Redo 后 runtime_values/texts 按恢复的程序重置、
  积木选择态清空。拖拽 key 用 "move:<名>"（同控件连续拖拽各成还原点，
  因为栈顶 key 相同会合并——如需逐拖还原需换 unique key）。
- **单步运行**：`RunModel.single_step` 冻结 RunTick（30ms/6 条自动推进），
  RunStep 走一条、RunResume 恢复；子程序重跑（ControlClicked）重置为
  false。**拍摄/演示技巧：闸门是天然暂停点**——闸门暂停时点单步冻结
  计时器，确认后即可逐条走（短子程序自动推进太快，直接单步抢不过计时器）。
- **MoonBit 预览**：`@export.moonbit_preview(program)` 逐字节稳定；
  export 包因此真实 import domain/ir（工具侧依赖，内核快照无关）。
  语句 JSON 编码字段是 `"op"`、表达式是 `"t"`（提案篡改测试靠这个）。
- **DuplicateHandler 曾是死变体**：validate_program 原来不查 (控件,事件)
  唯一性；修复后注意 apply_proposal 的 handlers_add 是**替换语义**
  （提案造不出重复对，重复只能来自损坏基底）。
- **studio_lang 关键字真身**：计次循环（计划文档里的「计次」是简写）。
- **web 素材生产**：python-playwright + 合成指针事件可完整驱动 IDE
  （1440x900 校准坐标见 moui-milestones/video/studio_shot*.py）；右栏是
  内滚 scroll_view，点 AI 面板前先在面板上 wheel；@views.text 默认
  TextCenter，代码语境要显式 align=TextStart。
- **导出 runner 未接品牌主题**（独立应用控件是默认深色块）——功能正确
  外观欠账，是下一个 UI 提升项（视频素材 README 已注明规避）。

## 2026-09-28 完善批次（冻结前收尾）新增事实

- **RunStatus 有 WaitingGate 变体**：闸门暂停时 status 是 WaitingGate 而非
  Running——按 status 过滤运行中按钮时要把 WaitingGate 算作活运行
  （单步/继续在闸门暂停时仍可用，是「闸门暂停→单步冻结→确认后逐步」
  教学手法的入口）；终态（Completed/Failed）才隐藏。
- **运行舞台条单行会裁按钮**：436px 内滚区一行放不下 caption+子程序名+
  3 按钮——拆两行。运行面板内的横向空间按 436 预算。
- **导出 runner 模板**在 `tools/export_runner_template/runner.mbt`（sync_kernel
  同步为 services/export/kernel_runner.mbt 常量）；改模板必跑 sync_kernel
  + 导出烟测。bundle app_pkg 现依赖 moui/core + graphics + views/style
  （style 是 **views 的子包**，写成 moui/style 会被工作区外构建拦下）。
  runner 已接朱砂主题 + 卡片容器 + 变量表 + 审计色点 + callout 闸门卡。
- **后台会话截不到原生窗口**：`moon run macos_skia` 后台启动进程存活、
  但 AX 报 0 窗口、screencapture 只有桌面——窗口级 native 验证需要
  前台会话（此前会话成功过，环境差异）。

## 2026-09-28 冻结后批次（积木画布/吸附/跳转/快捷键）新增事实

- **RunStatus.WaitingGate**：闸门暂停时 status 是 WaitingGate——运行中按钮
  的显隐要按「非终态」判断（Completed/Failed 才隐藏）。
- **顶栏居中布局会随行宽平移**：top bar 列的行按内容宽度居中，行 2 变宽
  （快捷键徽标）会让行 1 的 tab 整体左移——playwright 坐标不能跨布局版本
  复用，每次改顶栏要重校准。
- **KeyboardShortcut 通路（框架已有，勿重复造）**：@core.KeyboardShortcut::
  new(key~, modifiers?) + View::keyboard_shortcut + @views.shortcut_button
  （自带快捷键徽标与无障碍标注）；runtime 把 Keyboard 全窗口分发给
  shortcut modifier；matches 是修饰键**精确相等**——Ctrl 与 Cmd 要各注册
  一份（链式叠两个 keyboard_shortcut 即可）；空栈触发是安全 no-op 需测试。
- **就地手术会污染撤销快照**：replace_stmt_at/delete_stmt_at 是就地语义，
  快照（浅拷贝 struct）与活状态共享 body 数组——手术前必须
  @blocks.clone_stmts（有 program_signature 回归测试锁定）。
- **积木画布**：blocks_canvas.mbt（blocks_item_rects/hit_index/drop_slot/
  draw_plan + canvas 视图）；榫头 = 非首块顶部 18x7 同色凸块、卯口 = 底部
  挖画布底色；display_texts 由 panel 预渲染（draw 闭包无翻译器）；
  reorder_stmt 克隆语义 + list_path 寻址（[]/[i,0]/[i,1,k]/[i,2]）；
  否则/结束是**标记块非语句**，重排天然对它们无效（父路径不构成列表地址）。
- **测试独立包无 aliases**：domain/blocks 的 `type Stmt` 别名只在主包可见，
  *_test.mbt 里写 @ir.Stmt。
- **@views.text 默认 TextCenter**；代码语境要 align=TextStart。

## 2026-09-29 双轨真编译批次新增事实

- **主题解析双轨（ADR 0036，白字白底事故的根因）**：框架组件取色有两条
  路——button/text/text_field 在 **paint 期**读 `ctx.environment.theme`
  （跟随 `.theme()` 子树）；container/card/divider 等声明期组件经
  `views_ambient_theme(None)` 回退 `Theme::neutral()`（= minimal **浅色**）
  烘焙颜色。暗色主题 app 里两组相遇 = 白字白底（实测 1.16:1），且所有
  moon test 全绿——测试根本不覆盖这个矩阵。2026-09-29 起声明期表面组件
  已改 ambient（paint 期解析），**但 badge/callout/inline_error/
  empty_state/loading_state/disclosure 等声明期取色组件仍是钉定语义**：
  暗色 app 必须在这些调用点显式传 `theme=<brand_theme>()`。判别法：组件
  源码里出现 `views_ambient_theme(theme)` + `background=计算色` 就是钉定
  语义，需要调用点钉主题。
- **宿主窗口不铺主题底色**：macOS 浅色系统给白窗底、web 给 index.html
  底色。暗色 app 根视图必须显式包一层 `container(background=<底色>,
  padding=0.0)`，否则面板之间和未铺底区域透白。studio 的底色 = 
  `studio_window_background()`（与 palette.background 同源）。
- **1280 宽顶栏预算**：行 2 = 撤销 160 + 重做 216 + 命令面板 150 + 4 模板
  ~440 + 保存/打开/导出 300 + 间距 ≈ 1380 > 1280，「导出应用」被裁。
  命令面板入口已移至行 1（轨道组之后）；再往顶栏加东西前先按此预算算。

## 2026-09-29 双轨真编译批次新增事实（原批次记录）

- **产品名零兼容**：唯一格式 `moui.studio.project` v1；旧 `format`/`version`
  结构化拒绝，不读取、不迁移、不留解码路径；**旧产品名**（改名前的三个
  写法）在仓库源码与文档零残留（grep 断言作提交门）。模块路径
  `moui_studio`，计划 `docs/plans/active/moui-studio.md`。
- **双轨语义（v1 冻结）**：解释轨 = 课堂/Web 轨（沙箱即时执行，100_000 步
  预算、提交数据外发闸门 + 确认卡、审计日志、积木/代码聚光灯，计次循环
  槽 `@iN`/`@iN#n` 隐藏且差分排除）；编译轨 = 毕业通道（**仅 native**，
  Web 显式 `app.track.unavailable_web`）。两轨 RunModel / CompiledRun
  运行态彼此独立；显式切换，不静默降级、不隐式编译、编译轨无单步。
- **真编译管线**：`services/compile_native` 执行 `moon update → moon check
  → moon build --target wasm-gc → moon build --target native → native
  启动存活`。`services/export/moonbit_codegen.mbt` 产出的文本同时用于
  预览与 bundle 内 `app/generated_handlers.mbt`（逐字节同源，不再旁路）。
  `compiled_runtime` 是编译产物的执行面。
- **compile_bundle_at(root)**：root 必须是**含 `moon.mod` 的内层 bundle
  目录**（不是工作区根）；探针耗时参考 update ~2.1s / check ~0.9s /
  wasm-gc build ~1.4s / native smoke 冷启动 ~27.5s。
- **差分硬门**：`services/diff` 三/四样例 × 每类语句（Assign/If/计次循环/
  当循环/跳出/命令调用/函数调用）× zh-Hans/en-US 关键字渲染，逐项断言
  控件文本、变量终态、审计序列完全一致；不一致按 P0，无「已知差异清单」。
- **CompileReport**：`moon check/build` 输出解析为结构化诊断（文件/行/列/
  错误码），本地化后回渲染代码视图与运行视图，并可跳回 IR 语句路径/积木；
  失败绝不自动退回解释轨。控制器字段 `CompileJump`、控制台可重开。
- **命令面板**：`command_palette.mbt`，Ctrl/Cmd+K；执行通道必须保持
  `closing + @moui.Effect::send(command_message(intent))` 语义——直接写 model
  会绕过 SaveRequested/CompileRun 的 service 流。
- **技术风主题**：`studio_theme()` 钉 Dark，朱砂唯一强调色，发丝描边、
  紧半径档、stage/grid/console 专项色；控制台与代码预览等宽。
- **pr profile 新增**：`studio compile native tests`（插在 studio export
  tests 之前）；pr 的 studio 段现有 i18n catalogs / compiled runtime /
  diff matrix / compile native / export tests / export kernel sync。
- **moon info 陷阱**：`scripts/check-generated-interfaces.mjs` 只快照**已
  tracked** 的 `pkg.generated.mbti`，但 `moon info` 会在**未跟踪**的
  package（含 `moui_studio/**`）里生成新 mbti。跑完 `moon info`
  后记得 `git clean -f moui-studio` 清掉这些不该提交的生成物，
  只提交 tracked 漂移（本轮是 `moui/core/pkg.generated.mbti` 的
  `View::on_tap_with_frame`）。
- **`moon fmt` 陷阱**：对 `moui_studio/app/*.mbt` 通配会改写
  无关既有文件（实测 `canvas.mbt`）；只对本次触碰的具体文件跑
  `moon fmt <file>`。仓库多处既有文件有 format 漂移（proposal/main/
  compile_report/studio_lang_test/worker_test/runtime_pointer_input_test），
  `moon fmt --check` 必须全绿才能过 pr profile。
- **`moon fmt` 是 workspace 级**：在任一成员目录（如 `moui_markdown/`）里
  跑不带路径的 `moon fmt` 会格式化**整个 workspace**（实测 2558 tasks），
  包括 submodule 里他人未提交、非 canonical 文件的漂移；2026-10-11 曾因此
  改写 `moui_studio/app/**` 14 个在途文件。恢复路径：子模块 `.git` 的
  unreachable blob + `moonfmt <blob>` 与 post-fmt 缓存逐字节比对。预防：
  只跑 `moon fmt <path>` / `moonfmt <file> -w`，或在 `moon fmt --check`
  前确认工作树无他人脏文件。
- **仓库生成物**：`docs/repository-facts.md` 是生成物——改 docs catalog
  后跑 `node scripts/generate-repo-docs.mjs --write`（会连带
  `sync-website-docs.mjs`）；`website/web_wasm/docs/*` 与 `sitemap.xml`
  是同步生成物（web_wasm/docs 被 gitignore，不入库）。**旧名 grep**：
  新文档里别把旧产品名写回去（本轮踩过一次已清）；`git grep -in` 旧名
  三种写法应零命中（`docs/plans/done`、`docs/ai-sessions` 的历史快照除外）。
- **artifacts/ 与凭据**：`artifacts/` 不入库；`moui_studio/.config.json`
  （StepFun key）gitignored，绝不入源码/bundle。

## 2026-09-30 中心工作区重构（满幅画布 / AI 卡瘦身 / scroll_view 居中缺陷）

- **scroll_view 把「短于视口」的内容垂直居中**（框架行为，坑）：积木画布
  高度按内容算（块少 = 矮）就会被悬浮到滚动区中段。修法 = 画布节点高度
  取 `max(内容高, 视口高)`，内容永远顶对齐。同类场景（列表/画布短内容）
  都要警惕。
- **满幅设计画布（Figma 式）**：`canvas.mbt` 的 `stage_mapping(frame)` 返回
  （fit_scale [0.5,1] 缩放, 舞台居中原点 x/y），**背景画布 / StageLayout /
  覆盖层 / stage_point 指针换算四处共用**；点阵晶格从舞台内容区向四周铺满
  窗格（先铺满幅点 → 舞台白底盖住内部 → plan 再画内容区点），空态提示画在
  舞台中心。画布 measure 用 `pane_fill_measure`（铺满有界约束）。旧
  `auto_fit_measure` 不钳 1.0 与 StageLayout 钳 1.0 的失步只在 solo 窗格
  暴露——统一走 fit_scale 后消除。**GuideH 曾漏加标题条偏移 34pt**（覆盖层
  place 加了、guide 没加），重写时已修。
- **AI 浮动卡瘦身（Copilot/Cursor 口径）**：常驻 = 头部（标题+锚点读数+徽标
  +锚点/收起/停靠/历史/设置图标）+ 单行输入条（模式段｜输入｜发送）；
  窄卡（<520，含停靠 272）输入条折两行（`composer_height` 单点）；上下文
  芯片行/决策行按需出现（无内容 = 0 高，`decision_bar_height` 空返回 0）；
  旧 `.ctools` 工具行与头部图标完全重复（已删），历史入口 = 头部 Clipboard
  图标，忙碌态 = 发送芯片变灰。空闲卡高 102（band 126），测试钉 ≤140。
  **左/右锚卡只有 ~304pt，头部不画锚点读数**（读数只在宽卡 ≥420）；
  停靠图标的可访问名随锚点条件化（`ai_anchor_toggle_key`：停靠态 = 浮出）。
- **画布填充命令是 `FillRoundedRectBrush`**（paint_context 的
  fill_rounded_rect），不是 `FillRoundedRect`——绘制断言按颜色找矩形时
  要 match Brush::Solid。
- 回归测试在 `app/ui_regression_wbtest.mbt`：满幅画布居中（窗格底色矩形
  上下留白对称 ±4）+ 晶格点出现在舞台上方、AI 卡预算上限、无常驻提示行；
  居中断言已破断验证（stage_mapping 改顶对齐 → 红 30 vs 230）。

## 2026-09-30 积木编辑条输入框竖切字（text_area 单行误用）

- **症状**：积木编辑条的语句草稿框里字形被竖切一半（「有些字不显示」）。
- **根因**：用 `text_area(lines=1, line_height=24)` 当单行输入框——text_area
  内部有 8pt×2 垂直内垫，高度 24 扣完只剩 8pt 可见文本窗，16pt 字形被切。
  （与 composer 两行高度的坑同源：**text_area 的高度账必须含 16pt 内垫**；
  单行编辑场景根本不该用它。）
- **修法**：改 `@views.text_field(variant=Outline, height=FIELD_HEIGHT,
  on_submit=Some(CommitBlock))`——原生单行控件自带水平滚动，Enter 直接
  应用草稿（编辑条高度 34 不变）。现有溢出扫描抓不到这种「控件内部裁剪」
  （文字确实在它自己的 clip 窗内），别指望扫描网兜住这类。

## 2026-09-30 框架修复：嵌套 overlay host 双派发（模态点击全失效）

- **症状**：app 有两层 overlay host（如 toast_host 包住 modal overlay_host）
  时，模态对话框内容**看得见点不着**（单层宿主正常）。设置对话框关闭芯片
  是被报告的案例。
- **根因**：`input_pointer.mbt` 的 `dispatch_pointer_to_children` 派发序
  双入队——overlay prepass 经 `subtree_overlay_contains` 把「子树含 overlay
  的宿主」（如嵌套的内层 host，它自身 `is_overlay_child=false`）入队并置
  `is_overlay_owner`，紧随的 in-flow 循环只检查 render 节点的
  `is_overlay_child` 又把它推了一次。同一 child 派发两遍：第一遍 Down 使
  目标 pressed+captured；第二遍 `delivered_main_event` 已置位 → 走
  stale-hover else 分支 → 对**刚按压的同一子树**合成 Exit → 按压态被清 →
  Up 经 capture 回到目标但永不激活。`input_focus.mbt` 的焦点拾取循环同构，
  一并修。
- **修法**：in-flow 循环跳过 `is_overlay_owner[regular_index]` 已入队的
  child（两处）。回归：`moui/runtime/overlay_runtime_test.mbt` 的
  "modal dialog inside a nested overlay host receives taps"（嵌套 host +
  居中 Dialog + on_tap 芯片真实 `dispatch_pointer_input`，断言激活**恰好
  一次**），已破断验证。
- **排查方法论**：绘制级白盒测试看不到事件路径；建临时 harness 包
  （app+runtime 组合根）用 `AppRuntime::new_view + dispatch_pointer_input`
  真实点击是最短复现路径；框架内先加 PREPASS/EXIT-DISPATCH 打印锁定双派发，
  修复后删除。

## 2026-09-30 AI 卡二次精简（无头部 / 两行输入域）

- **头部整个删除**：浮层输入盒不需要标题栏。原「AI 提案 + 锚点读数 +
  假模型徽标 + 5 ghost 图标」→ 0 行。卡级操作进输入盒**脚注**：停靠态=
  「浮出」ghost；浮动态= 停靠/历史/收起（窄卡 inner<320 只留收起）；
  锚点循环与 provider 设置只走命令面板（studio.ai.anchor / studio.settings）。
- **+@上下文芯片行删除**（用户判定多余）：`context_chips` /
  `context_chips_height` 视图路径移除，model 消息保留未接线。若将来恢复，
  从 git 历史找。
- **输入区 = 两行文本域（高度必须含内垫！）**：`@views.text_area(
  lines=3, line_height=20, variant=Plain, on_submit=Some(ComposerRun))`
  ——Enter 直接发送（area 与 field 共用键盘处理器，on_submit 下 Enter
  提交不插换行；长 prompt 自动折行到第二行）。**坑：text_area 内部有
  8pt×2 垂直内垫，构造器高度 = lines×line_height 不含内垫——lines=2×18=36
  扣掉 16 只剩 20，可见的仍是一行**（用户实测抓到）。正确账：高度要给
  `期望可见行数×line_height + 16`，这里 3×20=60 → 可见 44 = 两整行，
  `COMPOSER_HEIGHT = 98`。回归断言：占位文案顶到发送钮顶的垂直距离
  ≥ 50pt（单行布局 ~30），已破断验证。
- **测试锚点迁移**：卡定位从「AI 提案」标题改为占位文案「描述你想要的
  应用」（app.ai.prompt 的 zh 值）——无头后它是卡片唯一的稳定文字锚点；
  「底部居中」读数断言删除。app 150×2 全绿。

## 2026-09-30 AI 卡现代化（Codex/ZCode 口径）

- **composer 是「输入盒」**：圆角 8 容器（ide_panel 底 + 发丝边框，padding
  8/5/8/6）内 = `@views.text_field(variant=Plain)` 无边框输入 + 盒内脚注
  （模式胶囊芯片 + `round_send_button` 圆形强调钮 24×24，ArrowRight 图标，
  accessibility_label="发送"，忙碌 = enabled=false 变灰 + Noop）。宽窄卡
  同构，`composer_height` 恒 64（`COMPOSER_HEIGHT`），card_chrome_height
  走同一函数。盒宽 = 卡宽 − 16（两侧呼吸感）。
- **头部 ghost 化**：`ghost_icon_button(..., surface)` = 透明底（surface 同色）
  + 选中才点亮 ide_selection——头部底色改 ide_elevated 与卡片无缝，不再有
  panel_alt 色条。卡片圆角 10、inline_card（线程/审计卡）圆角 8、hero
  示例芯片胶囊 10——圆角语言统一。
- **测试**：发送是图标没有「发送」文字——`shell_find_send_button(commands)`
  按「FillRoundedRectBrush + Solid(ide_accent) + w=h∈[18,34]」的绘制指纹找
  圆钮（shell_layout_wbtest 共享助手），5 处旧文字断言已迁移；破断验证 =
  发送恒禁用（无强调色圆）→ 3 测红。空闲卡预算仍钉 ≤140（实测 132）。

## 2026-09-30 六项 UI 批次（框架语义叠加/去朱砂/顶栏紧凑化/舞台产品主题）


- **沉浸标题栏高度 = 信号灯圆心的两倍（32pt，不再是 56）**：AppKit 把三灯
  圆心固定在窗口顶往下 **15.8pt**（实测，`TRAFFIC_LIGHT_CENTER_Y` 常量），
  且 `transparent_titlebar` 不给移动能力——想对齐只能让内容去就灯。带高
  取 2×15.8≈32，内容垂直居中即与灯共线；56 时内容中心 28，比灯低 12pt
  （用户截图「信号灯和图标两条线」）。测试断言 run 标签/品牌中心落在灯线
  ±2.5（`immersive mode merges the title bar into one band`），已故意破坏
  验证会红。`ide_root` 的 window_bar = 32−40 = **−8 是刻意的代数**
  （顶栏渲染 32，壳预算 40−8 记），别把它 clamp 成 0。

- **modifier semantics 是叠加不再是替换（框架修复，load-bearing）**：
  `ModifierViewNode::semantics()` = `modifier.semantics.overlaying(child.semantics())`
  （`moui/core/modifier_semantics.mbt` 的 `ViewSemanticsInfo::overlaying`：
  modifier 显式设置的 Option 字段获胜；`composition`/`text` **不从子节点继承**
  ——composition 是结构性语义，text 的 caret/selection 是元素实例状态，
  从包装元素继承会在 overlay 时清掉文本控件的光标）。
  `.semantics_role(TreeItem).on_hover(...)` 读回 role 不再是 None；
  runtime 的 overlay 路径本就按字段合并，直接读与提交树现在一致。
- **去朱砂**：`studio_theme()` primary = `ide_accent()`（#3574F0）；画布/积木
  选中描边等 5 处朱砂字面量改 `ide_accent()`。语义色点（闸门红等）不是主色，
  保持不动。runner 模板 `runner_theme()` primary 同步为同一蓝（sync_kernel 门）。
- **产品主题（stage 的真实样式）**：`studio_product_theme()`（theme.mbt，浅色+蓝）
  在 `stage_layout` 单点 `.theme()` 套给舞台控件；runner 内联同值。**跨 bundle
  不能 import，两处值必须人肉同步**（moon test 无法读文件做漂移断言）。
- **顶栏动作 = `topbar_action` 芯片**（ide_chrome.mbt）：24pt 高 + Caption 13pt，
  `on_click : Msg?`（None=禁用态弱文字）；宽由 `topbar_chip_bound`（ASCII 8.0/
  全角 13.0 + 内垫 20）算，`topbar_actions_width` 与拖拽区共用。
- **`action_chip(label, msg, ChipTone, height)`**（ide_chrome.mbt）：Quiet/
  Primary/Ghost 三态，宽 = `chip_label_width`（估宽×1.05+20）。高度预算按
  芯片算的容器（AI 决策条、审计卡）**必须**用它而不是 `@views.button`
  （36 实渲 vs 24 预算）；`decision_bar_height` 已同步为 24+4+24 / 22。
- **`wrap_text_lines`/`hint_lines_view`（ide_chrome.mbt）**：拉丁按词、CJK
  逐字贪心换行（估宽口径同 text_estimate_width）。长提示（英文 500-800pt）
  渲染必须折行——`@views.text` 会自己长宽溢出容器；`empty_hint` 签名改为
  `(label, width, height)` 最多 3 行。紧凑条（决策条错误行/gate_hint/代码
  脚注）走 `fit_label` 截断，不折行（高度预算单点）。设置对话框的 key_hint/
  compile 可达性/草稿提示已接换行块。
- **AI 浮动层居中**：`ai_floating` 的 AiCenter 锚 = 左右对称权重 spacer
  （旧实现贴中心列左缘，破断实测偏 22pt）；与药丸同一纪律。
- **回归网**：`app/ui_regression_wbtest.mbt`——AI 卡居中（按卡矩形宽匹配 +
  中心对齐）、舞台产品主题（空文本标签填字后查舞台区深色文字）、换行器
  单测、芯片宽单调性。两条关键断言已故意破坏验证会红。
- **验证器陷阱（新）**：`moui/core` 加公共 API 后 `checks/api-surface-report.json`
  与 `tools/moui/validate_api_surface/main.mbt` 的 max_lines/max_pub_lines
  **都要 +**（generate-repo-docs --write 对超限是报错不是自动抬）。

## web 入口实机验证工作流（2026-09-29 实测）

- index.html 的相对路径假设：`../.mooncakes/wzzc-dev/moui_web_renderer/
  runtime.js` 与 `../../../_build/wasm-gc/.../web_wasm.wasm` 均相对
  `web_wasm/`。workspace 成员（wzzc-dev/*）**不在** `.mooncakes` 里（在
  仓库根目录作为 workspace 成员），直接 `python3 -m http.server` 于
  web_wasm/ 会 404。**staging 布局**：`/tmp/stage/moui_studio/
  web_wasm/index.html` + `.mooncakes/wzzc-dev/{moui,moui_web_renderer}`
  符号链接到仓库对应目录 + `_build/.../web_wasm` 符号链接，于 stage 根起
  服务，URL `/moui_studio/web_wasm/index.html`。runtime.js 内部
  引 `../moui/backend/web/browser_runtime.js` 与
  `./canvas2d_runtime.js`，符号链接目录天然解析。
- 命令面板/对话框类 presentation 打开瞬间有渐显动画：截图测对比度前先等
  ~1s 稳定，否则拍到半透明中间帧误判。
- ZCode IAB 截图实测：1280×832 视口与桌面截图同尺度，逐点取样对比度
  可复用 artifacts/studio-analysis/contrast.py 的模态背景+字形极值法。

## v4 IDE 壳重写（2026-09-30 实测，五个布局陷阱 + 四路派生）

### 布局陷阱（本次所有视觉缺陷的根因，改壳前先读）

1. **`ContainerBox` 会把子节点居中并收缩到子节点尺寸**
   （`moui/views/layout/layout_views.mbt:135-151` 用 `first_child_size`，
   `:233-256` 做居中）。`container(column(...))` 只要内容比容器矮，整列就被
   **垂直居中**——表现是「窗格头浮在面板中间」。**对策**：每个窗格/列容器
   显式 `.frame(width=w, height=h)`。
2. **带权重的 spacer 只有在 flex 父节点主轴尺寸确定时才拿得到 slack**。
   `@views.row([a, spacer(weight=1.0), b])` 量出来只等于子节点之和，spacer
   拿到 0 slack，随后整行被容器居中——顶栏内容因此挤在窗口中间。
   **对策**：`.frame(width=W)` 钉住行宽。统一走 `app/ide_chrome.mbt` 的
   `fill_row(cells, width, spacing, align)`（`panel_head` / `kv_row` /
   `tree_row` / `status_cells` / `pane_head` / `pane_foot` / `category_bar`
   / `context_*` 都已改用它）。**新增任何带权重 spacer 的行都必须定宽。**
3. **`.align()` 必须写在 `.frame()` 之前**。`mod_aligned_rect`
   （`moui/core/modifier_layout.mbt:190-197`）把 `w` 算成
   `min(bounds.w, child.w)`，`AlignModifier::layout` 又把自己量成子节点尺寸，
   所以 `.frame(...).align(...)` 里的 align **永远拿不到 slack，是静默空操作**
   （部件会贴在左上角）。仓库既有正确写法见
   `examples/mo_desktop/app/view_overlays.mbt:117-120`。
   **但贴底/贴右更稳的写法是「权重 spacer + 定高子节点」**（AI 浮动层即此，
   见 `app/ide_ai.mbt` 的 `ai_floating`）——不依赖 align 的尺寸语义。
4. **`divider` 的轴向**：在 **row** 里用 `axis=Vertical`；在 **column** 里用
   默认 Horizontal。column 里放 Vertical divider 会量成整列高并盖住兄弟
   （图标栏曾因此被画成一条窄条）。
5. **`scroll_view` 给子节点的是无界约束**，子节点量不到视口宽。
   画布类子节点必须由调用方传显式宽度
   （`blocks_canvas(..., width, height, ...)` 的 `width` 就是为此加的；
   原先写死 470 会溢出到隔壁面板）。

### 本次真实缺陷（不是风格问题，都是逻辑错）

- `update_shell.mbt` 的 `set_workspace` 通配臂原先写
  `(other, _) => other`，导致**任何工作区切换都静默返回当前工作区**。
  正确写法 `(_, requested) => requested`。三处布局测试才暴露出来。
- `console_pane` 直接渲染 `line.text`（i18n 键原文）而非 `text(t, line.text)`。
- **撤销「合并」与「留痕」是两件事**：`with_undo_point` 的 key 既当
  合并键又当留痕依据，会把连插两个控件粘成一步撤销（既有
  `undo depth is capped` 测试抓到）。拆成两个入口：
  `with_undo_point`（可合并的连续编辑：move/resize/text/items/rect/rename）
  与 `with_recent_undo_point`（离散动作：insert/delete/duplicate/template/handler，
  coalesce key 为空所以永不合并）。

### 四路派生（事件 → 审计 / Console / 最近修改 / toast）

- **接受/拒绝提案**：`audit + log + recent(by_agent=true) + toast` 四路都发。
- **真编译**：启动记 Console；完成记审计（失败带诊断文本）。注意
  `CompileDiagnostic` 字段是 `severity/code/file/line/column/text`
  （**没有 `message`**）。
- **运行**：启动在 `start_run` 记一条（带 handler 标签）；**终态只在
  `merge_run_back` 记一次**——tick/单步/事件回灌都汇合到这里，散在各调用点
  会重复计数刷屏。副作用闸门用 `AuditWarn` 卡，且要判重
  （`already_gated`，否则每次 tick 压一条）。
- **IR 编辑**：最近修改挂在 `with_undo_point*` 单一漏斗；判定与撤销点同源
  （签名没变就不记），no-op 不入账。
- `LogLevel` 构造子是 `LogInfo/LogWarn/LogError`（**不是** `Info/Warn`）。
- `RunStatus` 是 `Running/WaitingGate/Completed/Failed`（**不是** `AwaitingGate`）；
  `RunState.error : LangError?` 要经 `error_message(t, error)` 转文案；
  `Gate` 字段是 `kind/prompt/payload`。

### AI 避让带（对齐设计稿 `syncAIRes()`）

中心列拆成**上下两段**（`app/ide_root.mbt`）：内容段拿 `row_height - band`，
浮动卡段拿 `band`。**不能**在 `stack` 里给子节点改高度——stack 给每个子
整帧，内容仍会被撑满。`ai_avoidance_band` 与 `ai_card_height` 同源计算，
停靠/药丸态返回 0（它们不遮内容）；卡高超过行高 60% 时也返回 0（避让只会
把内容压没）。

### 测试基建

- 壳布局测试在 `app/shell_layout_wbtest.mbt`（白盒，headless
  `new_program_with_dimensions` → 从 draw_commands 读文本/矩形）。
  新增覆盖：三列几何、工作区切换、底栏页签、避让带契约、空舞台、
  上下文页签、命令面板过滤、模态宿主、对齐夹取、toast 上限、split 夹取、
  树分组/过滤、IR↔行双向映射、最近修改计数。
- **树分组行的 `label` 是空串**，真正的标签是 `node.group`
  （`window`/`controls`/`handlers`/`variables`/`data`），渲染时才经
  `tree_group_label_key` 翻译。测试别按中文名找分组。
- **从 draw_commands 里按「宽度/高度」启发式反推区域不可靠**：中心列
  （整行高）与内容段（行高 − 带高）是等宽矩形。断言结构契约（用
  `ai_avoidance_band` 算出边界）比猜矩形稳。根容器是 1280×800，
  任何「宽度 > N」的过滤器都会先命中它。
- `println` 在通过的 MoonBit 测试里被吞掉——探针要 `fail("...")` 才看得见。
  且 heredoc (`<<'EOF'`) 会原样写入 `\{...}`，字符串插值在测试文件里
  要么用 `+` 拼接要么用 Python 写文件。
- 测试里 `assert_eq(x.pending, None)` 不可用（`PendingProposal` 无
  `Debug`/`Eq`）——写 `assert_true(x.pending is None)`。
- `update.mbt` 已拆至 994 行 + `undo_history.mbt` 241 行（原 1226 越过
  1200 行硬上限）；`i18n_catalog_generated.mbt` 的 generated 预算
  从 1566 提到 1786。

### 布局陷阱 4：`@views.button` 的 `width`/`height` 是**最小值**

`moui/views/button/button.mbt:161-182` 里
`content_height = max(self.min_size.height, measured.height + padding_vertical*2)`，
`padding_horizontal = spacing_scale.lg (16.0)`、`padding_vertical = sm (8.0)`
（`SpacingScale::default()`，`moui/core/theme.mbt:355`）。所以
`button(width=72, height=26)` 实际渲染成**高 36**，文字比声明宽还会自己长大：
实测「解释这个程序」量到 92.8 宽却塞在 72 的按钮里，顶出 AI 卡片边缘。
**需要精确尺寸时手搓** `container(center(text(...)))`（见 `app/ide_chrome.mbt`
的 `text_chip` / `icon_button`）。左栏「快速插入」按钮就是这么从 36px 缩回
26px 的（原来被底栏裁掉）。

### 布局陷阱 5：无 `background` 的 `@views.container` 会**刷一层不透明底板**

`moui/views/container/container.mbt:14-60`：`background is None && theme is None`
时走 `ambient = Some(variant)`，paint 期按环境主题的 Base 变体刷子填充。于是
「纯定位用」的外层 `container(child, width~, height~, padding=0.0)` 会把整帧刷成
面板色。**症状极具迷惑性**：布局全对、绘制流里文字都在、屏幕上却一片空——
AI 浮动层的外层包装就这么把空舞台的引导语和三个模板按钮整片盖掉了
（绘制流实测：`[119 TEXT 从零开始…]` 之后紧跟 `[128 RBRUSH y=41 h=694]`）。
**对策**：纯定位/纯占位的外层用 `@views.center`（无 paint）或显式
`background=transparent`；只有真的要底色时才用 `container`。
回归测试：`"floating AI layer does not paint over the workspace"`
（断言「舞台文字之后不得出现横跨中心列且高 > 400 的实心矩形」，已用回退验证
过它确实能抓到）。

### composer 模式段（设计稿 `#modeSeg`）赋予了真实语义

设计稿第 1215 行的模式段只切 `.on` 高亮、没有行为。本实现让它真正分流
「发送」（`ComposerRun` → `composer_run(model)`，`app/update_ai.mbt`）：
`解释` → 既有 `ExplainHandler`（本地确定性讲解）、`修复` → 既有
`RestoreCodeDraft`（草稿回到 IR 规范渲染）、`生成` → 清空控件与子程序后走
**同一个** `GenerateProposal` 校验链、`修改` → `GenerateProposal`。
**只改入口路由，不新增执行路径**。
「解释」有个坑：`local_explanation` 依赖 `current_handler`，没选中子程序时恒为
空（点了没反应）——所以先按左栏点选同一语义选中第一个子程序再讲解。

### hero 态（空舞台）

`ai_hero(model) = workspace is WsEmpty && !ai_pill && !(ai_anchor is AiDocked)`。
卡宽 `min(width-20, 700)`、贴上方（权重 42:58 的两个 spacer）、多一行
`HERO_HINT_HEIGHT = 30` 的示例指令芯片（点击只 `SetPrompt` 填入，不直接执行）。
两个连带修正：
- **带高为 0 时不能走「上下两段」**。浮动层原来被塞进 0 高的段里整块消失。
  现在 `band > 0` 用两段式（内容段 + 卡段，给浮动卡让位），`band == 0`
  （hero / 药丸 / 停靠）改用 `stack` 覆盖。回归测试
  `"hero and pill overlays still render when the band is zero"`。
- 空舞台引导语在 hero 时**顶部对齐**（定长 28px 前导 spacer，不用权重——权重
  份数随窗口高变化，窄窗口会把引导语推回卡片底下），否则 hero 卡盖住三个
  模板按钮＝「点了没反应」。回归测试
  `"empty stage guidance sits above the hero card"`。

### 维护基线工具：生成文件按内容标记豁免

`i18n_catalog_generated.mbt` 涨到 1820 行越过了
`validate_maintenance_baseline` 的 1800 行「手写文件」阈值。修法不是再抬常量，
而是让 `repo_scan_helpers.mbt` 的 `generated_source_text(text)` 识别头部
`DO NOT EDIT` 标记并跳过——生成文件体量已由 `checks/source-file-policy.json`
的 `generated` 清单显式棘轮（含生成器与 `--check` 命令），按手写阈值再报一次
是重复管辖。注意该工具自身的 `line_budget_catalog.mbt` 给
`repo_scan_helpers.mbt` 定了 115 行、`line_budget_checks.mbt` 96 行的预算，
改动要留在预算内（`skipped_directory_name` 已压成一行数组 `contains`）。

### 死 UI 陷阱：渲染层齐了但**没有生产者**

本次最值得记的一类缺陷。`AiCard` 结构、`ai_card_view` 渲染、`fold_bar`
计数、`#seeAll`、药丸的「待审计 N」全都写好了，但 `push_ai_card`
**一个调用方都没有**——`ai_cards` 恒为空，于是整条会话线程（设计稿 AI 层
的核心）永远不会出现。这类「死 UI」不会被布局测试抓到（渲染函数本身是对的），
也不会被现有测试抓到（没有测试断言卡片真的会产生）。

**识别方法**：对每个 `pub fn` 在 `app/` 内做一次调用方检索
（`grep -rn "<name>" app/*.mbt`），只出现在定义处 = 死代码。
`CycleAiAnchor` 一度看起来也是死的，其实在 `update_shell.mbt:65` 有处理器
——检索要覆盖 `update*.mbt`，别只看渲染文件。

**修法**：把生产者接到**唯一真实漏斗**上。提案的唯一入口是
`proposal_from_completion`（假模型与真实 provider 共用），线程卡的生成就
挂在那里；采纳/拒绝时由 `settle_newest_thread_card` 把最新未处理卡标为已处理
（只动最新一张——一次提案对应一张卡）。这样线程是**事件驱动**的可见记录，
不是摆设。

### 高度预算必须**单点计算**

同一轮里踩到的第二个坑：线程区高度在视图层用「可用高度 − 常数」，在
`ai_card_height` 里用「卡数 × 6 + 40」，两处各算一份。线程卡一多，视图层的
预算就超过卡片自身帧高，把 composer 和决策行顶出可视区（实测**一张** diff 卡
就够：`发送` 底边 846 vs 卡底 722）。

**对策**：抽 `thread_area_height(model)` 作为唯一来源，`ai_card_height`
= `card_chrome_height(model) + thread_area_height(model)`，视图层直接用它，
并**去掉二次钳制**（`height=thread_height.min(280.0)` 这种重复 clamp 改了上限
必漏一处）。回归测试：`"thread cards never push the composer out of the card"`
（已用回退验证过能抓到，报 `发送 falls outside the card`）。

### i18n `setdefault` 陷阱

给已存在的 key 追加新值时用 `dict.setdefault` 会**静默保留旧值**：
`app.ai.dock` 原值是「停靠右栏」，按设计稿想改成「侧栏」的意图不会生效，测试
按新值断言就会假失败。加 key 前先查现值（`grep` 生成目录或直接读 JSON），
要么显式赋值要么接受现值。


### 无边框窗口：不要自绘信号灯
`transparent_titlebar=true` 只做三件事：标题栏透明 + 标题隐藏 + fullsize content
view。它**不隐藏系统信号灯**——关闭/最小化/缩放三个圆仍然浮在左上角。所以
app 层再自绘三个点会叠成六个，必须让出 `TRAFFIC_LIGHT_INSET = 78.0`（与
momark / mo_workbench 同一值，这是 AppKit 固定几何而非主题值）。

推论：自绘窗口按钮是**死 UI 陷阱**。`WindowRequest` 没有 zoom/maximize 变体，
自绘的缩放按钮没有任何可用的后端请求；而关闭/最小化虽然真能走通
（`WindowRequestQueue` → `apply_window_request`），但既然系统信号灯已经提供
且自带悬停/键盘可达性，就没有理由重造。**结论：用系统的三个灯，只保留拖拽区。**

### 拖拽不能走 WindowRequest
`Window::drag_window` 依赖 `NSApp.currentEvent`，而 `drain_window_requests` 只在
`about_to_wait` / `window_event` 里跑，**不在 `mouseDown:` 内**——排队式拖拽拿到
nil event，返回 -1 / `RequestError::Ignored`。拖拽必须在 AppKit 事件内同步执行
（`performWindowDragWithEvent:`），见 `moui_webview/backend/macos/webview_host.m:311`。
`docs/invariants.md` P10 亦明确 drag decode 属平台本地。

### 校验：绘制命令级断言有盲区
「顶带里不许有小圆角方块」这类断言抓不到自绘信号灯——圆点会和整条顶带合并成
一次填充，`shell_rects` 里看不到独立方块（实测：故意加回圆点仍通过）。改用
**可观测代理**：提示文字的 x 必须 >= `TRAFFIC_LIGHT_INSET`（把 inset 改成 0
立即报 x=45）。写断言后必须**故意破坏一次**确认它会红，否则等于没写。

### 「写死宽度 + 本地化文案变长」是本项目复发最多的缺陷族
已复发：状态栏 112pt/格、代码页脚 62/68pt 按钮（截成「按 IR 重渲」）、
面板脚注 90pt 计数（截「2 个控件」）、右栏 tab `(width-12)/5`（正好占满无内垫）、
hero 示例句三等分。**逐点补宽治不了根**——用枚举式扫描：
`app/shell_responsive_wbtest.mbt` 的 `"no drawn label is narrower than its own text"`
扫过三工作区 × 三种宽度下**所有** `DrawText`，比 `frame.size.width` 与
`text_estimate_width(text)`。新加任何带 `width=` 的文字都会被它覆盖。

要点：`text_estimate_width` 比真实字形窄约 3%（实测估算 148.6 / 渲染 143.8 时
反过来也会出现估算偏大），所以**断言**用它 1.0 倍（宁可漏报），而**分配空间**
时需求侧乘 1.05。

### 断言必须故意破坏一次
本会话两次抓到「写了断言但抓不到回归」：
1. 「顶带里不许有小圆角方块」——自绘圆点与顶带合并成一次填充，`shell_rects` 看不到；
2. 圆形 `fill_row` 里等分时，按比例算出的 `cell` 根本没被用上（`fill_row` 自己等分）。
两次都是**故意把代码改坏**才发现的。写完断言立刻改坏一次确认它会红。

### 放不下就少放几条，不要压缩
窄窗（卡片 ~460pt）里三条中文示例句放不下。等比压缩会把文字截成半个词——
比不显示更糟。`hero_hints` 改为按自然宽**贪心放置**（一条都放不下则留空行，
高度预算不变，排版不跳）。

### 分类轨竖排（设计稿 #catbar）
原来是画布上方的横排芯片条；改成画布**左侧** 86pt 竖排轨（色点 + 名称 +
选中项 2pt 强调边）。两个理由：① 设计稿就是这个形态；② 横排白吃 30pt
画布高——积木视图纵向最紧，把分类移到画布旁边的空白里等于白赚。
分类轨**永远在**（没有选中子程序时全灰）：「今天没有块」本身就是要传达的信息。

### 测试陷阱：SetWorkSpace 是**切换**不是设置
`SetWorkSpace(WsVisual)` 在已经是 WsVisual 的模型上等于「点当前项」→
收起成空舞台，画布整个消失。测试里想表达「可视化工作区」就直接用
`initial_model()`（默认就是 WsVisual）。这个坑让本会话多花了两轮排查。

### 测试陷阱：同名字符串会在多个面板出现
「变量」「事件」既是积木分类名，也是左栏程序结构树的节点名。按文字找位置
时必须同时按**面板 x 区间**过滤，否则树行会被算进分类轨，报「不在同一列」。

### 文字宽度估算的真实标定：主题正文是 16pt，不是 13pt
`text_estimate_width` 用 ASCII 7.9 / 全角 13.0。实测（w=1280 的积木脚注）
声明宽 300.8 时实渲 300.8，估算 294.4 → **估算偏窄约 2%**。
所以：
- **分配**空间：需求 = `text_estimate_width(...) * 1.02`（或留固定余量）；
- **截断**（`fit_label`）：预算乘 `LABEL_WIDTH_SAFETY = 0.98`。
两个方向都要留余量，2% 在长中文句子上就是 5-6pt 的越界。

### 别再按「以为的字号」折算
`fit_label` 一度写 `scale = 12.0/13.0`（以为积木按 12pt 渲染），实际正文
16pt——凭空折算让预算**虚高 8%**，结果是「明明截断了却还是溢出 5pt」。
要用字号就**实测**（`run.font.size`），不要推理。

### 扫描的第三个盲区：完全没有裁剪区的文字
`PushClip` 配对的扫描只看得到**有**裁剪区的文字。窗格脚注那种直接画在
容器里、外层没有 `PushClip` 的文字会被**整个跳过**——实测积木脚注右缘
1013 越过窗格右缘 1008，扫描却是绿的。
现在 `"no drawn label is clipped by its own container"` 三段互补：
① 有裁剪区 → 比裁剪区；② 无裁剪区 → 比窗口（`overflow_report`）；
③ 跨窗格 → 比窗格右缘（`width - RIGHTBAR_WIDTH`）。

### `on_hover`（框架新增，2026-09-30）
`View::on_hover(Self[Msg], (Bool) -> Msg) -> Self[Msg]`：进 `true`、出 `false`。
透明观察者——不设 role、不进焦点、不抢指针捕获，只在**状态真的翻转**时发消息
（runtime 每次指针移动都投递 `Move`，不做翻转判断会把 update 循环刷爆）。

**实现要点（load-bearing，别改成 ViewStateSlots）**：必须把悬停态记在
`ctx.state.hovered`。runtime 只对「已上报 hovered/pressed 的子树」合成离开用的
`Exit`；用私有 slot 记录的话**永远收不到离开事件**，悬停会永久黏住。

**已知既有缺陷（未修，不属本次范围）**：`ModifierViewNode` 的 `semantics()`
会**替换**子节点的 role，所以 `.semantics_role(TreeItem).on_hover(...)` 读回来是
`None`。`on_secondary_tap` / `on_file_drop` 同样如此，不是 `on_hover` 引入的。
runtime 语义树本身不丢子节点（Transparent 节点会让子节点穿过），实际影响有限。
要修得改所有 modifier 的既有行为，需要单独的 RFC。

**给 core 写注释的坑**：`validate-api-surface` 会把 `moui/core` 下**所有**（含注释）
文本按子串匹配内部标识符（`ElementNode`/`ElementTree`/`RenderNode`/`DirtyFlags`/
`RuntimeState`/`AppRuntime`）。文档里描述行为即可，别把 runtime 内部符号写出来。

### 沉浸式窗口的关闭/最小化方式（无需自绘按钮）
`transparent_titlebar` 保留原生信号灯（红黄绿）→ 鼠标路径齐全。键盘路径也
齐全：macOS 后端在窗口就绪后安装**默认菜单栏**
（`macos_app_handler.mbt:83-88` 的注释），Cmd+W / Cmd+M 由此可达，不需要
app 自己装菜单（`on_ready` 是给**替换**默认菜单用的，装早了会被覆盖）。
所以「隐藏标题栏后怎么关窗」不需要框架新增能力——先确认原生路径是否已存在，
再决定要不要动框架。

### canvas 是**不可命中**的：需要悬停就必须用逐行单元
`@views.canvas` 没有 `hit_test`，是纯绘制节点。想做「悬停某一条看详情」时，
`on_hover` 只给 `Bool`（不给指针位置），所以「在 canvas 里按 y 反查」这条路
**走不通**——只有点击方向能用 `on_tap_with_frame` 的 `position` 硬算。
正确做法是把内容拆成**逐行/逐项的可命中单元**，每项各自 `on_hover`/`on_tap`，
命中判断交给框架。附带好处：与相邻列的对齐变成天然（同一 `height` 即可）。

### 只断言 update 状态是不够的
「update 改了字段」和「视图读了字段」是两件事。本会话实测：把 `hover_path`
从竖条与代码行的绘制里删掉，所有 update 断言仍然全绿，界面毫无反应。
补一个**绘制指纹**（`paint_signature`，把每条 `DrawCommand` 压成短串再整体比较）
就能抓住：悬停态与静止态的指纹必须不同，且悬停指纹必须**不同于**驻留指纹
（否则说明瞬态被当成了驻留）。

### 「隐藏」必须有对应的「显示」入口
`pane_live` / `pane_blocks` 这类可见性开关，一旦单侧隐藏就走单窗格分支，
**必须在该分支里留一条恢复入口**（设计稿的 `#btnAddLive`/`#btnAddBlocks`）。
否则「隐藏此窗格」= 永久丢失，用户只能重启。这类缺陷不会让任何测试变红，
只有真的点一遍才发现——所以每个「隐藏/关闭」控件都要问一句「怎么回来」。

### 无边框拖窗：区域是**状态**，不是命令（2026-09-30 定案）
最终走 **Option B**：`moui/services` 里的 `WindowDragRegionSource`，
app 经 `environment.services().platform().window_drag()` 拿到（非可选，
未接线时是空实现，所以 app 侧无需分支）。

为什么**不**加 `WindowRequest` 变体（原以为是首选）：
1. **泄漏（决定性）**：`drain_with_handler` 会为每个 request 往
   `WindowRequestQueue.completed` 塞一条完成记录，而**没有任何生产代码
   排空它**（只有测试和 service 内嵌队列调 `drain_completed`）。按布局帧
   发一个 request 会无限增长。
2. 队列在 `moui/backend/common/lifecycle`，app 碰不到（P9）。
3. 队列文件 209/210，去重逻辑塞不进去。
4. 语义：拖拽区是**声明式状态**（最新值获胜），不是命令。

关键性质：`set_region` 只在几何**真的变化**时推进 `revision`，宿主按
revision 去重 → 逐帧重复声明零原生调用（测试钉了 60 次重发 = 1 次调用）。
两个易漏点：窗口还没建就声明 → 重试而非记为已完成；revision **按 surface**
跟踪，否则第二个窗口收不到。

**接线要点**：`WindowDragRegionSource` **同一个实例**必须同时给
`program(environment=@macos.app_environment(window_drag=Some(src)))` 与
`@macos.MacosHostAppOptions::new(window_drag=Some(src))` —— app 侧写、宿主侧读。
两边各建一个的话永远拖不动（本会话踩过同类「建了但没传进去」两次）。

**仍未自动验证**：没有测试能把真实 `NSEvent` 送进 `mouseDown:`（`moon test`
里无法合成 AppKit 鼠标事件）。按下→`performWindowDragWithEvent:` 这段只有
C 层自测 + 外部 AppKit 探针覆盖，**需要在真窗口上手拖一次确认**。

### 截图脚本的坐标坑（别把脚本 bug 当成 app bug）
用 CDP 点击时，`Input.dispatchMouseEvent` 收的是 **CSS 像素**，而
`Emulation.setDeviceMetricsOverride(deviceScaleFactor: 2)` 之后截图是 **2×**
设备像素。截图里量到的坐标必须 **÷2** 才能喂给 `dispatchMouseEvent`。
本会话据此误判了两次「页签点不中」——实际是脚本坐标错，app 没问题。
右栏 5 个页签的中心（1280 宽窗口）可由常量算出，别靠肉眼估：
`start = 1280 - 272 + 6`，`cell = (272 - 12 - 4*3) / 5`，
中心 `= start + i*(cell+3) + cell/2` → 1039 / 1091 / 1144 / 1197 / 1249。

### 沉浸式标题栏：**合并**成一条，不要叠两条（2026-09-30 返工）
第一版做成「26pt 窗控带（居中一句提示文字、底色 studio_window_background）
+ 40pt 顶栏（ide_panel）」两条。用户截图一眼就看出「最上面的窗口边框不沉浸」：
两截不同底色在交界处形成色缝，上一条一半是空的，读起来像「顶栏上面多贴了
一条不属于窗口的东西」。**IDEA 的形态是一条**。

改成：`WINDOW_CHROME_HEIGHT = 56.0` 表示**标题栏总高**（不再是「顶栏之上额外
加多少」），沉浸态 `ide_top_bar` 自己按 56 渲染、左侧让出 `TRAFFIC_LIGHT_INSET`，
`window_chrome_bar` 整个删掉。`ide_root` 里 `window_bar = WINDOW_CHROME_HEIGHT
- TOPBAR_HEIGHT`（只补差额）。

配套教训：
- 动作按钮在更高的带子里**重新垂直居中**，所以标签只下移增量的一半（8pt 不是
  16pt）。测试若按「下移一整条带高」断言会误报。
- `on_hover`/`align` 那些摆放纪律不变；`fill_row` 仍必须显式定宽。

### 拖拽区**必须避开右侧动作簇**（否则按钮点了变成拖窗口）
AppKit presenter 命中拖拽区时直接 `performWindowDragWithEvent:` 并 return，
事件**不再进入运行时**。所以拖拽矩形一旦盖住运行/单步/编译，点它们就是拖窗口
——「按钮点了没反应」，且**只在原生无框窗口复现**，绘制断言全绿。

做法：`topbar_drag_width(model, t, width) = width - 10 - topbar_actions_width(...)`，
与渲染共用同一计算源（右内垫 10 + 动作簇贴右，所以这个值恰好是动作簇左缘）。

**估算必须取上界，不能取「精确估计」**：`text_estimate_width`（ASCII 7.9 /
全角 13）在**加粗 16pt 按钮标签**上偏窄很多——「编译 MoonBit」估 89.2、实际
绘制 97.6（窄 9%）。按 1.02 补偿后算出的右缘 884.8 仍然盖住左缘 876.4 的运行
按钮。改用 ASCII 10 / 全角 16 + 内垫 32 的宽松上界后，中英双语各宽度都有
约 41pt 余量。两种误差代价极不对称：高估只少几个点可拖，低估直接废掉按钮。

### `shell_rects` 必须收 brush 变体（第三类扫描盲区）
`@views.button` 画的是 `FillRoundedRectBrush` / `StrokeRoundedRectBrush`，而
测试助手只收 `FillRect` + `FillRoundedRect`。后果：所有「按钮盒在哪」的断言
静默落空，症状伪装成「测试自身找不到盒子」而不是「拖拽区盖住按钮」——本会话
因此真的把一个线上缺陷漏过去一轮。**给绘制命令写断言前，先把变体收全。**

### 断言「覆盖」要比**按钮盒**而不是**标签**
标签两侧各有 16pt 内垫。只比标签左缘会漏掉「拖拽区盖住按钮左半内垫」——落在
内垫上的按下照样被拖拽区吃掉。边界取盒子左缘。这个盲区是本会话写完「双语
测试」后自己探出来的（先用标签比，故意破坏时英文那侧没报）。

### 药丸收起态：居中 + 定位层不许铺底板
`shelf`：设计稿 `#aiLayer` 是 `left:50%;transform:translateX(-50%)`，`.pill`
只改宽度与贴底距离，**不改水平锚点**。原实现写死 180 宽 + 只放右侧权重
spacer → 贴在中心列右下角（实测中心 x≈958，列中心 645，偏 313pt）。
改成左右对称权重 spacer 居中；宽度按内容累加（中英「待审计 / To review」
宽度差近一倍，写死必然一侧截断或留白）。

定位外层**不能用无背景 `@views.container`**——它回落到环境 Base 刷子（不透明
面板色），整帧被刷成一块底板。`ai_floating` 的注释里早记过这个坑，药丸这条
路径漏改了。定位-only 一律用 `@views.center`。

**注意**：那条 slab 断言在 Web 目标下不复现（实测中心列填充只有 398/321 宽），
它主要在原生沉浸窗口可见。所以测试钉的是**结构**（外层无表面绘制），不是
某次渲染的像素。

### `SwitchLanguage` 是切语言的消息名（不是 ToggleLanguage）
写跨语言测试时先 `grep` 消息名，别猜。

### 第四类扫描盲区：**未被裁剪 ≠ 没被遮挡**
`overflow_report` 只查「未被裁剪的文字有没有越出窗口」，判据合理（滚动区内容
越出视口是设计如此）。但它漏掉另一半：**窗格头根本不在裁剪区里**（实测
`depth=0`），所以它的文字越出窗格后会被**后面的兄弟面板盖住**——看起来像被
裁掉，实际是压在下面。窗口边界内、又有绘制命令，两道既有扫描都抓不到。
修法：按「这段文字属于哪个窗格」直接比窗格的 x 范围（见
`pane head text stays inside its own pane`）。

### 同一行的几个格子**绝不能各自算预算**
窗格头的宽度分配第一版拆成两处：`pane_head` 按 `trailing` 算一次动作占位，
一个独立 helper 又按「窗格宽 − 内垫 − 动作 − 140」算尾巴预算。两处口径一
不同就再次溢出——新测试立刻在 1440 宽度抓到尾巴画到 1253.2 而窗格右缘只有
1166。**整行只能有一个分配函数**（现在是 `pane_head_layout`，纯函数、可直接
断言），建视图的那一层不做任何算术。

### 按钮宽度：`@views.button` 的 `width` 是**最小宽**（第三次踩）
`content_width = max(declared, measured_text + padding_horizontal×2)`。
写死 64 的「应用修改 / 删除语句」实际各要 92.8（标签 60.8 + 内垫 32）。
配合 `draft_w = width - 190` 的写法，真实总宽 = `w + 22`，删除按钮盒实测
`932..1028` 而窗格右缘 1006——**超出 22pt**，截图里「删除语句」只露出左半。
修法：`button_label_width(label)` 统一算，输入框拿剩下的空间（顺序反过来一定
挤掉按钮）。

**估算口径要按字号分组**：`text_estimate_width`（ASCII 7.9 / 全角 13.0）是给
**正文**标定的；加粗 16pt 的按钮标签上「应用修改」估 52 实际 60.8（窄 17%）、
「编译 MoonBit」估 89.2 实际 97.6（窄 9%）。所以按钮专用 `8.4 / 16.0` 上界。
**取上界是刻意的**：估宽只是内垫多几个点，估窄会让按钮自己长出去把兄弟挤出
面板（且只在特定语言/宽度复现）。

### 断言「按钮塞得下」要比**按钮盒**，不能比文字画框
`@views.text` 只会涨不会缩，文字自己**永远**塞得下——拿文字画框断言「没溢出」
是个不可能失败的断言。第一版就这么写的，故意破坏时一次都没红。必须比按钮盒
（`shell_rects` 里包住文字、且比文字宽的那个）。

### `workspace.mbt` 1162 行 → 拆成 `workspace.mbt`(593) + `code_view.mbt`(578)
自然边界是「窗格外壳/宽度分配」与「代码视图/空舞台内容渲染」。

### 面板头尾部动作贴右缘：**标题不能吃满剩余宽**
`panel_head` 的权重 spacer 曾写 `weight=0.0`——它分不到 slack，右端剩下的
40pt 空白堆在动作**之后**，左栏关闭 ✕ 停在离右缘 40pt 处（实测 ✕ 中心
css x 221.8，面板右缘 281）。

修的时候踩了一个更隐蔽的坑：第一版把标题宽设成「面板宽 − 尾部预留」，
即**标题吃满剩余**。这样尾部确实贴右了，但那是标题宽度**碰巧**保证的——
spacer 的 `weight` 写 0 还是 1 都看不出来。实测：故意把 weight 改回 0.0，
那条「尾部贴右缘」的测试**仍然通过**，断言等于失效。

正确做法：**标题只占内容宽**（`text_estimate_width * 1.02 + 8`，再按可用宽
夹取），余量留给 spacer 去推。这样 `weight` 才是真正起作用的一环，改回 0
测试立刻红（`right=154.04 expected ~273`）。

教训一般化：**当一个约束由两处共同保证时，测试要能被每一处单独破坏。**
改完先问「我这次修的到底是哪一处」，然后只破坏那一处看它红不红。

### `panel_head` 的尾部预留宽必须按**实际控件宽**给
统一按 22 预留是错的：`count_badge` 是 56 宽，按 22 留会让它越出右缘
（实测监视面板的计数徽标画到窗口外，w=1440 时 x 1407 越出）。所以加了
`trailing_widths?` 参数，调用方声明真实宽。

### 去掉顶栏四色方块（用户要求）
`brand_mark()` 整个删除。它是设计稿 `<div class="logo">` 的占位 logo：无边框
窗口里紧挨系统红黄绿，四个彩色小方块挤在一行很吵，且不承载信息（产品名就在
旁边）。**注意：这是纯删除，不要给它写绘制断言**——我试过「顶栏左端有没有
成对小块」，但那个 logo 在绘制流里会合并成一次填充，断言抓不到（实测把 logo
加回去测试照样通过），属于不可能失败的断言，已删除。

### 清空选中：`ClearSelection` 必须同时清控件与子程序
`context_head` 在无控件时回退到 `current_handler`——只清 `selected_control`
的话右栏继续显示上一个子程序，用户点「清空选中」看到的是「内容没变」。
设计稿对应 `#clearSel`。没这个出口时用户只能靠「选中别的对象」离开，
回不到中性态。

### 积木窗格**跟随选中**（用户要求「只有在需要的时候才出来」）
判据是**选中态**不是「有没有块」：新建的空子程序也要显示窗格（用户正要在
那里加块），但没选子程序时一块都不该显示。`blocks_pane_wanted(model) =
pane_blocks && current_handler(model) is Some(_)`。

关键连带改动：`SelectControl` 必须**清掉 `selected_handler`**。否则点了一个
控件之后积木窗格还挂着（用户已经离开那段子程序了）。设计稿的树本来就是单选：
控件与子程序互斥。

`model.pane_blocks` 仍是用户显式开关，语义是「需要积木时把它关掉」，不能
反向把不需要的窗格打开。

**测试字符串坑又踩一次**：断言「积木窗格在不在」不能用「积木」二字——积木
分类轨里也有一个叫「积木」的分类项，`shell_has_text` 会撞上。改用窗格独有的
副标题前缀 `IR 映射`（整串会被 `fit_label` 截断成 `IR 映射 · …`，用前缀）。

### 删掉我自己发明的「单窗格恢复带」（用户指出）
之前为了让「隐藏窗格」可逆，我在只剩一个窗格时于它**头顶压了一条
「+ 另一个窗格」按钮带**。那是**我自己加的、设计稿里没有的东西**，凭空多
一条工具带还挤掉舞台高度。用户直接指出不要它。

设计稿的真实规则更干净（`#btnHideLive`/`#btnHideBlocks`）：
```js
S.live=false; if(!S.blocks) S.ws='empty';
```
**关掉最后一个窗格就进空舞台**，而空舞台自带 `#btnAddLive` / `#btnAddBlocks`
两个入口——恢复路径**只有这一条**，不在单窗格态另开一条。所以：
- 单窗格 = 那个窗格占满整列，不加任何带子；
- 两个都关 = 空舞台（`empty_stage`），它带恢复按钮。

**恢复按钮必须幂等「显示」而不是「取反」。** 新增 `ShowPaneLive` /
`ShowPaneBlocks`（赋值语义，对应设计稿 `S.live=true`）：空舞台出现时窗格一定
是关的，用 `Toggle*` 会让这条消息在别处（命令面板）变成「关掉它」，语义不可
预测。二者还顺带把 `workspace` 切回 `WsVisual`——空舞台可能是点图标栏
`SetWorkSpace` 收起造成的，那时只打开 pane、工作区还停在 `WsEmpty`，
用户点了按钮什么都看不到。

`ShowPaneBlocks` 还要**顺手选上第一个子程序**：积木窗格要 `current_handler`
非空才画得出来（`blocks_pane_wanted` 判据），否则用户点了「+ 积木窗格」
屏幕上只有 Live App，看起来就是没反应。

### 空舞台按钮宽度必须按内容算 + 折行
模板 3 颗 + 恢复入口最多 2 颗，写死 150 时整行 `5×150+4×10 = 790` > 1280
窗口下的中心列 724，最右那颗被面板裁掉（实测 `+ 积木窗格` 只露左半）。
改用 `button_label_width` + `empty_stage_button_rows` 折行：放不下就分两行，
不压缩（压到 ~140 会让「新建问候程序」6 个全角字贴边）。

### `shell_responsive_wbtest.mbt` 1225 行 → 拆出 `pane_lifecycle_wbtest.mbt`
自然边界是判据类型：前者是**响应式/溢出扫描**（视口 1440→1000，枚举所有
绘制文字找越界，「画得下吗」），后者是**交互状态机**（点一下之后谁该出现/
消失，「该不该画」）。9 + 9 个测试。

### 右栏头的 ✕ 是「关闭整个右栏」，不是「清空选中」（用户报的 bug）
上一轮我加 `ClearSelection` 时，把它放在了右栏头整行的**最右端**——而那里
正是「关闭面板」按钮该在的位置（左栏的 `#btnCloseLeft` 就在那儿）。于是
点它只是清了选中、面板纹丝不动，用户读到的语义就是「关闭右栏关错了东西」。

**位置即语义**：一个 ✕ 放在面板头右端，用户只会读成「关闭面板」。设计稿里
两者是分开的：
- `#clearSel` 是**对象芯片内部**的小 ✕（`.objchip` 里紧挨着名字）；
- 面板关闭按钮属于窗格头（`.pnhead` 右端）。

所以右栏头现在是三段：`对象名 + 清除✕ | 权重 spacer | 种类徽标 + 关闭✕`。
两个 ✕ 语义不同、位置不同，不能互换。

### 右栏原本**没有**收起能力（这次补上）
`right_visible : Bool`（左栏是「多视图 + 收起」所以用枚举，右栏只有一个视图，
布尔足够）。`shell_chrome_widths` 的 `right` 返回 `0.0` 表示收起，调用方
**不必区分**它是「用户收起」还是「窄窗口让位」——都是「不画右栏」。

连带两处：
1. `workspace_row` 里 `chrome.right == 0.0` 时**面板与它左侧的发丝线都不画**，
   否则中心列右边会留一条没有内容的竖线；
2. 重开入口在图标栏（`Columns` 图标）。它是**唯一**的重开入口，所以必须
   始终在场——不像左栏那两个图标是「多视图」互斥关系。

用 `SetRightVisible(Bool)` 显式布尔而不是 Toggle：关闭入口在右栏头（只可能
关），打开入口在图标栏（只可能开）；共用一个 Toggle 会让「点击目标当前
不可见」这类情况反向操作。

### 浏览器点击验证的坐标坑（又一次）
自动化点击两次打偏：一次点 `x=1272` 落在 ✕ 右侧空白，一次点 `y=234` 命中了
**AI 锚点图标**（把锚点切成了「右下角」）。教训：**别靠肉眼估图标栏坐标**，
先从截图里量出目标元素的实际中心（本次量到关闭 ✕ 中心 css x=1260.8，
面板切换图标在 y≈265 而非 234）。icon 栏是纯图标、没有文字锚点，估错代价
就是「测试看起来通过了但改的是别的东西」。

### 积木编辑从「底部编辑条」改为「链条内编辑卡」（用户指出旧布局不合理）
旧版选中块后在窗格底部弹一条 34pt 编辑条：输入框被「应用修改/删除语句」两颗
文字按钮挤到只剩 ~90pt（窄窗格只见「变量 序号 =」），且编辑区与块在视觉上
完全脱节。参考 Scratch/Blockly 的就地字段编辑口径重做：

- **画布在选中块处拆成上下两段**（`blocks_canvas` 各画一段），编辑卡作为
  真实视图行夹在中间——卡片永远紧贴被编辑的块，不占窗格固定高度；
  `blocks_body_height` 不再随选中抖动。
- 卡内 = 分类色徽章 + 全宽 text_field（Enter 提交）+ 三个 ghost 图标
  （✓ 应用 / ⧉ 复制语句 / 🗑 删除语句）。宽度预算必须从**卡宽**起算，
  从画布宽起算会让行比卡宽 4pt、末位图标顶出圆角。
- 复制语句（`DuplicateBlock`）：克隆语句插入同层下一位并选中之，进撤销栈。
- **按下不再即时选中**（`BlocksCanvasPress` 只建拖拽态）：选中决定拆分位置，
  手势中途换选中会让画布在手势进行时重构、指针捕获随元素重建而丢失；
  选中交给松手后的 tap / 重排跟随，草稿经 `select_block` 与新选中同步。
- 落槽指示线从绘制计划提为纯函数 `blocks_insert_mark`（链条坐标）：跨段的
  兄弟列表若让两段各自用子集矩形推槽位会算错位置；两段各按 `y_offset`
  换算本地坐标渲染。
- 拆段画布的 measure 不能再带旧整链画布的 `.max(160)` 高度下限（上段只有
  ~50pt，下限会在块与卡之间垫出空白）；短内容垂直居中用**列尾填充物**
  压住（scroll_view 会对短于视口的子节点居中）。
- else/end 等装饰块（path 为空）只高亮、不展开编辑卡。

已知遗留：text_field 的 DrawText 在 frame 内不裁剪（`moui/views/text/
text_input_paint.mbt`），长草稿的尾部字符会画出字段框、在卡片右缘露出
（web 渲染器实测；属控件层裁剪缺陷，修复应在框架层做 clip）。

## 2026-10-01 产品完善批次（死 UI 根治 / 语句插入 / 键位 / CI）

### 「死 UI」缺陷族的机制性根治（本轮最重要的方法论）

- **症状族**：`update` 分支写好了、视图也渲染了，但**全仓库没有任何地方构造
  过这条消息**——功能在运行时完全不可达。本轮实测确认 3 个：
  `Msg::Undo`/`Msg::Redo`（顶栏按钮在 v4 壳重写时删掉了，没人补入口）、
  `studio_commands()`（30 条 v4 命令表，零调用者）、
  `ToggleProviderSettings`/`CompileStopped`/`SelectBlock`/`SetBottomHeight`。
- **为什么 165 个测试全绿也抓不到**：测试直接 `apply(model, Undo)` **绕过 UI
  入口**构造消息，处理器逻辑正确 → 测试绿。**测「消息处理对不对」和测
  「消息有没有生产者」是两件事**，前者永远抓不到后者。
- **对策（已落地）**：`tools/moui/validate_dead_messages` +
  `checks/dead-message-catalog.json` + `scripts/validate-dead-messages.mjs`，
  注册为 pr profile 的 `dead message gate`。规则：受管辖枚举的每个变体必须在
  声明文件**之外**有构造点；排除 match 臂（`X =>` / `X(..) =>`）、限定引用
  （`@pkg.X`）、模式位（`is X` / `| X`）。白名单带 `reason` 且**会 stale**
  （变体一旦有构造点就报错要求删白名单）。
- **上线即再抓 4 个**（手工扫描漏掉的）：`SelectBlock` / `SetBottomHeight`
  （真死码，删）、`ToggleProviderSettings` / `CompileStopped`（**接线成真功能**
  ——后者接上早已存在却没人用的 `app.compile.cancel` 文案）。
- **结论**：这类缺陷不能靠「多写测试」兜住，只能靠「每个变体至少一个构造点」
  的结构性断言。

### 语句插入：从零写程序的断点（最致命的一条）

- **根因**：积木三条写回路径 `commit_block`（替换）/`duplicate_block`（克隆）/
  `delete_block`（删除）**都要求语句已存在**，`CreateHandler` 建的是空 body。
  分类轨**可点**（`on_tap(SelectBlockCategory)`）但处理器只改
  `selected_category` 一个高亮标志位，注释声称的「滚动到该类首块」从未实现
  （`scroll_view` 没有命令式滚动 API）。于是没有 AI、没有模板就**加不出一行逻辑**。
- **修法**：`app/statement_palette.mbt`（分类 → 骨架 → 插入）+
  `@blocks.insert_stmt_at`（**克隆后插入**，与 replace/delete 同一快照纪律——
  就地改会污染撤销快照）。骨架先过 `parse_handler_body` 同一校验链，
  失败 no-op + 提示，绝不把非法语句塞进 IR。
- **骨架必须中英各一份**：关键字表按语言**互斥**
  （`keywords_for(ZhHans)` 只有「变量/如果/结束」），同一段文本不可能两边都
  解析。内建命令名反而中立（`find_builtin` 同时认 `spec.zh`/`spec.en`/`spec.id`），
  统一写规范 id。
- **面板宽度必须自适应**：积木窗格常是中心列两个窗格之一（1280 窗口下实测
  ~374pt），固定 240pt 把画布挤到 ~44pt（内容全被裁）。取可用宽一半并双向夹取。
- **顺序陷阱**：`canvas_width` 必须**先**扣掉面板宽再建画布。第一版把重算写在
  画布构造**之后**——`let` 遮蔽看着像改对了，实际是死代码（编译器不报错）。

### 键位：两个必踩的坑

- **`KeyboardShortcut::matches` 是修饰键精确相等**（`event.modifiers ==
  self.modifiers`）：macOS 发 `meta`、Windows/Linux 发 `control`，**必须各注册
  一条**（`shortcut_icon_button` 的 `alt_shortcut`），只注册一个会有一整端
  失灵，且**本机测不出来**。
- **快捷键载体必须是 `@views.button`，不能是 `on_tap` 外壳**：runtime 的
  快捷键通路（`input_keyboard.mbt`）匹配后走 `activate_primary` → 给第一个
  子节点合成一个 **Enter 键盘事件**；而 `OnTapModifier` 只认 `Pointer` 事件。
  所以 `icon_button`（`on_tap`）+ `.keyboard_shortcut(...)` **永远不会触发**。
  `views/button/button.mbt` 显式处理 `Enter`/`Space`，是唯一对合成事件有反应的载体。
- **顶栏宽度预算的实数**：`@views.button` 的 `content_width =
  max(declared, measured_text + padding_horizontal×2)`，Studio 主题
  `spacing_scale.lg = 16` → 空标签按钮**硬下限 32**（声明 26 渲染 32）。
  拖拽区预算按声明值算就会低估，直接盖住按钮（只在原生无框窗口复现：
  点运行变成拖窗口）。加按钮后**必须重跑** `shell_responsive_wbtest` 的
  「drag region stops before the top bar actions」——本轮它一次就抓到了。
- **`topbar_actions_width` 要与渲染同源**：既有实现把 `34.0 / 28.0 / 28.0`
  写死，而 `topbar_chip_bound("编译 MoonBit")` 实算 110（不是声明的 72）。
  加按钮时把图标按钮统一到 `TOPBAR_ICON_BUTTON_WIDTH` 并留
  `TOPBAR_ACTIONS_SAFETY` 余量（高估只少几个点可拖，低估直接废掉按钮）。

### CI 盲区

- `checks/profiles.json` 的 studio 步骤原先**全在 `services/`**，
  `moon test moui_studio/app`（172 个用例，含全部 UI 回归白盒）
  **从不进 CI**。已加 `studio app tests` 到 pr profile。
- 改动 `domain/blocks` 后 `sync_kernel --check` 仍报 current（内核集只有
  ir/studio_lang/codec，blocks 不在其中）——但**仍要跑**，因为 codegen 与
  bundle 依赖内核快照。

### 悬停提示（框架能力边界）

- **更正（2026-10-01 复核）**：我先前记的「框架 tooltip 没有视觉浮层、需要
  portal」是**错的**——`moui/views/controls/control_focus_overlay.mbt:67` 的
  `@views.tooltip(child, message, visible?)` 就是可用的定位浮层（走
  `presentation.popup_host` + 四向 placement），`examples/excel/app/view_toolbar.mbt:162`
  在用。**教训：下「框架没有 X 能力」的结论前先 grep 一遍**——这句话我写进了
  代码注释、计划 Decision log 和本文件三处，全部要回改。
- 状态栏提示仍是当前选择（图标簇共用一格状态已够用，键盘可达），但理由从
  「框架没有浮层」改为「不需要逐元素 hover 状态」——**是取舍不是缺失**。
- **`on_hover` 必须确认真的插进去了**：本轮第一次 `str.replace` 因为目标串
  在文件里出现多次而静默未命中，编译照过、测试照绿、实机毫无反应——
  改视图层后**务必实机验证**（像素差 0 就是没生效）。

## 2026-10-01 左栏结构树批次（用户报「点不动」+「没有新增结构的地方」）

### 树行「画了但不可交互」——与死 UI 同族，但表现是「点了没反应」

- **缺陷**：`tree_node_row` 只为 `TnControl`/`TnHandler` 生成 `on_tap`；
  窗体（`TnWindow`）、变量（`TnVariable`）、数据（`TnDataFile`）三类行的
  `on_click` 是 `None`（`match` 的 `_ => None`）。**用户看到树上有行、点了
  毫无反应**。更隐蔽的一半：变量行与数据行的 `select_key` 是**空串**——
  即便接上点击，所有变量行也会指向同一个空目标。
- **修法**：`tree_node_row` 按 kind 分派 `SelectSide(SideWindow |
  SideVariable(name) | SideData(name))`；`ide_state.mbt` 的
  `program_tree` 补上变量/数据行的 `select_key`。
- **教训**：给树加新节点种类时，**同时**要给它 `select_key`（可寻址）与
  `on_click`（可交互）。只加 `nodes.push` 会造出一行装饰品。
- 新增 `TreeView` 节点种类时，检查清单：① `TreeNodeKind` 加变体；
  ② `program_tree` 填 `select_key`；③ `tree_node_row` 给 `on_click`；
  ④ `tree_node_selected` 给选中判据；⑤ 右栏 `context_props` 给属性面。

### 选中必须是单一漏斗（三条槽互斥）

- **背景**：选中是三条并存的槽——`selected_control`（控件名）、
  `selected_handler`（`控件@事件`）、新增的 `side_target`。
- **既有不一致（本批次顺带修掉）**：`SelectHandler` **忘了清
  `selected_control`**，而 `context_head` 优先读控件 → 点左栏的子程序行之后，
  右栏继续显示上一个**控件**的属性。用户读到的现象同样是「点了没反应」。
- **纪律**：任何改选中的代码都走 `app/update_selection.mbt` 的
  `select_control_by_name` / `select_handler_key` / `select_target` /
  `clear_selection`。清字段的动作只写一遍，新入口就不可能漏清。
- 视图层的选中判据也收敛到 `tree_node_selected(model, kind, key)`，
  不要在各处重写 `model.selected_control == node.select_key`。

### 新建入口必须与枚举等长

- 「快速插入」原来只有 4 个（按钮/标签/列表框/输入框）：**选择框与表格没有
  任何入口**（只能靠 AI 提案或模板才会出现），而且**没有新建变量的地方**。
- 现在 7 格 = 6 种 `ControlKind` + 变量，**与枚举等长**是这个区域的验收口径。
- **高度预算单点**：`INSERT_ROWS`（=4，7 格 2 列）被 `bottom_strip_height`
  与视图共读。旧常量写死 `2.0 * 26.0`，格子加到 7 个会把最后两行挤出面板
  下缘——这类「加了内容没改预算」是本仓复发最多的一族。

### 变量语义（易错点）

- **改名必须同步改写引用**：引用只在代码视图可见，改名不同步会让程序静默
  变成「引用未声明变量」。递归覆盖 `If`/`ElseIf`/`CountLoop`/`WhileLoop`
  的 body（`rename_var_in_stmts`）。
- **删除不清理引用**：自动删语句是静默改写程序语义，比留下显式错误更糟，
  交给 `validate_program` 在编译/导出时如实报。
- **`Var(name)` 有歧义**：控件名在 IR 里也以 `Var` 形态出现在命令实参位
  （`取文本(姓名框)`）。变量改名只动 `Var`，不做位置语义推断——推错了会静默
  改写行为。控件改名走的是「命令实参位」专用规则（既有实现）。
- 名称去重 `变量1`/`变量2`…（`validate_program` 把重名当致命错误）；
  预算 `MAX_VARIABLES = 64`，超限设 notice 不静默。

### 只读 vs 可编辑的判断口径

窗体设计尺寸（640×480）**刻意只读**：它是全局常量，运行舞台等比缩放与控件
越界校验都按它判定；放开编辑要同时改画布换算与不变量三处。**宁可如实展示
加一句说明，也不要给一个会破坏不变量的输入框**。同理数据条目是**派生**
视图（控件 items / 变量集合），给可编辑输入框会让人以为数据有独立存储。

## 2026-10-01 创建入口上移（用户质疑「新建都在快速插入里合理吗」）

### 判断口径：创建入口应该贴着什么？

- **底部全局块的问题不是丑，是三层不合理**：
  ① 它已是从零开始的**唯一**创建通道，标签却叫「快速插入」（暗示还有正门）；
  ② 常驻占左栏 **约 35% 高度**（800pt 窗口实测 256/736），而结构树才是那个
  会长、会滚动的区域；③ **它是全局的**，而本 App 另外两处创建都是上下文相关
  的（右栏「动作」页签建事件子程序、积木分类轨建语句）——同类操作两套范式。
- **改法**：`group_create_action` 给分组头加 `+`，点开内联候选菜单。
  **用过已有的 30pt 分组头行 = 零额外空间**。
- **哪些组有「+」由 `group_can_create` 单点判定**：窗体/控件/变量/事件子程序
  有；**本地数据没有**——条目从列表/表格控件的行**派生**，没有独立创建语义。
  **宁可没有按钮，也不给一个点了没用的按钮。**

### 内联展开 vs `@views.dropdown`

- 框架的 `@views.dropdown(label, items, state~, on_toggle~, ...)` 自带一个
  `@button.button` 锚点 + `DropdownState`——塞进 24pt 的树行会撑破行高。
- 用**内联候选行**（与积木的语句插入面板同一手法）：展开时在该组子节点之后
  插入若干与树行同高的行，读起来是「这一组可以加什么」的清单。

### `tree_row` 加尾部动作的宽度纪律

- 新参数 `trailing` / `trailing_width`；**尾宽必须计进宽度账**
  （`gaps` 加一条、`label_width` 减 `trailing_width`）。
- 这个文件已有**两次**同类教训：meta 写死 52 时「640×480」被裁成「64」；
  尾宽漏算会让 meta 或「+」挤出面板右缘。

### 测试边界陷阱（本轮又踩一次）

- 断言「不越出左栏」时，**`LEFTBAR_WIDTH` 是宽度不是坐标**。左栏的绝对范围是
  `[ICONBAR_WIDTH, ICONBAR_WIDTH + LEFTBAR_WIDTH]`。我第一版直接拿文字右缘
  （265）与 `LEFTBAR_WIDTH`（232）比，把**正确布局判成了溢出**。
  判之前先量一次实际值（探针实测 right=265 vs 面板右缘 280 = 合法）。

### 更正：框架 tooltip 是可用的

- **我先前记的「框架 Tooltip 没有视觉浮层、需要 portal」是错的**——
  `moui/views/controls/control_focus_overlay.mbt:67` 的
  `@views.tooltip(child, message, visible?)` 就是可用的定位浮层
  （走 `presentation.popup_host` + 四向 `placement`），
  `examples/excel/app/view_toolbar.mbt:162` 在用。
- 状态栏提示仍是当前选择，但理由从「框架没有浮层」改成「图标簇共用一格状态
  已够用，不必逐元素管 hover 状态」——**是取舍不是缺失**。
- **教训：下「框架没有 X 能力」的结论前，先 grep 一遍 `moui/views/pkg.generated.mbti`
  与 `examples/`**。这句话我写进了代码注释、计划 Decision log 和本文件三处，
  全部回改了。

### 危险的批量删除（本轮教训）

- 用 `re.search(r"///\|\n(?:///.*\n)*fn NAME\(.*?\n\}\n\n", s, re.S)` 删函数时，
  `.*?` 跨过了后续内容，**一次删掉 840 行**（文件 1166 → 326）。
- 教训：**批量正则删除后立刻 `wc -l` 与 `git diff --stat` 核对行数**；
  多行删除改用「先定位函数起点 + 找下一个顶层分隔标记」的显式边界，
  并打印删掉的行数确认。所幸当时未提交，`git checkout` 可恢复——但那次恢复
  也带走了本会话在**同一文件**里的未暂存改动（树行 SelectSide 接线），
  必须重做。**跨会话的未提交改动要尽早 commit 或至少暂存。**

### notice 漏斗与命令表纪律（2026-10-02）

- **`model.notice` 曾是只写不画的死通道**（全仓无任何视图渲染它）：保存/打开/
  导出成败、积木解析失败、预算超限、Web 编译轨不可达等十几条路径静默吞掉。
  已根治：**所有 notice 写入必须走 `update_shell.mbt` 的 `with_notice`**
  （写字段 + 补推 toast，错误 warning=true，长文本 fit_label 截断），禁止
  直接写结构体字段。唯一例外：导出 `ExportDirPicked` 的目录回显是中间态
  （完成/失败马上 toast），注释声明。
- **导出回执计数 `export_pending`**：bundle 几十文件逐文件回执，全部落盘
  才报一次「已导出」；单文件失败告警一次并归零。逐文件报成功 = 刷屏。
- **命令面板的死命令盲区**：死消息门（validate_dead_messages）只看 Msg
  变体构造点，管不住「`StudioCommandRun("studio.xxx")` 的 id 在
  `studio_commands()` 表里缺席」——`studio.template.drill/store`、
  `studio.help/preview` 曾是有处理器无表项的死命令（样例/帮助/预览零入口）。
  **加 run_studio_command 分支必须同步加表项**，测试钉住表内容与执行链。
- **`export_available`（macOS true，Web 默认 false）**：Web 目录「选择」
  返回文件名列表，逐文件 write_text 必然失败——不可达就显式声明
  （`app.export.unavailable_web`），与 compile_track_available 同口径。
  给页面入口必须配出口（全屏页「返回编辑」行）。
