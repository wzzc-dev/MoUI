# MoMao（墨卯）App Notes

## Package

- `examples/momao`（module `examples/momao`，2026-09-27 建立）：中英双语可视化
  编程 IDE，单一程序 IR 支撑「窗体设计 / 积木编排 / 双语代码」三视图 + 结构化
  AI 提案 + 闸门化运行 + 独立应用导出。计划：`docs/plans/active/momao.md`。
  前身 `examples/moeui_studio` / `examples/moblocks_studio` 已删除（git 历史
  e7cfe78e2 / a29eb8e3d 可查），salvage 映射见计划第 11 节。
- 结构（计划口径）：`domain/{ir,momao_lang,codec,blocks,proposals}` 零 UI 依赖、
  `services/{export,model_provider,provider_native}`、`app/`（TEA + 五视图，
  native+wasm-gc）、`web_wasm/` + `macos_skia/` 薄入口、`tools/{sync_kernel,
  emit_bundle}`。
- 最小循环：`moon test examples/momao/app --target native|wasm-gc`、
  `moon build examples/momao/web_wasm --target wasm-gc`、
  `node scripts/generate-i18n-catalogs.mjs ... --check`、
  `moon run examples/momao/tools/sync_kernel --target native -- --check`。

## 产品决策（重写时不要推翻）

- IR 是语句级（Assign/If/CountLoop/WhileLoop/Break/Call），不是自由图；
  积木与代码都是 IR 的投影，代码视图是文本真身。
- DSL 关键字是 catalog 数据（`domain/momao_lang/keywords.mbt` 中英两张表），
  解释器内禁止 `keyword == "如果"` 式硬编码分支；往返测试
  `parse(render_zh(ir)) == ir == parse(render_en(ir))` 是硬门。
- 内核语言中立：ParseError/RunError 只给结构化 `{kind,line,col,token?}`，
  可读文案全部由界面层经 `moui_i18n` catalog 解析（key 不进领域层）。
- `提交数据` 是闸门化模拟动作（确认卡 + 审计），v1 不发起真实网络请求；
  web 端只走确定性假模型，真实 OpenAI 兼容 provider 仅 native。
- 真实模型默认配置：阶跃星辰 StepFun，endpoint
  `https://api.stepfun.com/step_plan/v1`，model `step-5-preview`。**凭据
  唯一来源是 gitignored 的 `examples/momao/.config.json`**
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
  写回状态（如 MoMao 的 `run.state.texts`），否则输入回跳、`取文本` 读旧值。
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
  cwd = **module 根**（`examples/momao/`，探针实测），配置路径候选
  `.config.json` + `examples/momao/.config.json`。live 调用会消耗 key
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
- 导出自包含应用的最小充要条件：领域内核（ir/momao_lang/codec，零 UI 依赖，
  只允许 `@graphics.Color` 与 `@json`）+ 一个 ~150-200 行通用 TEA runner。
  内核之间可互调，**不能调用非内核文件里的函数**（workspace 外构建才报错，
  例：`auto_layout` 曾被 ai_generation 持有导致 bundle 编译失败）。
- 浏览器里导出应用的逻辑坐标 == CSS 坐标（宿主按画布尺寸重排），不要再按
  DPR 换算。

## 2026-09-27 P1 落地后新增事实

- **模块已成形**：`examples/momao` 独立 module，五个领域包 + services×3 + tools×2 +
  app + web/macos 入口。全量测试：domain 51 + app 14 + model_provider 5 + export 8
  （双目标）+ provider_native 2（native）。
- **最小循环**：`moon test examples/momao/domain/<pkg> --target native|wasm-gc`、
  `moon test examples/momao/app --target native|wasm-gc`、
  `moon run examples/momao/tools/sync_kernel --target native -- --check`、
  `moon run examples/momao/tools/emit_bundle --target native -- <project.json> <name> <dir>`。
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
  （kernel_momao_lang + kernel_momao_lang_rt 两组；1800 行/文件硬线）；bundle
  里 kernel .mbt 必须与源逐字节一致（cmp 验证）；独立构建需 `moon update`
  拉 mooncakes.io。emit_bundle 签名：`<project.json> <app-name> <target-dir>`。
- **i18n**：app 自带 230 条中英 Message（手写 catalog，不走 generate 脚本——
  示例包不引入 JSON 加载）；文案全部 key 化（含 DSL 错误 kind 映射）。
- **假模型**：`fake_model_completion(prompt, current_program)` 全量构建语义
  （先 remove 全部再加），关键词路由中英文混合。

## 2026-09-27 收官两项（verifier 补齐）

- **i18n 生成链**：数据在 `examples/momao/app/i18n/{zh-Hans,en}.json`（manifest
  `catalogs.json`），`node scripts/generate-i18n-catalogs.mjs --input … --out …`
  生成 `i18n_catalog_generated.mbt`（GeneratedI18nCatalog + Text/Plural），
  app/i18n.mbt 只做适配（momao_messages 打平成 @i18n.Message）。`--check` 步骤
  名 "momao i18n catalogs"（checks/profiles.json）；生成文件需同时进
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
  主题）。深色系统 + 无背景的浅色布局 = 白字白底。MoMao 在根视图
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
- **`moon test` 的 cwd = module 根**（`examples/momao/`，探针实测），
  不是仓库根；`moon run` 才是仓库根。`.config.json` 路径候选要两者兼顾。
- **UI 框架要点（B1-B4 实测）**：`@views` facade 的 `pub using` 转发会把
  枚举构造器带进作用域（`variant=Ghost`/`role=Title` 裸写可用），但 match
  臂里的裸构造器不行（BadgeTone 与 FeedbackTone 歧义，要
  `@style.BadgeTone::Success`）；`ColorPalette::from_seed(primary~, scheme)`
  的 **scheme 是位置参数**；`View::on_tap(msg)`（core）给彩色 container 行
  加点击 + Semantics，积木行靠它替代文本按钮；现成控件直接用：card/
  button_group+action_item/checkbox/progress/loading_state/inline_error/
  badge(tone)；品牌主题 `momao_theme()` = 朱砂 `ColorPalette::from_seed`
  + `@views.theme(palette=...)`（app 主导入块加 `wzzc-dev/moui/core` 是
  示例 app 既有先例，pdf_workbench 等都这么干）。
- **导出回归门**：`scripts/momao-export-smoke.sh`（emit_bundle → 临时目录
  `moon update` + 独立 wasm-gc 构建），注册为 smoke/gates.json
  `momao.export-build`（nightly 档，需网络不进 pr）。坑：emit_bundle 产物
  在 `<target-dir>/<app-name>/` 且 app 名被模块名安全化（下划线→连字符），
  用唯一子目录通配进入；脚本退出码会被管道 tail 吃掉，重定向到文件再取。
- 设计画布绘制计划已 pub(all)（GridDot/GuideV/GuideH/SelectionHandle op），
  alignment_guides 纯函数 ≤4px 容差；同宽控件偏移 ≤4px 时左/中/右三条
  参考线全命中（测试按成员断言）。
- app 包曾有 test-block `wzzc-dev/moui/core` 死导入（unused package
  警告），已移除并转入主导入块实际使用。
