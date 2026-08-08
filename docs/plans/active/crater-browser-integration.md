# Plan: Crater × MoUI 纯 MoonBit 浏览器(examples/browser)

- **Status**: active
- **Goal**: 用 MoUI + mizchi/crater(HTML/CSS 引擎)+ dowdiness/js_engine(纯
  MoonBit 嵌入式 JS)构建纯 MoonBit 桌面浏览器 demo。
- **结论**: **可行且已立项**。crater 暴露"HTML → PaintNode"公开 API,MoUI 侧
  `canvas` 绘制注入可直接承载翻译后的 DrawCommand;JS 由
  `dowdiness/js_engine@0.7.0`(纯 MoonBit、无 C 绑定)提供,整条链路无
  JavaScript 之外的语言。

## 进度(2026-08 执行中)

- M1 ✅ `examples/browser/engine`(crater 引擎子包):`paint_node_to_commands`
  翻译器(背景/圆角/文本/边框/阴影/opacity/clip/图片/多边形,10 测试),
  `render_html` / `render_html_document` facade。
- M2 ✅ 交互:修复 PaintNode 父相对坐标累加;像素级链接区域提取(DOM href
  × paint 树 `<a>` 框按文档顺序 zip);canvas `on_drag` 点击命中 → data URL
  导航;http(s) 导航进入后台加载。
- M2.5 ✅ `dowdiness/js_engine@0.7.0` 接入:JsEngine 包装(持久 realm、console
  输出、错误非致命)、`extract_scripts`;渲染时执行页面 `<script>`。
- **M3.5 子资源加载 ✅**(本次交付,外链 JS/CSS):
  - **C 桥批量扩展**(`net_bridge.c`):单槽导航 API(slot 0)扩展为
    **48 槽批量 API**(`moui_fetch_slot_start/wait_all/state/len/take/clear`),
    每 URL 一个并行 worker 线程;`use_seq` 标志区分导航槽(代数计数防
    陈旧)与批量槽(结果保留);`fetch_resources(urls)` MoonBit 侧批量抓取。
  - **资源提取与管线**(`scripts.mbt`/`page_render.mbt`):
    `extract_script_entries`(内联+外链按文档顺序)、`extract_stylesheets`;
    `render_page_with_resources`:批量抓外链 JS/CSS → 文档顺序执行 →
    **动态脚本循环**(shim 记录运行时 appendChild 的 `<script src>`,
    `__moui_take_dynamic_scripts`,最多 4 轮)→ **timer pump**
    (`JsEngine::pump_events`:run_timer_checkpoint 驱动 setTimeout 回调,
    如 bing 的 sb_st → onPP 链)→ dump DOM → 外链 CSS 拼入 `<head>`;
    dump 为空回退原始 HTML 但仍注入 CSS(`inject_styles`)。
  - **URL 解析修复**:`resolve_location` 补无前导 `/` 的相对路径
    ("news.css" → host/news.css)。
  - **验证**:HN 渲染命令 **164 → 276**(外链 CSS 生效,真实样式);
    测试 50/50 全绿(新增 resolve_url 测试);端到端无 panic。
  - **边界**:bing 等 SPA 仍空白——其加载链(AMD `define/require`、
    `customEvents` 事件总线、visibility 事件)超出 js_engine 0.7.0
    兼容性;`_w`/`sj_be` 等脚本报错属 js_engine 复杂代码兼容差异。
    基础设施(并行抓取/动态脚本/timer/CSS 注入)对服务器渲染站点
    是质的提升。
  - **JS shim**(`engine/dom_shim.mbt`,~330 行,宿主经 eval 注入):在
    js_engine realm 内实现最小 `document`/`window`/`location`/`navigator`:
    createElement/createTextNode/createDocumentFragment、appendChild/
    removeChild/insertBefore/replaceChild、setAttribute/getAttribute/
    classList/style(cssText)/textContent/innerHTML、getElementById/
    querySelector(简化选择器)/querySelectorAll、addEventListener、
    `window === globalThis`(脚本 `var x` 与 `window.x` 一致)、
    DOMContentLoaded/load 派发(`__moui_dispatch_ready`)、重置、HTML
    序列化(`__moui_dump_html`)。
  - **宿主集成**(`engine/scripts.mbt` 扩展 + `page_render.mbt`):
    `JsEngine::new()` 安装 shim;`reset_dom(url)` / `dump_dom_html()` /
    `dispatch_ready()`;`render_html_with_js(source)` 执行内联脚本 → 影子
    DOM 序列化回 HTML → crater 渲染;无脚本页面原样渲染;dump 为空回退
    原始 HTML。`inject_json` 注入宿主数据、`call_json` 取回序列化结果。
  - **验证**:shim 8 测试 + app 集成测试(脚本 document.createElement
    建 DOM → 真实渲染出背景矩形);bing.com JS 错误 13→3;HN 无脚本
    回归不变。**边界**:bing 等 SPA 的 DOM 生成代码在**外链 `<script src>`**
    里,当前只执行内联脚本 → bing 仍空白;外链脚本抓取属于子资源加载
    里程碑(M3.5 待办)。
