# MoUI StudioApp Notes

## Package

- `examples/moui_studio`（module `examples/moui_studio`，2026-09-27 建立）：中英双语可视化
  编程 IDE，单一程序 IR 支撑「窗体设计 / 积木编排 / 双语代码」三视图 + 结构化
  AI 提案 + 闸门化运行 + 独立应用导出。计划：`docs/plans/active/moui-studio.md`。
  前身 `examples/moeui_studio` / `examples/moblocks_studio` 已删除（git 历史
  e7cfe78e2 / a29eb8e3d 可查），salvage 映射见计划第 11 节。
- 结构（计划口径）：`domain/{ir,studio_lang,codec,blocks,proposals}` 零 UI 依赖、
  `services/{export,model_provider,provider_native}`、`app/`（TEA + 五视图，
  native+wasm-gc）、`web_wasm/` + `macos_skia/` 薄入口、`tools/{sync_kernel,
  emit_bundle}`。
- 最小循环：`moon test examples/moui_studio/app --target native|wasm-gc`、
  `moon build examples/moui_studio/web_wasm --target wasm-gc`、
  `node scripts/generate-i18n-catalogs.mjs ... --check`、
  `moon run examples/moui_studio/tools/sync_kernel --target native -- --check`。

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
  唯一来源是 gitignored 的 `examples/moui_studio/.config.json`**
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
  cwd = **module 根**（`examples/moui_studio/`，探针实测），配置路径候选
  `.config.json` + `examples/moui_studio/.config.json`。live 调用会消耗 key
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

- **模块已成形**：`examples/moui_studio` 独立 module，五个领域包 + services×3 + tools×2 +
  app + web/macos 入口。全量测试：domain 51 + app 14 + model_provider 5 + export 8
  （双目标）+ provider_native 2（native）。
- **最小循环**：`moon test examples/moui_studio/domain/<pkg> --target native|wasm-gc`、
  `moon test examples/moui_studio/app --target native|wasm-gc`、
  `moon run examples/moui_studio/tools/sync_kernel --target native -- --check`、
  `moon run examples/moui_studio/tools/emit_bundle --target native -- <project.json> <name> <dir>`。
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

- **i18n 生成链**：数据在 `examples/moui_studio/app/i18n/{zh-Hans,en}.json`（manifest
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
- **`moon test` 的 cwd = module 根**（`examples/moui_studio/`，探针实测），
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
  `examples/moui_studio`，计划 `docs/plans/active/moui-studio.md`。
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
  package（含 `examples/moui_studio/**`）里生成新 mbti。跑完 `moon info`
  后记得 `git clean -f examples/moui_studio` 清掉这些不该提交的生成物，
  只提交 tracked 漂移（本轮是 `moui/core/pkg.generated.mbti` 的
  `View::on_tap_with_frame`）。
- **`moon fmt` 陷阱**：对 `examples/moui_studio/app/*.mbt` 通配会改写
  无关既有文件（实测 `canvas.mbt`）；只对本次触碰的具体文件跑
  `moon fmt <file>`。仓库多处既有文件有 format 漂移（proposal/main/
  compile_report/studio_lang_test/worker_test/runtime_pointer_input_test），
  `moon fmt --check` 必须全绿才能过 pr profile。
- **仓库生成物**：`docs/repository-facts.md` 是生成物——改 docs catalog
  后跑 `node scripts/generate-repo-docs.mjs --write`（会连带
  `sync-website-docs.mjs`）；`website/web_wasm/docs/*` 与 `sitemap.xml`
  是同步生成物（web_wasm/docs 被 gitignore，不入库）。**旧名 grep**：
  新文档里别把旧产品名写回去（本轮踩过一次已清）；`git grep -in` 旧名
  三种写法应零命中（`docs/plans/done`、`docs/ai-sessions` 的历史快照除外）。
- **artifacts/ 与凭据**：`artifacts/` 不入库；`examples/moui_studio/.config.json`
  （StepFun key）gitignored，绝不入源码/bundle。

## web 入口实机验证工作流（2026-09-29 实测）

- index.html 的相对路径假设：`../.mooncakes/wzzc-dev/moui_web_renderer/
  runtime.js` 与 `../../../_build/wasm-gc/.../web_wasm.wasm` 均相对
  `web_wasm/`。workspace 成员（wzzc-dev/*）**不在** `.mooncakes` 里（在
  仓库根目录作为 workspace 成员），直接 `python3 -m http.server` 于
  web_wasm/ 会 404。**staging 布局**：`/tmp/stage/examples/moui_studio/
  web_wasm/index.html` + `.mooncakes/wzzc-dev/{moui,moui_web_renderer}`
  符号链接到仓库对应目录 + `_build/.../web_wasm` 符号链接，于 stage 根起
  服务，URL `/examples/moui_studio/web_wasm/index.html`。runtime.js 内部
  引 `../moui/backend/web/browser_runtime.js` 与
  `./canvas2d_runtime.js`，符号链接目录天然解析。
- 命令面板/对话框类 presentation 打开瞬间有渐显动画：截图测对比度前先等
  ~1s 稳定，否则拍到半透明中间帧误判。
- ZCode IAB 截图实测：1280×832 视口与桌面截图同尺度，逐点取样对比度
  可复用 artifacts/studio-analysis/contrast.py 的模态背景+字形极值法。
