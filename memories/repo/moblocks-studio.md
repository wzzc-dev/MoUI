# MoBlocks Studio App Notes

## Package

- `examples/moblocks_studio`（module `examples/moblocks_studio`）：AI 直接生成的可视化应用开发工具，2026 上海赛交付物。计划：`docs/plans/active/moblocks-studio.md`。
- 结构：`app/`（平台中立 TEA + 领域模型）、`web_wasm/`（评审主路径）、`fixtures/`（离线样例，M1 起充实）。services/ 与 macos_skia/ 留待后续里程碑。
- 最小循环：`moon test examples/moblocks_studio/app --target native|wasm-gc`、`moon build examples/moblocks_studio/web_wasm --target wasm-gc`。

## 工具链陷阱（2026-09-25，moon 0.1.20260920）

- `derive(Eq, Debug)` 在新模块触发 `implicit_impl_as_method` 警告（每个 derive 一条），建议语是 `pub extend T with Eq::{...}`。老模块（momark/moui/core）同样写法不警告，deepseek_harness_desktop 也警告——原因未定位（与依赖树、supported_targets、debug 导入均无关，已逐一排除）。**对策：app 包默认零 derive**（counter 风格），枚举比较用 `is` 模式，断言用 `assert_true(x is Variant)`，绕开整个坑。
- `Map::new()` → `Map([], capacity=16)`；`Array::new(capacity=n)` → `Array(capacity=n)`；`Option.or(x)` → `unwrap_or(x)`；`not(expr)` → `!expr`；`derive(Show)` 整体废弃（用 Debug）。
- `assert_eq` 需要 `Eq + Debug`（不是 Show）。
- 测试文件（`*_test.mbt`）是独立包：同包函数须 `@app.` 前缀（否则 test_unqualified_package 警告），枚举构造器可裸用；跨包 struct 字面量/结构更新要求 `pub(all) struct`。
- `@json.parse(text) catch { _ => ... }` 可直接接 String；Json 构造器模式（`Object(m)`/`Number(n, ..)`）在 prelude 可裸匹配；注意 `Number(Double, repr~)` 双字段。
- 事件闭包参数类型靠推断，不要在 app 生产代码里写 `@core` 类型名；DragGesturePhase 走 `@views.DragGesturePhase::Started` 比较即可（views 再导出）。

## 画布（canvas）探针经验

- `@views.canvas(measure, draw)` + `on_drag_with_frame` 足以支撑命中/拖动探针，无需自定义 ViewNode；绘制逻辑拆成纯数据 draw-plan（`canvas_draw_plan`）后可断言 op 数量做帧基线结构代理（20/50/100 节点 → 59/149/299 op，线性 3n-1）。
- canvas 内容必须在 draw 里 `push_clip(ctx, frame)`/`pop_clip`，否则会画到兄弟面板下面。
- canvas 的 measure 不要狮子大开口：row flex 分配后槽位可能比内容小，需要视口滚动（M2 待办）而非硬撑大尺寸。

## M1/M2 输入与框架坑（2026-09-25）

- **AppServices::new() 不能在 update 闭包里每次构造**：wasm-gc 下会让所有指针事件
  静默失效（点击无反应、无报错）。在 `program()` 构造时捕获一次
  `let services = environment.services()` 即可（file_importer 同款模式）。
- ~~row 子级控件与 on_drag 手势不命中指针~~（**已澄清为误判**，2026-09-26：见
  `docs/plans/done/row-child-hit-testing.md`——画布 draw 帧是局部坐标、指针是屏幕坐标，
  旧测试混用导致点击偏移 42px）：
  M2 工作区把所有可交互控件放在 view 根 scroll_view / 检查器扁平列内；
  AppEnvironment/DOM 层面的 cua 点击在浏览器里对扁平列按钮有效。
- `text_field` 首参是当前值，`on_input` 回调带新值；`scroll_view(view, width~, height~)`
  会裁剪命中区（滚出视口的内容不可点，runtime 测试同样如此）。
- canvas 的 draw 闭包内用 `push_transform` 做视口变换；Transform2D 只能
  `translation(dx,dy)` / `scale(sx,sy)`，组合用结构体字面量
  `@graphics.Transform2D::{ a: s, b: 0.0, c: 0.0, d: s, tx: tx, ty: ty }`。

## M2 绿旗时刻与 provider 面板（2026-09-26）

- 画布聚光灯：`canvas_draw_plan(graph, selection, spotlight)` 对运行中/等待确认节点
  追加金色高亮描边（纯绘制，不依赖指针通道）。`spotlight_node(execution)` 从
  cursor 步骤状态推导。
- provider 面板（inspector 顶部）：fake/真实切换 + endpoint/key 字段；key 只存
  会话内存，测试断言 `encode_project` 产物不含 key。
- `services/model_provider` 包：OpenAI 兼容请求体构造 + 响应解析（错误体拒绝）+
  确定性假模型 + 请求预算守卫。注意 `Json::stringify()` 输出是**紧凑**格式
  （`"key":value` 无空格），断言别带空格。
- `moon test examples/moblocks_studio/services` 会失败（目录不是 package），
  要指向 `services/model_provider`。