- M3a ✅ 网络(默认加载网页):
  - **当前实现**:`engine/net_bridge.c` + `net_bridge.mbt` —— detached
    pthread 线程里 `popen("curl -sL --max-time 20 [-x 代理] URL")`,
    stdout 写入加锁槽;主线程经 `Subscription::timer`(100ms)轮询
    `poll_fetch()`。app 侧 `Effect::task` 启动导航,`PollNetwork` 消息
    取回 HTML 并渲染。UI 不阻塞。代理默认 `http://127.0.0.1:7897`,
    `program(proxy=...)` 可覆盖。
  - **默认页 = `https://news.ycombinator.com`(纯服务器渲染)**:
    实测渲染 164 命令 / 58 链接 / 159 文本(无脚本)。bing.com 首页是
    SPA(主体 `<div id="hp_app">` 空壳,内容由 JS 生成),js_engine 无
    DOM bridge 时渲染仅 3 命令≈白屏——**这不是渲染 bug,是站点性质**;
    地址栏仍可访问 bing 等 JS 站点(显示空白,状态栏有脚本错误计数)。
  - **纯 MoonBit 栈待接入**:`engine/net.mbt`(async `fetch_page`,基于
    `moonbitlang/async/http`,支持 https/TLS、重定向跟随、代理 CONNECT)
    测试全绿,但 MoUI 同步 tick 无法直接 await 协程(无公开 spawn API,
    `internal/coroutine` 被可见性规则禁止),故当前用 curl 桥;
    后续可把 curl 桥换成纯 MoonBit 栈(需 async 生态提供公开 spawn 或
    MoUI 提供 async effect 通道)。
- 待办:DOM bridge(js_engine 侧 document/window 绑定)、滚动、历史、
  图片资源加载(页面外链 CSS/图片)、Web target(crater WASM 或
  js_engine wasm)。


## 1. crater 是什么(与本方案相关的部分)

mizchi/crater 是一个纯 MoonBit 实现的浏览器引擎(headless,Apache-2.0),
模块化发布,可按需 `moon add`:

| 模块 | 作用 |
|---|---|
| `mizchi/crater-core` | CSS 解析、htmlparser、color 等基础 |
| `mizchi/crater-dom` | DOM tree / Shadow DOM |
| `mizchi/crater-layout` | Taffy 移植的 CSS 布局 |
| `mizchi/crater-painter` | paint tree 模型(`/paint/model`)、CPU 光栅化、位图字体 |
| `mizchi/crater-renderer` | HTML → layout → paint tree → RenderedImage 编排 |
| `mizchi/crater-browser` | 浏览器壳:导航、交互、cookie/cache/http、BiDi |
| `mizchi/crater-browser-runtime` | JS 契约(ScriptExecutor / AsyncExecutionMode) |
| `crater/native` (browser/native) | V8 宿主(js_v8,可选重型依赖) |
| `mizchi/crater-wasm` | WASM component(wa.dev 分发,WIT 接口) |

### 关键公开 API(renderer 包,`renderer/pkg.generated.mbti`)

```
render_html_to_paint_tree(String, Size) -> PaintNode
render_html_to_paint_tree_json(String, Size) -> String
render_paint_tree_to_image(PaintNode, Int, Int) -> RenderedImage
render_html_to_image(String, Size) -> RenderedImage
render_html_to_layout_json(String, Size) -> String
```

