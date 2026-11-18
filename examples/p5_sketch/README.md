# p5 core × MoUI

一个用 MoonBit 实现的 p5.js 2D 核心。它以
[`bobzhang/p5.mbt`](https://github.com/bobzhang/p5.mbt) 为参考，但**不是**
把 p5.mbt 的 JS 版本原样复制过来：本实现把绘制后端换成了 MoUI 的
renderer-neutral `DrawCommand` 流，因此同一份 sketch 可以跑在原生 Skia、
Web wasm-gc，或只做记录的无头 `Recorder` 上。

本目录是一个独立的 MoonBit module（`examples/p5_sketch`），包含：

- `p5/`：不依赖 MoUI 的 sketch 核心（生命周期、图形、颜色、变换、文本、数学、输入、路径、Recorder）。
- `p5/http/`：native-only 的异步 `https:` 图片 worker（`load_image_async` 的宿主实现）。
- `p5/moui/`：MoUI 适配层（`MoUISurface` + `SketchView`）。
- `app/`：三个可交互示例和 TEA 外壳。
- `macos_skia/`、`web_wasm/`：原生与 Web 入口。

---

## 1. 对 p5.mbt 的分析

### 1.1 功能范围

p5.mbt 是 p5.js 2.x 2D 核心到 MoonBit 的移植，目标后端是 JavaScript +
HTML Canvas。README 把它覆盖的范围列为：

| 领域 | 内容 |
|---|---|
| 生命周期 | `setup` / `draw`、`preload`、帧率节流、`no_loop` / `loop_` / `redraw`、`push` / `pop`、clipping |
| 图形 | point / line / rect / ellipse / arc / triangle / quad / bezier / spline、`begin_shape` 的 Path/Points/Lines/Triangles/... 模式、圆角矩形、`rect_mode` / `ellipse_mode`、曲线点与切线 |
| 颜色 | `color` / `fill` / `stroke` / `background` / `clear` / `erase`、`blend_mode`、`color_mode` 自定义最大值、RGB/HSB/HSL/HWB/Lab/LCH/OKLab/OKLCH、`lerp_color`、通道访问器 |
| 变换 | translate / rotate / scale / shear / apply_matrix / reset_matrix / angle_mode |
| 字体 | 多行、按盒宽换行、截断、`text_size` / `text_leading` / `text_font` / `load_font` / `text_style` / `text_align` / `text_wrap`、测量 |
| 图像 | load_image / create_image / image / image_region / tint / pixels / get / set / filter / create_graphics / save_canvas，以及对像素的 CPU 过滤 |
| 事件 | 鼠标/指针/触摸、按下/释放/点击/双击/移动/拖拽/滚轮、键盘 key/code/keyCode、`window_resized` |
| 环境 | frame_rate / delta_time / millis / cursor / fullscreen / pixel_density / resize_canvas / focused |
| 数学 | Vector 全量运算、Perlin noise、p5 的 LCG random、Gaussian、map/constrain/lerp/dist/... |
| 数据与 DOM | nf/nfc/nfp/nfs、split_tokens、shuffle、hex/binary、日期、localStorage、load_strings/load_json，以及 `create_div` 等 DOM 元素 |
| 录制 | `record(frames=...)` 离线逐帧渲染并导出视频 |

p5.mbt 的包拆分：

| 包 | 内容 | target |
|---|---|---|
| `bobzhang/p5` | sketch API、`P5`、`run`、`Image`、`Element` | JS |
| `bobzhang/p5/math` | `Vector`、`Noise`、`Random`、`Matrix2D`、标量函数 | 全平台 |
| `bobzhang/p5/color` | `Color` 与色彩空间 | 全平台 |
| `bobzhang/p5/shape` | p5 2.x shape 模型 → canvas path | 全平台 |
| `bobzhang/p5/filters` | CPU 图像滤镜 | 全平台 |
| `bobzhang/p5/dom` | Canvas/DOM/Image 的 JS FFI | JS |

它的核心抽象是 `Surface` trait：sketch 自己算好变换和样式，把 path、文本、
像素操作交给后端。`CanvasSurface` 画到 HTML canvas，`Recorder` 把每次调用
记成一行文本，所以数学和绘制行为可以在 Node 里无头测试。

### 1.2 核心 API 形态

p5.mbt 采用 p5.js 的 **instance mode**：所有全局函数都是 `P5` 的方法，
`setup`/`draw` 等回调收到同一个 `p : P5`。

```moonbit
@p5.run(
  setup=p => p.create_canvas(400, 400),
  draw=p => {
    p.background(220)
    p.fill((237, 34, 93))
    p.circle(p.mouse_x, p.mouse_y, 50)
  },
)
```

与 p5.js 的对应关系（摘自它的 README）：

| p5.js | p5.mbt |
|---|---|
| `setup()` / `draw()` | `@p5.run(setup=..., draw=...)` |
| `mousePressed()` | `@p5.run(mouse_pressed=...)` |
| `createCanvas(w, h)` | `p.create_canvas(w, h)` |
| `width` / `mouseX` / `frameCount` | `p.width` / `p.mouse_x` / `p.frame_count` |
| `fill(200)` / `fill(255, 0, 0)` | `p.fill(200)` / `p.fill((255, 0, 0))` |
| `ellipse(x, y, w, h)` | `p.ellipse(x, y, w, h=...)` |
| `random(5, 10)` | `p.random_range(5, 10)` |
| `textAlign(CENTER, CENTER)` | `p.text_align(HCenter, vertical=VCenter)` |
| `colorMode(HSB, 1)` | `p.color_mode_max(HSB, 1)` |
| `loop()` | `p.loop_()`（`loop` 是 MoonBit 关键字） |

约定：camelCase → snake_case；重载改成可选标签参数、不同函数名，或
`ColorArg` trait（数字、数字 tuple、CSS 字符串、`Color` 都接受）；常量用
enum 构造器。

### 1.3 示例

p5.mbt 仓库里有六个示例，覆盖了 API 的主要组合：

| 示例 | 展示 |
|---|---|
| `shapes` | 基本图形、Bézier/spline、contour、HSB、变换、文本、鼠标 |
| `images` | `preload` 里的 `load_image`、滤镜、tint、逐像素修改、graphics buffer |
| `flowfield` | Vector、Perlin noise、slider/button |
| `input` | 键盘、鼠标、滚轮、`clip`、`erase` |
| `data` | `load_json`、`load_strings` |
| `history` | 104 秒、完全用 p5.mbt 做的短片；`record` 离线导出 |

---

## 2. 本实现的范围与取舍

### 2.1 为什么不是逐行复制

p5.mbt 的 JS 版依赖 DOM、HTML Canvas、`Path2D`、图片元素和浏览器事件。
把这些 FFI 搬进 MoUI 没有意义；本实现保留它的**架构**（sketch 状态机 +
`Surface` 后端 + 无头 Recorder），但把后端换成 MoUI 的绘制命令流：

```text
             ┌──────────────┐
             │    Sketch    │  状态、API、矩阵、颜色、文本、输入
             └──────┬───────┘
                    │ Surface trait
        ┌───────────┼────────────────┐
        │           │                │
   Recorder    MoUISurface      NullSurface
   (测试)      (DrawCommand)     (未绑定帧)
                    │
             MoUI DrawCommand
                    │
        ┌───────────┼────────────┐
      Skia        Web wasm     (其他 MoUI renderer)
```

核心包 `p5` 不知道 MoUI 的存在，可以在 `moon test` 里直接跑；MoUI 只在
`p5/moui` 出现。这与 p5.mbt 的 `p5` / `p5/math` / `p5/color` / `p5/dom`
分层是同一个思路。

### 2.2 已实现（可运行）

| 领域 | API |
|---|---|
| 生命周期 | `Sketch::new`、`setup`、`draw`、`frame(now_ms)`、`frame_count`、`delta_time`、`millis`、`no_loop` / `loop_` / `redraw` / `request_redraw`、`push` / `pop`、`reset_sketch` |
| 画布 | `background`、`clear`、`resize_canvas`、`clip_path_begin` / `clip_path_end` / `clip`（`PushPathClip`；Skia 真路径，其他后端退化为包围盒）；`SketchView::new` retained display list / `new_stateless` 每帧替换 |
| 样式 | `fill`、`no_fill`、`stroke`、`no_stroke`、`stroke_weight`、`stroke_cap`、`stroke_join`（Skia/Sun 已渲染）、`blend_mode`（13 种；Skia/Sun/Canvas2D 真实合成，WGPU/Metal 退化）、`smooth` / `no_smooth` |
| 颜色 | RGB / HSB / HSL 输入、`color_mode` / `color_mode_max` / `color_mode_maxes`、`color`、`lerp_color`、`red` / `green` / `blue` / `alpha` / `hue` / `saturation` / `brightness` / `lightness`、十六进制与常用 CSS 命名色 |
| 图形 | `point`、`line`、`rect` / `square`（四角半径一致时走 `FillRoundedRect` SDF 图元；`circle` 走同一图元）、`ellipse` / `circle`、`arc`（Open/Chord/Pie）、`triangle`、`quad`、`bezier`、`curve`、`begin_shape` / `begin_contour` / `end_contour` / `vertex` / `quadratic_vertex` / `bezier_vertex` / `spline_vertex` / `curve_vertex` / `end_shape`、`spline_tightness` / `curve_tightness` |
| 模式 | `rect_mode`、`ellipse_mode`、`angle_mode` |
| 变换 | `translate`、`rotate`、`scale`、`shear_x` / `shear_y`、`apply_matrix`、`reset_matrix`、`get_matrix` |
| 文本 | `text_size`、`text_font`、`text_style`、`text_leading`、`text_align`、`text_wrap`、`text`（多行、按 `max_width` 换行、按 `max_height` 截断；`stroke()` 走 `TextRun` 描边，`no_fill()` 时为 stroke-only 描边文字）、`text_width`、`text_ascent`、`text_descent` |
| 图像/像素 | `load_image` / `try_load_image`（同步 PNG data URI、本地文件、`file://`）、`load_image_async` + `ImageFetcher`（宿主非阻塞 fetch）、`create_image`、`create_graphics`（矢量 recording sketch + `image()` replay）、`Image::get` / `set` / `fill` / `pixels` / `load_pixels` / `update_pixels` / `resize` / `copy` / `filter` / `tinted` / `to_png_bytes` / `save`、`tint` / `no_tint`、`image`；CPU 滤镜（threshold/gray/opaque/invert/posterize/blur/erode/dilate）；MoUI `RgbaImage` 可写离屏 buffer，adapter 编码 PNG data URI → `DrawCommand::DrawImage` |
| 数学 | `random` / `random_max` / `random_range` / `random_choice` / `random_gaussian` / `random_seed`、`random2d` / `random3d`、`noise` / `noise_seed` / `noise_detail`、`sin` / `cos` / `tan` / `asin` / `acos` / `atan` / `atan2`、`map` / `constrain` / `lerp` / `dist` / `mag` / `norm` / `sq` / `fract` / `round` / `degrees` / `radians` |
| Vector | `new`、`copy`、`set`、`add` / `sub` / `mult` / `div`、`mag` / `mag_sq`、`dot` / `cross`、`normalize` / `set_mag` / `limit`、`heading` / `rotate`、`dist`、`lerp`、`angle_between`、`array` |
| 输入 | `pointer_down` / `pointer_move` / `pointer_up` / `pointer_clicked` / `pointer_double_clicked` / `pointer_wheel`、`touch_started_at` / `touch_moved_to` / `touch_ended_at`、`on_touch_started` / `on_touch_moved` / `on_touch_ended`、`touches`（含 `id`/`pressure`）、`text_input` / `composition_start/update/end`、`composing` / `composition_text` / `last_input_text`、`key_down` / `key_up` / `key_typed_input` / `key_is_down`（`key` + 物理 `code` + `key_code`）、`mouse_x` / `mouse_y` / `pmouse_*` / `moved_*` / `mouse_is_pressed` / `mouse_button` / `key` / `code` / `key_code` / `focused` |
| 无头验证 | `Recorder`（逐调用文本日志）、`NullSurface`、`SketchView::handle_input` |

### 2.3 为 p5 补充的 MoUI 框架能力

本轮在 `moui/core` 增加了两个透明 observer modifier：

- `View::on_pointer((PointerEvent, Rect) -> Msg)`：转发每个指针采样
  （Move/Down/Up/Cancel/Exit、滚轮），带 child frame；`Down` 捕获指针，
  几何命中的最近 focusable wrapper 负责获得焦点。它不拥有按压状态、
  不加语义角色。
- `View::on_key((KeyboardEvent) -> Msg)`：让元素 focusable，只在聚焦时
  转发键盘事件。
- `KeyboardEvent.code`：新增 DOM 风格物理键字段；window-hosted 后端从平台
  `PhysicalKey`（`KeyA`、`Digit1`、`ArrowLeft` 等）派生，宿主没有物理键
  身份时为空串。`on_key` 把它原样带给应用。
- `View::on_keyboard_input(key_handler, text_input_handler)`：一个 focusable
  wrapper 同时接收 `KeyboardEvent` 与 `TextInputEvent`，避免两个独立
  focusable modifier 抢焦点；p5 适配层用它接 IME。
- `@graphics.RgbaImage`：可写、renderer-neutral 的 RGBA8 离屏 buffer
  （get/set/fill/pixels）；p5 adapter 把它编码为 PNG data URI 后走
  `DrawCommand::DrawImage`，Skia/Sun/browser 共用同一条图片路径。

这些能力是通用的 canvas/custom-paint 能力，不是 p5 专用；p5 适配层
用它们替换了原来的 `on_drag_with_frame` + `on_tap_with_frame` 组合，从而补上
hover、滚轮、画布外 release 和键盘输入。核心测试从 199 增至 203（含 `KeyboardEvent.code` 与 `on_keyboard_input`）。

### 2.4 有意未实现

| 未实现 | 原因 |
|---|---|
| WGPU/Metal 的 Source blend 与可分离模式 | 同步加载覆盖 data URI、本地文件和 `file://`；`load_image_async` + native `p5/http` 已把 `https:` 放到 async worker；主画布 readback 在 macOS 走 `skia_raster`、Web 走 `web_raster`（示例自带 `p5_raster` import 命名空间 + 离屏 2D 解释器）。像素 overlay 的 `BlendMode::Source` 在 WGPU/Metal 仍退化为 source-over（不可擦除）。 |
| DOM 元素（`create_div` 等） | p5.mbt 的 DOM 是浏览器 FFI；MoUI 用 `views` 构建 UI，不需要在 sketch 里创建 DOM。 |
| WebGL / WebGPU / 3D / shader / framebuffer | 与 p5.mbt 一样不在 2D 核心范围。 |
| 视频 / 音频 / 摄像头 | 依赖浏览器媒体元素。 |
| `load_json` / `load_strings` / `save_*` | 属于宿主 I/O；应由 app 的 service/effect 层完成。 |
| `record` 视频导出 | 需要逐帧编码；MoUI 侧可以后续用 `moui screenshot` 逐帧做离线渲染。 |
| `textToPoints` / SVG 导入导出 / Table / XML | p5.mbt 同样未移植。 |
| 非 Skia 后端的路径裁剪 | `PushPathClip(PathSpec)` 已进入 draw-command 协议；Skia 用 `clip_path` 真正按路径裁剪，Sun/TUI/WGPU/Metal/Web 目前按几何 bounds 退化为矩形裁剪。 |
| 非 Skia 后端的文本描边 | `TextRun.stroke_color/stroke_width` 已进入协议；Skia 在填充下先画描边 pass，Sun/Web/WGPU/Metal/TUI 目前忽略描边、只画填充。 |
| 主画布像素 readback / 像素级持久 canvas | 已实现 retained **display list**（p5 adapter 层），但 MoUI 不保留上一帧 RGBA；主画布 `get/set/pixels` 仍需要 renderer readback。 |

---

## 3. 项目结构

```text
examples/p5_sketch/
├── moon.mod                 # examples/p5_sketch，依赖 moui / skia / web
├── README.md                # 本文件
├── p5/                      # 核心：不依赖 MoUI
│   ├── moon.pkg
│   ├── math.mbt             # 常量、标量、Matrix、Random、Noise、Vector
│   ├── color.mbt            # Color、RGB/HSB/HSL、ColorArg、CSS 解析
│   ├── path.mbt             # PathCmd、矩形/圆角/椭圆/弧/Bézier
│   ├── types.mbt            # FontSpec、TextMetrics、对齐、BlendMode、StrokeCap
│   ├── surface.mbt          # Surface trait、NullSurface、Recorder
│   ├── image.mbt            # Image / create_image / create_graphics / image
│   ├── image_filters.mbt    # CPU filters + tinted()
│   ├── graphics.mbt         # create_graphics recording surface + replay
│   ├── png_decode.mbt       # PNG data URI / local file decoder for load_image
│   ├── png_encode.mbt       # Image → PNG bytes / Image::save
│   ├── sketch.mbt           # Sketch 状态、生命周期、图形、变换、push/pop
│   ├── api.mbt             # 文本、数学、输入、颜色访问器
│   └── core_test.mbt        # 37 个无头测试
├── web_raster/              # wasm-only CanvasRasterizer（JSON + p5_raster import）
│   ├── serialize.mbt        # 命令流 → 紧凑 JSON（自写转义）
│   └── raster.mbt           # 字符串句柄 ABI、capture、install/self_test
├── p5/http/                 # native-only 异步 https 图片 worker
│   ├── loader.mbt           # RemoteImageLoader / with_loader
│   └── loader_wbtest.mbt    # 队列投递与拒绝 cleartext 测试
├── p5/moui/                 # MoUI 适配
│   ├── moon.pkg
│   ├── view.mbt             # MoUISurface、SketchView、P5Canvas ViewNode
│   ├── image_encode.mbt     # RGBA → PNG data URI（ImageRun source）
│   ├── pixels.mbt           # CanvasRasterizer、capture/save、主画布像素 API
│   └── adapter_test.mbt     # 13 个 DrawCommand/输入/retained/readback 适配测试
├── skia_raster/             # native-only 离屏 Skia CanvasRasterizer
│   ├── raster.mbt           # DrawCommand → RGBA p5.Image（含反预乘）
│   └── raster_wbtest.mbt    # 像素回读、半透明混合、save_canvas 测试
├── app/                     # 三个示例 + TEA 外壳
│   ├── moon.pkg
│   ├── demos.mbt            # shapes / flow field / bouncing balls / intro
│   └── app.mbt              # Model/Msg/update/view + program()
├── macos_skia/
│   └── main.mbt             # 原生入口
└── web_wasm/
    ├── main.mbt             # wasm-gc 入口
    └── index.html           # 本地 Web 预览页
```

`p5` 的 `supported_targets` 是 `+native+js+wasm-gc+wasm`；它只依赖
`moonbitlang/core/{math,buffer,compress/zlib,encoding/base64}` 与
`moonbitlang/x/fs`。`p5/http` 是 native-only 的 async worker，依赖
`moonbitlang/async` + `moonbitlang/async/http`。`p5/moui` 依赖 `p5` +
`wzzc-dev/moui/core`，`app` 依赖 `p5`、`p5/moui`、`moui` 和 `moui/views`。

---

## 4. 使用方式

### 4.1 最小 sketch

```moonbit
let view = @p5m.SketchView::new(900.0, 540.0)
let p = view.sketch()

p.setup(p => {
  p.background((18.0, 18.0, 24.0))
})

p.draw(p => {
  p.fill((237.0, 34.0, 93.0))
  p.circle(p.mouse_x, p.mouse_y, 50.0)
})
```

把 `view.view()` 放进任意 MoUI 视图树即可：

```moonbit
let canvas = view.view().map(input => Msg::Canvas(input))
```

`view.view()` 返回 `@moui.View[CanvasInput]`；`CanvasInput` 是：

```moonbit
pub(all) enum PointerPhase {
  Move
  Down
  Up
  Cancel
  Exit
}

pub(all) enum CanvasInput {
  Pointer(PointerPhase, Double, Double, Int32, Int32, Double)
  Wheel(Double, Double, Double)
  Key(String, String, Bool, String?)
  TextInput(@core.TextInputEvent)
}
```

`Pointer` 的参数顺序是 `phase, x, y, button, id, pressure`：p5 按钮号
0 左/1 中/2 右，`id` 是 MoUI pointer stream，`pressure` 已归一化到 0..1。
`Wheel` 的第三个参数是垂直滚轮增量；`Key` 是键名、物理 `code`、按下状态和可打印文本；`TextInput` 携带 MoUI 的 IME/文本输入事件。
短距离的 press→release 会由 `SketchView` 合成 `mouse_clicked`；320ms 内同位置的
第二次会继续合成 `mouse_double_clicked`（仅 primary id 0）。

在 `update` 中把消息转回 sketch：

```moonbit
Canvas(input) => {
  view.handle_input(input)
  model
}
```

`SketchView` 内部用新增的 MoUI 原始事件 modifier 接线：

- `View::on_pointer`：每个 `PointerEvent`（Move/Down/Up/Cancel/Exit 和滚轮）都带 child frame；
  `Down` 会捕获指针，`Move` 持续更新 hover 位置，滚轮转成 `Wheel`；
  几何命中会把焦点交给 `on_key` 的 focusable wrapper。
- `View::on_key`：canvas 变成 focusable，聚焦后转发每个 `KeyboardEvent`；
  适配层把它送给 `key_down`/`key_up`/`key_typed_input`。

坐标会减去 canvas 的 `frame.origin`，所以 sketch 看到的是画布局部坐标。

图片加载分同步与非阻塞两条路径：

```moonbit
// data URI、本地文件、file://
let logo = p.load_image("assets/logo.png")

// 非阻塞：返回 1x1 透明占位图，远端字节回来后原地填充
let remote = p.load_image_async("https://example.com/logo.png", on_load=img => {
  // 可在这里通知 app / view 重绘
})
```

`load_image_async` 只负责投递；宿主用 `Sketch::set_image_fetcher` 或
`set_default_image_fetcher` 安装 `ImageFetcher`。macOS 入口已安装
`p5/http` 的 native worker，仅接受 `https:`。循环中的 sketch 会自动重绘；
`no_loop` 的 sketch 应在 `on_load` 里触发一次 app 状态更新或重绘请求。

主画布 readback 通过宿主的 `CanvasRasterizer` 完成：

```moonbit
let snapshot = view.capture_image()   // 当前命令流 → p5.Image
view.save_canvas("frame.png")         // 截图写 PNG

// 主画布像素缓冲区
let buffer = view.load_pixels()
view.set_pixel(0, 0, @p5.Color::rgb(255.0, 0.0, 0.0))
view.update_pixels()                  // 作为 overlay 叠加到后续帧
```

macOS 入口安装 `skia_raster`（离屏 Skia surface），按 `s` 可保存当前
canvas。overlay 通过 `BlendMode::Source` 层提交（Skia/Sun/Canvas2D 精确
替换颜色与 alpha，可擦成透明；WGPU/Metal 退化为 source-over）。

### 4.2 颜色写法

MoonBit 没有变参重载，颜色按 p5.mbt 的约定用 tuple：

```moonbit
p.fill(200.0)                     // 灰度
p.fill((255.0, 0.0, 0.0))         // RGB
p.fill((0.0, 0.0, 255.0, 128.0))  // RGBA
p.fill("red")                     // 命名色
p.fill("#ff8000")                 // hex
```

`color_mode(HSB)` 之后同样的数字按 HSB 解释；默认 max 是
`360/100/100/1`。`color_mode_max(HSB, 1.0)` 会把四个通道都设为 1。

⚠️ **alpha 通道的范围是模式相关的**（p5.js 语义）：`fill((r, g, b, a))`
在 RGB 模式下 alpha 按 **0..255** 解释（`fill((255,0,0,128))` 是半透明），
HSB/HSL 模式下按 **0..1**。在 RGB 模式里传 0..1 的 alpha（如
`fill((r,g,b,0.5))`）会得到 ≈1/255 的近透明色，表现为"整段内容不显示"——
Intro 所有半透明颜色都经 `intro_fill` / `intro_stroke` 助手换算。

### 4.3 生命周期与时间

`Sketch::frame(now_ms)` 返回 `Bool`，表示这一帧是否真的执行了 `draw`：

- 第一次调用执行 `setup`，然后执行 `draw`，`frame_count == 1`。
- 同一个 `now_ms` 重复 paint 不会重复推进帧计数。
- `no_loop()` 之后只在输入触发 `request_redraw` 或显式 `redraw` 时绘制。
- `loop_()` 恢复逐帧绘制。

`SketchView` 在 `paint` 里返回 `ViewPaintPlan::animating_commands`（循环时），
让 MoUI runtime 持续请求帧；暂停时返回普通 `commands`。

---

## 5. 与 p5.js / p5.mbt 的语义差异

### 5.1 持久 display list，而不是持久像素

`SketchView::new` 现在默认是 p5 风格的 **retained display list**：

- 每帧新命令追加到历史，paint 时重放整段历史
- 不透明 `background()`、`clear()`、`reset_sketch()` 会推进
  `Sketch::canvas_epoch`，adapter 据此丢弃旧历史
- 半透明 `background()` 不重置，历史继续累积，因此 p5 的“半透明矩形拖尾”
  对**矢量命令**有效
- `SketchView::new_stateless()` 保留旧行为：每帧替换，不累积

这不是像素级持久 canvas：MoUI 仍不保留上一帧 RGBA，也没有主画布
`get()/set()/pixels` readback。逐像素效果仍应使用 `Image`/`RgbaImage`
或 app 侧状态。

### 5.2 输入能力

MoUI core 新增了 `View::on_pointer` 和 `View::on_key`，p5 适配层已使用它们：

- 未按下时的鼠标移动会更新 `mouse_x`/`mouse_y`，触发 `mouse_moved` 和重绘。
- 按下后拖动会触发 `mouse_dragged`；捕获指针后移出 canvas 仍能收到 Move/Up。
- 滚轮触发 `mouse_wheel`，并同步光标位置。
- 点击 canvas 后获得焦点，键盘事件进入 `key_down`/`key_up`/`key_typed_input`；
  `key_code` 由适配层按常用键映射（Enter/Escape/方向键/空格/单字符等）。
- p5 按钮号与 MoUI 的归一化按钮号会转换（MoUI 右键=1 → p5 右键=2）。
- **每个** pointer stream 都会更新 `touches` 并触发 touch 回调；primary id 0
  同时驱动鼠标状态。`touches` 条目带 MoUI stream id 和归一化 `pressure`
  （1.0 表示宿主未提供压力信号）；`win_x/win_y` 在本适配层是 canvas 局部坐标。
  多指按 id 独立更新/移除，互不覆盖。

双击已由 `SketchView` 合成：同一位置 5px 内、320ms 内的第二次短
press→release 会调用 `pointer_double_clicked`。注意 `no_loop()` 后 runtime
不再持续请求帧，`millis` 只在重绘/输入触发时推进；需要持续时钟的暂停态
应保留 loop 或用 `TimerSource` 驱动重绘。

IME / 文本输入现在走 `View::on_keyboard_input`：`InsertText`/`ReplaceText`
触发 `text_input`，`CompositionStart/Update/End` 更新 `composing` /
`composition_text` 并触发对应回调；`CompositionEnd` 的提交文本写入
`last_input_text`。`SetSelection`/`DeleteRange`/`DeleteSurrounding` 没有
对应的 p5 sketch 文本模型，当前被忽略。

### 5.3 渲染差异

- 路径 clip 已走 `PushPathClip`；Skia 是真实路径裁剪，其他后端退化为几何 bounds 矩形。
- 文本描边走 `TextRun.stroke_color/stroke_width`；Skia 是描边 pass 叠在填充下，
  其他后端忽略描边只画填充。`no_fill()` + `stroke()` 时填充为**透明**
  （真 stroke-only 描边字），不支持描边的后端因此画不出文字——如实降级。
- `blend_mode` 映射到 MoUI 的 14 种 `BlendMode`：Multiply/Screen/Overlay/
  Darken/Lighten/Add/Difference/Exclusion/HardLight/SoftLight/Dodge→ColorDodge/
  Burn→ColorBurn 在 Skia、Sun、Canvas2D 上真实合成；`Source`（精确替换，
  含 alpha）在 Skia/Sun/Canvas2D 可用；WGPU/Metal 的固定混合管线表达不了
  可分离模式，退化为 SourceOver。
- `stroke_cap`/`stroke_join` 已在 Skia/Sun 的 `PathSpec` 绘制中生效；Web/WGPU/Metal 仍可能使用后端默认值。
- 图像最小闭环把 `Image` 的 RGBA buffer 每帧编码成 PNG data URI 再交给
  `DrawImage`；没有增量编码/纹理缓存，大图或每帧改像素会有编码开销。
- `create_graphics` 返回 recording `Sketch`，可通过 `image()` 重放；文本度量
  在 recording 阶段使用 fallback，replay 时由父 surface 重新排版。
  `load_image` 已支持 data URI、本地文件和 `file://`；`Image::to_png_bytes` /
  `Image::save` 复用同一个 PNG 编码器；`load_image_async` 通过 `ImageFetcher`
  接 native async worker（`p5/http`，仅 `https:`），占位图在完成时原地填充。
  主画布 readback 由宿主 `CanvasRasterizer` 提供：macOS 用 `skia_raster`
  离屏重放命令，Web 用 `web_raster`（命令 JSON → 示例自带 JS 解释器 →
  离屏 2D canvas → `getImageData`），`save_canvas`、`load_pixels`、
  `set_pixel`、`update_pixels` 全部可用。
- 文本测量依赖当前 paint pass 的 `TextSystem`；`Recorder` 用
  `0.5 * size * length` 的确定性近似。

---

## 6. 构建、运行与验证

以下命令都在仓库根目录执行：

```sh
export PATH="$HOME/.moon/bin:$PATH"
```

### 6.1 核心测试（无窗口）

```sh
moon test examples/p5_sketch/p5 --target native
moon test examples/p5_sketch/p5/http --target native
moon test examples/p5_sketch/p5/moui --target native
moon test examples/p5_sketch/skia_raster --target native
moon test examples/p5_sketch/web_raster --target wasm-gc
```

预期：

```text
Total tests: 38, passed: 38, failed: 0.   # p5 core
Total tests: 2, passed: 2, failed: 0.       # native http loader
Total tests: 14, passed: 14, failed: 0.     # MoUI adapter
Total tests: 3, passed: 3, failed: 0.       # Skia canvas rasterizer
```

核心测试覆盖：

- p5.js 兼容的 LCG 随机序列（`randomSeed(99); random()` =
  `0.27443566313013434`）
- Perlin noise 的确定性与范围
- HSB/RGB 转换、hex/命名色解析
- 矩阵 compose/inverse、标量 helper
- 椭圆路径包围盒
- `setup` 只跑一次、`frame_count`/`delta_time`、`no_loop`/`redraw`
- 多 contour 的 `MoveTo`/`Close` 序列、spline_vertex 的 Catmull-Rom→Bézier 控制点、基础图形的稳定路径输出
- push/pop 与 transform 命令
- 文本测量与对齐
- 指针/键盘回调
- 多 pointer id 的 touches 更新/移除、压力 clamp、touch 回调与 Recorder 绘制
- IME composition 状态机、text_input/commit 与 adapter 事件映射
- image buffer 的 create/get/set/pixels、filter/tint、Recorder 绘制与 PNG data URI 编码
- graphics recording → replay 的 transform/path 断言
- PNG data URI / 本地文件 / `file://` → Image 像素解码、`try_load_image` 失败语义与 `load_image` 回调
- `Image::to_png_bytes` 编码 → 解码 round-trip、`Image::save` 写盘与失败返回
- `load_image_async` 的同步/延迟完成、占位图原地填充、失败保持占位与重复完成忽略
- native `p5/http` 的队列投递、字节回传与 cleartext `http` 拒绝
- `SketchView` 通过宿主 rasterizer 捕获命令流、主画布 load/set/update pixels 的 overlay 命令
- `skia_raster` 的 RGBA/半透明回读（含反预乘）与 `save_canvas` → PNG → `load_image` 闭环
- retained display list 的累积、opaque background reset 与 stateless 对照
- p5 Project/Bevel → `PathSpec` stroke cap/join 映射
- 文本描边：Recorder 记录 `stroke=... w=...`、`no_fill()` + `stroke()` 不再静默返回，adapter 断言 `TextRun` 携带描边字段
- Vector 运算

适配层测试覆盖：

- sketch 帧 → `FillRect` / `DrawPath` / `DrawText`
- `translate` → `PushTransform(tx, ty)`
- `clip_path_begin/end` → `PushPathClip` / `PopPathClip`（适配层断言路径 bounds，不再发矩形 clip）
- `SketchView::handle_input` 路由
- 暂停状态下输入仍触发一帧重绘

### 6.2 原生（macOS Skia）

```sh
moon build examples/p5_sketch/macos_skia --target native
moon run examples/p5_sketch/macos_skia --target native
```

窗口标题是 `MoUI p5 Sketch`。顶部三个 tab 切换 Shapes / Flow / Balls，
`Pause` / `Resume` 控制循环，`Reset` 重置当前 sketch。

### 6.3 无头截图（验证布局与绘制）

```sh
moon run moui_cli/cmd/moui -- screenshot examples/p5_sketch \
  --app app --out artifacts/p5-sketch.png \
  --width 1000 --height 720 --scale 2
```

该命令会：

1. 在 module 里生成临时 `moui_screenshot_tmp` 包；
2. 用 Skia 离屏 renderer 渲染 `app.program()` 的第一帧；
3. 写出 PNG（本仓库验证产物：`artifacts/p5-sketch.png`，2000×1440）。

四个示例（0/1/2/3，3 = **Intro** 介绍动画：20 秒自动循环，四幕——
渐变大字词标 + 光晕 + 强调线 → 三张特性卡片（AI-native / Pure TEA /
Renderer-neutral）→ 七个平台 pill chips → 真空心描边字标收尾）的截图可以分别把
`app.mbt` 的初始 `demo` 改成对应值后重新执行；

**离线视频管线**：`examples/p5_sketch/intro_frames`（native）用
`SketchView::render_commands(now)` 逐帧驱动 Intro 时间轴，先
`view.set_text_system(raster.text_system())` 绑定与光栅器一致的
`TextSystem`、再 `render_commands(0)` 预热时钟；`skia_raster` 复用
`SkiaCanvasRaster` 会话离屏回读，写成 600 张 2x PNG（1800×1080，
30fps × 20s；参数 `[out_dir] [scale] [from] [to]` 支持分块并行渲染，
4 进程约 7 分钟），ffmpeg 合成 `artifacts/moui-intro.mp4` / `.webm`；
**Web 端性能（2026-11-18 实测与修复）**：旧版 Intro 在 Web 上只有约 4fps
且时间轴约 0.5s 后停摆。根因与修复：

1. **动画路径击穿 mesh 缓存**：10 个光晕圆 + 32 个尘埃圆每帧几何/颜色都变，
   而 WebGPU 的 path-mesh 缓存按完整 `PathSpec`（含画笔）内容寻址 →
   每帧 42 次重新细分 + 逐字符 FFI 字符串上传 + GPU buffer 创建。
   - p5 形状层：`circle` 与四角半径一致的 `rect` 改走 MoUI 的
     `FillRoundedRect`/`StrokeRoundedRect`（Web 端是 SDF quad，Skia 是原生圆角
     矩形），不再生成贝塞尔路径；
   - 框架层：path-mesh 缓存改为**只按几何 verbs 寻址**，填充色/透明度动画
     不再让已上传的 mesh 失效。
2. **Web 端没有真实帧时钟**：`begin_redraw` 每次 +16ms 合成时钟，低帧率下
   动画变慢动作。`moui/backend/web` 现在注入 `frame_clock`（`performance.now`），
   动画按真实时间推进。
3. **大面积半透明 overdraw**：光晕从 10 层收到 4 层、尘埃 32→24，进一步降填充率。

修复后同一 8s 窗口：帧数 30（停摆）→ 240（≈30fps，光晕 4 层）、无光晕基线
≈45fps；时间轴按真实时间走完 20s 循环。Web 端仍受 SDF/fill-rate 限制，
不追求 60fps。

本目录的验证使用了：

- `artifacts/p5-sketch.png`（Shapes）
- `artifacts/p5-flow.png`（Flow）
- `artifacts/p5-balls.png`（Balls）

### 6.4 Web（wasm-gc）

```sh
moon build examples/p5_sketch/web_wasm --target wasm-gc
python3 -m http.server 8765
```

然后打开 <http://localhost:8765/examples/p5_sketch/web_wasm/>。页面通过
`moui_web_renderer/runtime.js` 的 `bootMouiWasmGcApp` 加载
`_build/wasm-gc/debug/build/examples/p5_sketch/web_wasm/web_wasm.wasm`。

### 6.5 一次性检查

```sh
moon check examples/p5_sketch/p5 --target native
moon check examples/p5_sketch/p5/http --target native
moon check examples/p5_sketch/p5/moui --target native
moon check examples/p5_sketch/skia_raster --target native
moon check examples/p5_sketch/app --target native
```

当前五个包都是 0 warning、0 error（测试二进制的 `input verification failed`
是链接器对预编译运行时对象的提示，不是包诊断）。

### 6.6 本次验证记录

| 验证 | 结果 |
|---|---|
| `moon test moui/core` | 205 passed, 0 failed（含 `RgbaImage`/`on_keyboard_input`/`PathSpec::shape_bounds`） |
| `moon test moui/runtime` | 250 passed, 0 failed（含 pointer→focus→key/text 路由） |
| `moon test moui/backend/common/input` | 35 passed, 0 failed（含 PhysicalKey→code 解码） |
| `moon test moui_skia_renderer` | 153 passed, 0 failed（含三角形路径裁剪、描边文字、Difference 合成像素断言） |
| `moon test moui_sun_renderer` | 113 passed, 0 failed（含高级 blend 映射） |
| `moon test examples/p5_sketch/p5` | 41 passed, 0 failed（含 stroke-only、RGB/HSB alpha 范围、圆角图元路由与 replay） |
| `moon test examples/p5_sketch/p5/http` | 2 passed, 0 failed |
| `moon test examples/p5_sketch/p5/moui` | 15 passed, 0 failed（含 Difference/Dodge → PushLayer 断言） |
| `moon test examples/p5_sketch/skia_raster` | 3 passed, 0 failed |
| `moon test examples/p5_sketch/web_raster` | 2 passed, 0 failed（JSON 序列化） |
| Web `?debug=1` 启动日志 | `p5 web readback self-test: left=(255,0,0) right=(0,255,0)`（JSON → 离屏 2D → getImageData → 像素回传闭环） |
| `moon test moui_sun_renderer` / `moui_tui_renderer` / `moui_web_renderer` / `moui_wgpu_renderer` / `moui_metal_renderer` | 112 / 43 / 33 / 61 / 91 passed，路径 clip fallback 通过 |
| `moon check`（p5 / p5/http / p5/moui / skia_raster / app） | 0 warning, 0 error |
| `moon build examples/p5_sketch/macos_skia --target native` | 成功，async entry + `RemoteImageLoader` 链接通过，产物 `_build/native/debug/build/examples/p5_sketch/macos_skia/macos_skia.exe` |
| `moon build examples/p5_sketch/web_wasm --target wasm-gc` | 成功，产物约 1.6 MB |
| Web 预览（启动本地 HTTP server，打开 `web_wasm/`） | 页面加载；DOM 无障碍树包含三个 tab 与 canvas；点击 `Flow` 后标题和 `● Flow` 选中态更新 |
| `moui screenshot` | 写出 `artifacts/p5-sketch.png`（2000×1440, skia）并人工检查 |

Web 预览的截图像素抓取在本次 IAB 后端超时；因此 Web 侧以 DOM 与交互验证为准，
视觉验收使用原生 Skia 的离屏截图。

---

## 7. 设计要点

### 7.1 Surface 契约

```moonbit
pub(open) trait Surface {
  fn set_transform(Self, Matrix) -> Unit
  fn save(Self) -> Unit
  fn restore(Self) -> Unit
  fn fill_path(Self, Path, Color) -> Unit
  fn stroke_path(Self, Path, Color, Double, StrokeCap, StrokeJoin) -> Unit
  fn fill_rect(Self, Double, Double, Double, Double, Color) -> Unit
  fn clear_rect(Self, Double, Double, Double, Double) -> Unit
  fn clip_path(Self, Path) -> Unit
  fn clip_end(Self) -> Unit
  fn fill_text(Self, String, Double, Double, Color, FontSpec, HAlign, VAlign) -> Unit
  fn measure_width(Self, String, FontSpec) -> Double
  fn text_metrics(Self, FontSpec) -> TextMetrics
  fn set_blend_mode(Self, BlendMode) -> Unit
  fn set_smoothing(Self, Bool) -> Unit
}
```

`Sketch` 自己做矩阵、颜色模式、push/pop、路径构建；后端只负责把局部坐标
的 path/text 画出来。这和 p5.mbt 的 `Surface` 契约一致，也是 `Recorder`
能逐行断言绘制行为的原因。

### 7.2 矩阵与变换栈

`Matrix` 使用 MoUI 的 2D affine 布局：

```text
x' = a*x + c*y + tx
y' = b*x + d*y + ty
```

`translate`/`rotate`/`scale` 都是右乘（先应用新变换，再应用旧 CTM），
与 canvas 的 `translate` / `rotate` 语义一致。

`MoUISurface::set_transform` 不直接输出绝对矩阵，而是算出相对当前 CTM
的 delta：

```text
delta = inverse(current) * target
```

然后输出 `PushTransform(delta)`。`save`/`restore` 记录 push 深度，`restore`
会连续 `PopTransform` 到保存点，保证 `push`/`pop` 内的多次变换都能恢复。

### 7.3 路径

`Path` 是 `Array[PathCmd]` 的封装，命令只有
`MoveTo/LineTo/QuadTo/CubicTo/Close`。椭圆、圆弧、圆角矩形都在核心层转成
三次 Bézier，所以所有后端只需要支持这 5 个 verb。

### 7.4 随机与噪声

- `Random` 用 p5.js 的 Numerical Recipes LCG
  （`state = 1664525*state + 1013904223 mod 2^32`），所以
  `random_seed(99)` 后的序列与 p5.js 一致。
- `Noise` 是 p5.js `src/math/noise.js` 的经典 Perlin lattice 端口：
  `PERLIN_SIZE = 4095`、`YWRAP=16`、`ZWRAP=256`、4 octaves、0.5 falloff。
- 测试里对随机序列和噪声确定性做了断言。

### 7.5 文本

绘制时使用当前 `ViewPaintContext.text_system` 测量：

1. 按 `\n` 拆行；
2. 如果给了 `max_width`，按词或字符换行；
3. 用 `text_leading` 计算行高；
4. 按 `text_align` 的垂直模式算出块顶部；
5. 每行以 `Baseline` 模式交给 `Surface::fill_text`，由适配层把 baseline
   换算成 `TextRun.frame`。

---

## 8. 参考与许可

- 参考项目：[`bobzhang/p5.mbt`](https://github.com/bobzhang/p5.mbt)
  （LGPL-2.1；p5.js 也是 LGPL-2.1）。
- 本目录是 MoUI 仓库内的示例/实现，遵循 MoUI 仓库的 Apache-2.0 许可。
- 随机数、Perlin noise 和若干数学 helper 的算法来自 p5.js / p5.mbt 的公开
  实现；如果要把本实现作为独立库发布，请按 LGPL-2.1 的衍生作品要求重新
  评估许可与署名。