## M3 provider IO 要点（2026-09-26）

- `moonbitlang/async/http` **只有 native 目标**：wasm-gc 下 `@http.post` 解析不到。
  因此 `services/model_provider`（含 worker）不能在 app 的 moon.pkg 里被 web 依赖；
  app 只依赖纯函数部分（`finish_real_generation` 等），native 组合根（macos_skia）
  负责把 `provider_submit` 闭包传进 `program(provider_submit~)`。
- async 组合模式（照抄 mo_workbench）：`async fn main` +
  `@async.all([window_task, worker_task])`，窗口侧用 `run_async_pump()`；
  worker 侧 `@async.with_task_group` + `queue.get()` + `group.spawn_bg`。
- HTTP 用例：`@http.post(url, body_string, headers={ "Authorization": "Bearer " + key })`；
  响应 `(resp, data)`，`resp.code`、`data.text()`。
- Queue `try_put` 会 raise，要 `ignore(x catch { _ => false })`；结构体字段里的回调
  调用要写 `(job.on_result)(result)`。
- MoonBit 字符串里的 `{` 字面量是 `"{"`，不要写成 `"'{'"`（那是 3 个字符）。

## M4 导出 bundle 的两个硬骨头（2026-09-26，浏览器实测通过）

导出项目在浏览器无法启动的根因有两个，都与"仓库内能跑"的差异有关：

1. **JS 运行时闭包目录错位**。`moui_web_renderer/runtime.js` 内部
   `import ... from "../moui/backend/web/browser_runtime.js"`。把 runtime.js 拷到
   bundle 的 `web_wasm/` 会让该相对路径解析到 `bundle/moui/backend/web/...`（不存在），
   表现为页面日志为空、状态停在 Loading。**最终方案（2026-09-26 收口 P0）：导出的
   `index.html` 直接引用 bundle 自己的依赖目录
   `../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js`（从 `web_wasm/` 上一级），
   其内部 `../moui/backend/web/browser_runtime.js` 因此解析到
   `bundle/.mooncakes/wzzc-dev/moui/backend/web/browser_runtime.js`（`wzzc-dev/moui`
   是 bundle moon.mod 的依赖，`moon build` 后必然在 `.mooncakes`），动态
   `./canvas2d_runtime.js` 同目录。**不要**把 JS 拷进 bundle 或嵌成 MoonBit 常量：
   拷贝会让 Studio 内导出（只写 15 个生成文件）与文档承诺不一致，嵌入会冲破
   `validate-maintenance-baseline` 的 1800 行/文件默认预算（runtime.js 3300+ 行）
   且与 moon.mod 固定版本脱钩。`python3 -m http.server` 正常提供点号目录。
   `emit_bundle` 与 Studio 内导出现在走同一个 `export_bundle`，两边零差异。
2. **Moon 的 wasm 链接器只导出「可执行包自身定义」的函数**。`moon.pkg` 的
   `options(link: { "wasm-gc": { exports: [...] } })` 只登记符号名；符号必须在**可执行包
   自己的 .mbt** 里定义，否则静默 DCE，产物只剩 `_start`，浏览器报
   `must export web_dispatch_event`。转发垫片放依赖包里无效（webbridge 实验证实）。
   修法：可执行包含一个机械 `abi.mbt`，逐个 `pub fn web_xxx(...) { @web.web_xxx(...) }`
   转发到 `moui/backend/web`（照抄 `examples/moblocks_studio/web_wasm/abi.mbt`）。
   注意：`link.exports` 里写不存在的符号**不报错也不警告**，只能解包 wasm 查 export 段验证。

其他：`#|` 多行字符串在本工具链**不支持 `\{...}` 插值**（原样输出）；多行串就是
"每行 `#|` 前缀、遇到非前缀行结束"。月球 per-line 形式。
`is-main` 选项已废弃，与 `pkgtype(kind: "executable")` 冲突会报错。

## 2026-09-26 框架债务澄清：row 命中 / on_drag 不是框架缺陷

- `docs/plans/done/row-child-hit-testing.md` 的三个症状（row 直接子级按钮不命中、
  row 内 scroll_view 子级不命中、`on_drag`/`on_drag_with_frame` 不触发、画布拖不动）
  复核后**全部为坐标系误用导致的测试误判**，框架无缺陷：
  1. `AppRuntime.draw_commands()` 里 `@views.canvas` 的 `DrawText.frame` 是
     **画布局部坐标**（draw 回调的 transform 不进命令记录）；指针事件是屏幕坐标。
     旧测试按节点文本帧中心派发指针，实际落在积木上方 canvas 原点偏移处
     （Studio 画布原点 (0,42) = notice 32px + 根 column 间距 10px）→ hit_test 未命中
     → 误判「手势不触发」。
  2. 拖拽手势 `DragGesturePhase::Started` 发生在**第一次越过 3px 阈值的 Move**，
     不是 Down；Down 只进入 Pending。测试要先发一个 >3px 的小步进再发完整位移。
  3. 8 种 row 形状探针 + canvas/按钮/普通 view 的 on_drag 全部正常；
     program 宿主（new_program）下消息按序作用到更新后的 model。