`PaintNode`(`painter/paint/model`)字段全公开:id/tag/x/y/width/height/
overflow/scroll/clip/stacking_order/text/src/visual_polygon/children +
`PaintProperties`(背景色、border 四边宽/色、box_shadows、字体三要素、
opacity、pointer-events、border-radius、背景图等),且 `to_json_string()` 可
序列化——**是纯数据结构,可在 MoUI 侧直接遍历翻译**。

`RenderedImage` = `{ width, height, pixels : Array[Int] }`(CPU 光栅化,
ARGB 打包整数)——**像素帧可直接取出**。

### 浏览器壳(Browser,`browser/shell`,async fn raise HttpError)

- 导航:`navigate(url)` / `go_back` / `go_forward` / `set_html_content` /
  `get_current_url` / `activate_link_at(x, y)`
- 交互:`pointer_down_at/move_at/up_at` / `hover_at` / `scroll_up/down` /
  `handle_focused_key`(同步调用)
- JS:`execute_inline_js_async` / `set_js_runtime` / `tick_js` /
  `run_event_loop` / `execute_scripts`
- 配置:`set_dark_mode` / `set_enable_js` / `set_enable_cookies` /
  `set_incremental_reflow` / `set_image_cache_max_bytes` / `set_request_sandbox`
- 网络:`crater-browser-http`(fetch、cookie_jar、cache、RequestSandbox)

`browser(width, height)` 是唯一入口(native 下 JS runtime 默认 mock,
V8 可选注入)。

## 2. MoUI 侧可用机制(已验证)

| 机制 | 位置 | 用途 |
|---|---|---|
| `canvas(measure~, draw~)` 控件 | `moui/views/canvas/canvas.mbt` | ViewNode 自定义绘制:`PaintContext` 收集 `DrawCommand`,经 `ViewPaintPlan` 输出。网页内容翻译后注入点 |
| `DrawCommand` 27 变体 | `moui/core`(见 `moui/render/common/draw_plan.mbt`) | Clear / FillRect / StrokeRect / FillRoundedRect / FillRoundedRectBrush / DrawShadow / DrawText / DrawImage / PushClip / PushRoundedClip / PushTransform / PushOpacity / PushLayer / PushFilter / DrawPath / DrawShaderEffect / 缓存层命令 |
| `draw_platform_view_pixels(Bytes, w, h, stride, x, y, dw, dh)` | `moui/render/renderer_session.mbt` + `moui/core/platform_view_pixels.mbt` | 渲染器中立的宿主像素帧嵌入(Skia/Sun 已实现) |
| `moui_webview` addon | 仓库根 | addon 结构模板:host 协议 + views 控件 + 平台后端 |
| `AsyncImageLoader` | moui 内 | data URI / 本地文件图片异步解码,可直接复用于 `PaintNode.src` |
| `svg_import.mbt` | `moui/render/common` | "外部格式 → DrawCommand 翻译器"已有先例 |

## 3. 渲染桥接:三条路径

### 路径 A(推荐):PaintNode → DrawCommand 矢量翻译

递归遍历 PaintNode 树(按 stacking_order 排序),翻译成 DrawCommand 流,
注入 `canvas` 控件或专用 ViewNode 的绘制阶段。映射表:

| PaintNode 字段 | MoUI DrawCommand |
|---|---|
| `background_color` + 几何(x/y/w/h) | `FillRect`,border-radius 时 `FillRoundedRect` |
| 四边 border_width + border_color | `StrokeRect`,或四边 `FillRect`(不等宽时) |
| `box_shadows` | `DrawShadow`(x/y/blur/spread/color) |
| `text` + font_size/weight/family + color | `DrawText`(TextRun,frame=节点几何) |
| `src`(base64/data URI 图片) | `DrawImage`(复用 AsyncImageLoader 解码) |
| `visual_polygon` | `DrawPath` |
| `clip` / overflow / scroll | `PushClip`/`PopClip`(+ `PushTransform` 表达滚动偏移) |
| `opacity` | `PushOpacity`/`PopOpacity`(或 `PushLayer`) |
| `background_image` | `DrawImage` |
| `z_index` / `pointer_events` | 排序 / 命中测试 |

优点:复用 MoUI 全部渲染器(Skia/WGPU/Sun),字体用系统字体,滚动只重排
命令不用重光栅;增量重排时 crater 的 diff 机制 + MoUI 缓存层
(`BeginCachedLayer`)可做脏区优化。复杂度 ≈ `svg_import.mbt`(同类翻译器),
估 400–700 行 + 测试。