- 回归固定：`moui/runtime/row_child_pointer_input_test.mbt`（5 项，native+wasm-gc
  140/140）；Studio 画布拖拽端到端回归在 `app/moblocks_ui_test.mbt`
  （46/46 ×2 目标）。债务文档移入 `docs/plans/done/`。

## 2026-09-26 导出应用可执行化 + 一个要命的转义坑

- 导出自包含应用要「能跑」，最小充要条件：领域内核（block_graph/block_catalog/
  graph_validation/execution_reducer/project_codec 五个文件，零 UI 依赖，只用到
  `@graphics.Color` 与 `@json`）+ 一个 ~200 行通用 TEA runner。不需要按积木代码生成。
- 同步机制：`tools/sync_kernel`（moon 工具，`moonbitlang/x/fs` 同步 IO）把 5 个内核与
  `tools/export_runner_template/runner.mbt` 读成常量，**一个源文件一个常量文件**写进
  `services/export/kernel_<name>.mbt`（含 `kernel_runner.mbt`）；`--check` 模式做漂移门，
  已注册进 `checks/profiles.json` 的 pr profile。改了内核/模板必须重跑同步——
  `moon fmt` 也会造成漂移（实测触发过一次）。常量文件别合并成单文件：
  `validate-maintenance-baseline` 有 1800 行硬线（1818 行的合并版被拒）。
- **坑（花了很久）**：本工具链的 `#|` 多行字符串**不做 `\{x}` 插值**，原样输出。
  同步时若按「插值会被求值」的假设把反斜杠加倍，嵌入串的值就比源文件多一层 `\`，
  内核里的 `"\{edge.to}:\{edge.to_port}"` 退化成字面量 → 校验器的占用检查把所有边
  算成同一个输入 → 合法图全被误判 `InputOccupied`。判断方法：bundle 的 .mbt 与
  app/ 下的源文件 `cmp` 必须逐字节相同。
- 浏览器实测坐标：导出应用的窗口逻辑坐标 == CSS 坐标（宿主按画布尺寸重排），
  按钮 y 可直接用 draw 命令帧（跑 `moon test app` 打 `DrawText` 帧即可），不要再按
  DPR 换算。

## 2026-09-26 冻结前收口：导出闭包 / prompt 输入 / 闸门精度

- **导出的 Web 运行时 JS 只能来自 `.mooncakes`**（见上文 M4 第 1 条的最终方案）：
  不要把 JS 嵌成 MoonBit 常量（`validate-maintenance-baseline` 1800 行/文件默认预算
  会被 runtime.js 的 3300+ 行冲破，且与 moon.mod 固定版本脱钩），也不要只让离线 CLI
  拷贝（Studio 内导出走不到那段代码，浏览器停在 Loading）。导出页面写
  `../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js`（相对 `web_wasm/index.html`）。
- **`Array` 没有 `find` 方法**（本工具链），按谓词找元素要手写 for 循环；
  `Float`/`Array` 常用方法：`any/filter/map/contains` 可用。
- **提案节点不带 config**：`decode_proposal` 只从提案 JSON 读 config，不填 schema
  默认值（`GraphEditor::apply(AddNode)` 才会填）。因此执行摘要里的人设/模型名要
  回落到积木目录的规范默认值（`find_config_spec(...).default`），别假设节点自带配置。
- **`decode_project` 对无坐标的项目自动布局**：提案形状 JSON（如
  `fake_model_completion` 的产物）没有 x/y，解码后所有节点会叠在原点；
  现在 `has_coordinates == false` 时跑 `auto_layout`。带坐标的项目不受影响。
- **外发闸门口径**：`validate_graph` 要求 ModelCall/StructuredModelCall 的 `approved`
  输入从 UserConfirmation 的 `approved` 输出**直接连线**（`MissingConfirmation`）；
  旧的「从确认节点可达」会让挂在无关支路上的确认节点也放行外发。M0 的 20 节点
  样例图因此补了 3→{6,7,18,19} 的 approved 连线。
- 执行步骤带 `input_summary`/`output_summary`（`step_summaries`，计划期推导）：
  模型步骤显示 `【人设】确定性回复（模型 X）`，其余步骤一句话说明；`StepOk`/`Confirm`
  的 summary 取 output_summary（空则「完成」）。时间线不再满屏「完成」。
- **内核文件的函数边界（workspace 外构建才会抓到）**：`services/export` 只同步 5 个内核
  文件（block_graph/block_catalog/graph_validation/execution_reducer/project_codec），
  内核之间可以互调，但**不能调用住在非内核文件里的函数**——例如 `auto_layout` 原先在
  `ai_generation.mbt`，`project_codec` 的无坐标自动布局一调它就编译不过（app 包内
  同包可见所以 app 测试全绿，导出 bundle 在 workspace 外 `moon build` 才报
  `auto_layout unbound`）。已把 `auto_layout` 移进 `block_graph.mbt`（内核成员）。
  改了内核或模板后必须重跑 `sync_kernel`，`--check` 漂移门已进 pr profile。