### 路径 B(备用):RenderedImage → draw_platform_view_pixels

`render_paint_tree_to_image` 得到 `{pixels: Array[Int]}`,打包 Bytes 后走
`draw_platform_view_pixels`(与 moui_webview 相同的像素嵌入通道)。
适合 2–3 天快速原型验证"浏览器窗口里真的出现网页",但滚动/缩放/交互要
整帧重光栅,且字体是 crater 位图字体(近似),不做主路径。

### 路径 C(混合,长期)

矢量翻译为主;图片/复杂合成内容降级为路径 B 的局部像素。需要 crater 提供
"局部 paint 输出"配合,列为远期。

## 4. 交互与事件循环(主要工程风险)

- 数据流:MoUI 事件(pointer/key/scroll)→ crater `pointer_down_at` /
  `handle_focused_key` / `scroll_down`(同步)→ DOM 事件 → JS 回调 →
  `tick_js` / 重排 → 新 PaintNode → 重新翻译绘制。
- **异步桥**:`navigate`/`fetch` 等是 `moonbitlang/async` 的 `async fn`。
  MoUI **已在用** `moonbitlang/async@0.20.2`(`moui/moon.mod`;
  `run_async_pump` 本身是 async fn,每帧 `@async.sleep` 即调度点),
  因此不是"引入新运行时",而是把 crater 的 future 放进应用层任务队列,
  每帧 tick poll 一次,完成后作为 message 投递。同步的 pointer/key
  调用直接执行。参考先例:MoUI 已有"异步完成 → 请求重绘"模式
  (`AsyncImageLoader`)。网络 IO 走宿主后台线程,避免阻塞 UI 帧。
- 坐标:MoUI 事件坐标减控件 frame 原点 → crater 视口坐标。

## 5. 模块结构建议

新 addon(仿 `moui_webview`,第三方依赖隔离在 addon 内,符合 app 依赖边界):

```
moui_crater/                  # 新 addon(独立模块,依赖 wzzc-dev/moui + mizchi/crater-*)
├── host/                     # crater 会话封装:Browser 生命周期、async 桥、事件循环接线
├── translate/                # PaintNode → DrawCommand 翻译器 + 像素打包 + 测试
├── views/                    # @views.crater_web_view(...) 控件(ViewNode + canvas 注入)
└── (M3+) js/                  # js_engine 适配器(实现 crater JsRuntime trait)
examples/browser/             # 演示 app:地址栏 + 标签页 + crater_web_view
```

依赖边界处理:`checks/release-modules.json` 注册新模块;`moui_crater` 依赖
`mizchi/crater-*` 需 pin 版本(见风险 R6)。

## 6. 里程碑

| 里程碑 | 内容 | 工作量 | 风险 |
|---|---|---|---|
| M1 静态渲染 | `moui_crater` 骨架 + 翻译器 + example 显示本地 HTML(`set_html_content` / `render_html_to_paint_tree`),无 JS | 1–2 周 | 低(核心价值先行验证) |
| M2 交互 | pointer/key/滚动注入、链接导航、async 事件循环桥 | ~1 周 | 中(async 集成) |
| M3 网络 + JS | crater-browser-http 沙箱 + js_engine 适配器(纯 MoonBit,四目标) | 1–2 周 | 中(见 §7 R8) |
| M4 Web 目标 | `mizchi/crater-wasm` 组件对接 MoUI web 渲染器(探索性) | 未定 | 高(component 互操作) |

JS runtime 取舍:V1 不需要任何 JS 引擎——crater `set_js_runtime` 默认
mock,静态 HTML + CSS 渲染完全不依赖 JS;M3 首选 `dowdiness/js_engine`
适配器(见 §9),V8 仅作为远期 native 性能选项。

## 7. 风险与缓解

| # | 风险 | 缓解 |
|---|---|---|
| R1 | async 任务推进与 MoUI 帧节奏的集成 | MoUI 已依赖 `moonbitlang/async`(`run_async_pump` 每帧即有调度点);应用层持有 crater future 队列,每帧 poll;网络走后台线程;M2 专门验证 |
| R2 | 字体度量差异:crater 布局用近似测量,MoUI 系统字体绘制可能有换行/溢出偏差 | 接受保真度偏差;或按 MoUI 测量修正文本宽度(远期) |
| R3 | crater 是 0.x 快速迭代,API 未稳定 | pin 版本;翻译器只依赖 model 层稳定字段 |
| R4 | crater 渲染精度有限(WPT 84–100%、无 GPU) | 定位"演示/实验浏览器",不承诺 Chromium 级兼容 |
| R5 | JS 引擎性能/兼容性 | 首选 js_engine(纯 MoonBit):tree-walking 较慢、test262 执行通过率 91%(ES2022 55%),现代框架产物可能不兼容——演示/静态/轻交互页面可接受;bounded 检查点 API 防死循环;V8 仅远期性能选项 |
| R6 | 第三方依赖违反 app 边界 | 隔离在 addon(同 `moui_webview` 先例),过 release-modules 校验 |
| R7 | 中文/CJK 字体在 crater 布局与 MoUI 绘制间的度量差异 | M1 原型即用中英混排页面验证 |

## 8. 开放问题

1. crater 的 `PaintNode.text` 是否带换行/测量元数据(决定 R2 修正难度)——立项后读 `painter/paint/model` 源码确认。
2. `mizchi/crater-browser-runtime` 的 `trait JsRuntime` 方法签名(决定 js_engine 适配器工作量,估 ≤10 个方法)——立项后读该包源码确认。
3. js_engine 0.7.0 是否含 bounded/可中断 API(`eval_bounded` 等为 Stage 4 特性)——不含则适配器只用 `Engine.eval` / `call_json`(老 API,不受影响)。
3. wasm-gc 目标下 crater 各包能否直接依赖(还是必须走 component)——影响 M4。
4. crater 增量重排(`set_incremental_reflow` + paint diff)与 MoUI 缓存层的对接方式。

## 9. JS 引擎选型(调研结论:js_engine 可用且优于 V8)

crater 的 JS 引擎是**插件化的**:契约 `trait JsRuntime` 定义在独立发布包
`mizchi/crater-browser-runtime`(`@runtime_impl`),`Browser::set_js_runtime`
注入;默认实现是 mock,另有 native V8(`browser/native/js_v8`)。
crater 的 JS 桥是「DOM → 序列化 JS 代码 → eval → JSON 取回」模式
(`create_dom_init_code` / `serialize_dom_*` / `enqueue_script` /
`execute_script_task` / `process_script_tasks`),不要求嵌入 DOM 对象模型。

**`dowdiness/js_engine`(mooncakes 0.7.0)与这个模式高度匹配**:

- 纯 MoonBit 树遍历解释器,四目标:native / JS / Wasm / **Wasm-GC**
  —— MoUI 桌面与 Web 版用同一引擎;V8 只能 native 且需 C++ 链接
- `Engine.eval(source)` + `call_json(name, args)`(严格 JSON 边界,
  不触发 getter/toJSON/Proxy trap)——正好对应 crater 的序列化桥
- bounded API:`eval_bounded` / `call_json_bounded` /
  `run_microtask_checkpoint_bounded` / `run_timer_checkpoint_bounded` /
  `InterruptionHandle` / `ExecutionPolicy` —— 每帧一个可中断检查点,
  **与 MoUI 同步 tick 模型天然契合**,还能防死循环;微任务/定时器
  检查点对应 crater 的 scheduler 集成
- 宿主对象注入(`def_builtin` / `make_host_object`):可给页面暴露有限宿主 API
- 适配器工作量:一个 `trait JsRuntime` impl + 测试

**已知短板**:test262 执行通过率 91.3%(ES2022 仅 55%:class fields/
私有字段等缺),现代前端框架产物可能部分不兼容;性能比 V8 慢 1–2 个
数量级;README 明示**不是安全沙箱**(与 crater 自身定位一致,不跑
不可信脚本)。

## 参考

- crater README:https://github.com/mizchi/crater
- renderer API:https://github.com/mizchi/crater/tree/main/renderer
- browser shell:https://github.com/mizchi/crater/tree/main/browser/shell
- WASM component 文档:https://github.com/mizchi/crater/tree/main/wasm
- MoUI:docs/architecture-map.md、docs/renderer-capability-report.md、
  `moui/views/canvas/canvas.mbt`、`moui_webview/`(addon 模板)
