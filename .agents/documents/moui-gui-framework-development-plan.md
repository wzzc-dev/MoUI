# MoUI — MoonBit GUI 框架开发计划

## Summary

基于 `/Users/zc/Downloads/plans` 中三份未完成计划，统一制定一份可直接执行的 MoUI 首版开发计划。目标是在 `/Volumes/Data/Code/moui` 空壳工作区内创建一个 macOS native 优先的 MoonBit GUI 框架，复用本地已缓存的 `Milky2018/window` 与 `Milky2018/wgpu_mbt`，实现窗口生命周期、事件分发、声明式 View 树、布局、绘制命令、wgpu/Metal 渲染和 Counter 示例闭环。

首版成功标准：`moon check`、定向 `moon test`、`moon fmt`、`moon info` 通过；`moon run examples/counter --target native` 能显示原生窗口，响应 resize、hover、press/click，并触发重绘展示 counter 或等价交互状态变化。

**Before starting implementation:** Use the Skill tool to load the moonbit-c-binding skill, which provides comprehensive guidance on FFI declarations, ownership annotations, C stubs, and AddressSanitizer validation.

## Current State Analysis

* 工作区根目录是 `/Volumes/Data/Code/moui`，当前没有根级 `moon.mod.json`、业务包或 README，仅有 `.mooncakes` 依赖缓存与 `.trae` 工具目录。

* 本地计划来源包括 `/Users/zc/Downloads/plans/plan.md`、`/Users/zc/Downloads/plans/plan_old.md`、`/Users/zc/Downloads/plans/moonbit-gui-framework_90b17a8e(未完成).md`，三者在目标、分层、首版范围上基本一致。

* `Milky2018/window` 位于 `/Volumes/Data/Code/moui/.mooncakes/Milky2018/window`，版本为 `0.1.1`，模块配置为 `preferred-target: native`，提供 macOS AppKit 风格事件循环、窗口、输入、IME 与 raw handle 能力。

* `Milky2018/wgpu_mbt` 位于 `/Volumes/Data/Code/moui/.mooncakes/Milky2018/wgpu_mbt`，版本为 `0.1.0`，模块 source 为 `src`，配置为 `preferred-target: native`，封装 wgpu-native C API 与 Metal surface helper。

* `window` 关键 API 已确认：`EventLoop::run_app`、`try_run_app`、`ApplicationHandler`、`ActiveEventLoop::create_window`、`Window::request_redraw`、`Window::pre_present_notify`、`Window::surface_size/inner_size`、`WindowEvent::SurfaceResized`、`WindowEvent::RedrawRequested`、`WindowEvent::Pointer`、`WindowEvent::KeyboardInput`、`WindowEvent::CloseRequested`。

* `wgpu_mbt` 关键 API 已确认：`Instance::create`、`Instance::create_surface_metal_layer`、`Surface::configure_default`、`Surface::get_current_texture`、`SurfaceTexture::take_texture/status`、`Texture::create_view`、`Device::create_shader_module_wgsl`、`Device::create_render_pipeline_rgba8/color_format`、`Surface::present`。

* 重要缺口：`wgpu_mbt` 当前可创建自有 `CAMetalLayer` surface，但没有直接接收 `window.Window`、NSView、CAMetalLayer 或 raw-window-handle 的公开 surface 创建 API；需要在后端/FFI 层封装“窗口 view/layer 与 wgpu surface”桥接，不把该差异泄漏到 core API。

* 现有依赖示例可复用：`window/examples/window/main.mbt` 展示 resize/redraw/pre\_present\_notify；`window/examples/application/main.mbt` 展示 `ApplicationHandler` 用法；`wgpu_mbt/src/tests/wgpu_surface_present_test.mbt` 展示 surface configure/acquire/render/present；`wgpu_mbt/src/tests/wgpu_render_offscreen_test.mbt` 展示离屏 render target 测试。

## Proposed Changes

### 1. 根模块与文档

* `moon.mod.json`：新增模块配置，模块名使用 wzzc-dev`moui`，声明 `preferred-target: native`，依赖 `Milky2018/window` 与 `Milky2018/wgpu_mbt`。

* `README.md`：新增项目说明，覆盖首版平台范围、分层架构、包结构、验证命令、示例运行命令、已知限制与后续路线。

* `.gitignore`：如缺失则新增，忽略 MoonBit 构建产物、临时日志、ASan 输出与本地实验文件；不忽略 `pkg.generated.mbti`，最终通过 `moon info` 生成并纳入接口审查。

### 2. `core/` 核心包

* `core/moon.pkg`：新增核心包配置，首版不依赖平台包，保持可纯逻辑测试。

* `core/spec.mbt`：新增公共契约草案，使用 `declare` 固定核心抽象的最小公共 API，包括 `App`、`View`、`ViewNode`、`LayoutResult`、`DrawCommand`、`RendererBridge`、`Runtime`。

* `core/geometry.mbt`：新增 `Point`、`Size`、`Rect`、`Insets`、`Constraints`、`Axis`，实现约束 clamp、rect contains、offset/inset 等基础方法，并为测试友好派生 `Show`、`Debug`、`Eq`、`ToJson` 中可用集合。

* `core/event.mbt`：新增框架事件模型，定义 `AppEvent`、`WindowEvent`、`PointerEvent`、`PointerPhase`、`KeyboardEvent`、`RedrawReason`，统一坐标、尺寸与 modifiers 表达。

* `core/paint.mbt`：新增 `Color`、`Clip`、`DrawCommand`，首版支持 `Clear(Color)`、`FillRect(Rect, Color)`、`PushClip(Rect)`、`PopClip`，文本仅保留占位命令或延后实现。

* `core/view.mbt`：新增声明式 `View`/`ViewNode` 抽象。首版采用可执行且 MoonBit 友好的枚举/闭包组合模型，避免过早复杂泛型；用户视图通过构造 `ViewNode` 表达树，框架负责布局、事件和绘制调度。

* `core/layout.mbt`：新增 O(n) 布局与命中测试基础，提供 `measure_node`、`layout_node`、`hit_test`，处理 constraints、padding、row/column 主轴分配、叶子节点固定/最小尺寸。

* `core/app.mbt`：新增运行时状态与调度接口，定义 `AppModel`、`RuntimeState`、`needs_redraw`、`dispatch_event`、`build_draw_commands`，由后端在 `RedrawRequested` 时调用。

* `core/core_easy_test.mbt`：新增几何、约束 clamp、rect contains、绘制命令序列测试。

* `core/core_difficult_test.mbt`：新增嵌套布局、命中测试、事件传播顺序、按钮状态变化驱动 redraw 的测试。

### 3. `backend/` macOS 后端包

* `backend/moon.pkg`：新增包配置，导入根模块 `core`、`Milky2018/window`、`Milky2018/window/core`、`Milky2018/window/macos`、`Milky2018/window/dpi` 中实际需要的包，并将 native-only FFI 文件限定到 native target。

* `backend/platform.mbt`：新增平台抽象，提供 `run_app(config, app_factory)`、`WindowConfig`、`BackendError`、`SurfaceBridgeInfo`，对 core/render 隐藏 `window` 具体类型。

* `backend/macos_app.mbt`：新增 `ApplicationHandler` 实现，创建窗口，处理 `can_create_surfaces`、`window_event`、`about_to_wait`、`destroy_surfaces`，将 `WindowEvent` 转换为 core 事件；`SurfaceResized` 更新 runtime 尺寸并通知 renderer resize；`RedrawRequested` 调用 `pre_present_notify` 后执行布局、绘制、present。

* `backend/native_surface.mbt`：新增 surface 桥接安全包装。优先路径是复用 `window.Window` 的 native/raw handle 获取 NSView/CAMetalLayer 并创建 wgpu surface；如果依赖 API 不能直接暴露所需 layer，则实现最小 C bridge 将 `CAMetalLayer` 安装到窗口 content view，并返回可传给 `wgpu_mbt` 的 handle。

* `backend/native_surface_stub.c`：仅在需要桥接 `window` 与 `wgpu_mbt` surface 时新增。所有非 primitive 参数必须明确 `#borrow` 或 `#owned`；外部对象使用 finalizer；不得把 C 保存的 MoonBit 对象错误标为 borrow。

* `backend/backend_test.mbt`：新增纯转换测试，覆盖 resize、redraw、close、pointer move/down/up、keyboard input 到 core 事件的映射；不依赖真实窗口的逻辑放在可测函数中。

### 4. `render/` wgpu 渲染包

* `render/moon.pkg`：新增包配置，依赖 `core` 与 `Milky2018/wgpu_mbt/src` 对应包路径；如实际 import 名与 source 结构不同，以 `moon ide doc` 与现有 `wgpu_mbt/src/tests/moon.pkg.json` 为准。

* `render/renderer_spec.mbt`：新增渲染契约声明，固定 `Renderer` 生命周期：`create`、`resize`、`render(commands)`、`dispose` 或等价安全接口。

* `render/renderer.mbt`：新增 renderer facade 与错误类型，向 backend 暴露 `RendererHandle`，向 core 仅暴露绘制命令输入。

* `render/shaders.mbt`：新增 WGSL shader 字符串，首版实现矩形填充。为降低首版复杂度，可先把 `FillRect` 展开为 CPU 侧顶点数据或简单 instance buffer；文本渲染不进入首版。

* `render/wgpu_renderer.mbt`：新增 wgpu 实现，流程参考 `wgpu_surface_present_test.mbt`：创建 instance/adapter/device/queue，配置 surface，acquire current texture，创建 view，编码 render pass，提交 queue，present；resize 时重新 configure surface；surface lost/outdated 时返回可恢复错误并请求重配。

* `render/render_test.mbt`：新增不依赖真实窗口 surface 的测试，覆盖 `DrawCommand` 到矩形批次转换、clip stack 合法性、resize 状态更新。可复用 offscreen texture 做最小渲染 smoke，但 onscreen present 留给示例验证。

### 5. `views/` 基础视图包

* `views/moon.pkg`：新增包配置，仅依赖 `core`。

* `views/label.mbt`：新增 `label(text, ...)` 视图。首版以矩形占位或固定 size 表达文本区域，保留后续文本渲染扩展点。

* `views/button.mbt`：新增 `button(label, on_click, ...)` 视图，支持 normal/hover/pressed 状态、pointer enter/move/down/up/cancel 处理、click 回调与 redraw 标记。

* `views/flex.mbt`：新增 `row(children, spacing?, align?)` 与 `column(children, spacing?, align?)`，实现主轴排列、间距、交叉轴尺寸计算。

* `views/padding.mbt`：新增 `padding(child, insets)`，实现 constraints 收缩、child layout 偏移、hit-test 坐标转换。

* `views/views_test.mbt`：新增基础视图测试，覆盖 button 状态机、click 只在 press 后 release 命中时触发、row/column/padding 布局结果。

### 6. `examples/counter/` 示例

* `examples/counter/moon.pkg`：新增可执行包配置，`options("is-main": true)`，依赖 `core`、`views`、`backend`、`render`，限定 native 运行。

* `examples/counter/main.mbt`：新增 Counter demo。窗口标题为 `MoUI Counter`，初始大小 800x600；视图树包含标题/计数展示/按钮；按钮 hover/press 改变填充色，click 增加计数并请求 redraw。

## Assumptions & Decisions

* 首版只支持 macOS native，不实现 Linux、Windows、Web 后端；跨平台仅通过 `PlatformBackend`/`Renderer` 抽象预留接口。

* 目录采用顶层包结构：`core`、`backend`、`render`、`views`、`examples/counter`，不采用旧计划中的 `src/` 与 `widgets` 命名。

* 公共命名统一使用 `views` 与 `View`，不混用 `Widget` 作为对外概念；如内部需要兼容旧名，可在后续版本再用 alias。

* core 包必须保持平台无关，便于 `moon test core` 在不创建窗口的情况下验证布局、事件和绘制命令。

* 文本渲染、主题系统、富文本、无障碍树、复杂动画、增量 diff/reconcile、跨平台 backend 均不进入首版范围。

* 布局、命中测试、事件分发、绘制命令生成以单次树遍历为目标，复杂度目标 O(n)；首版不实现 retained cache，只保留 `needs_layout`/`needs_redraw` 扩展点。

* surface 桥接是最高风险点：如果不能把 `window` 的实际 NSView/CAMetalLayer 与 `wgpu_mbt` surface 直接连通，先完成 offscreen render + window event demo，并将 onscreen surface bridge 作为 backend/native\_surface 的集中修复点，不改变 core/views API。

* 所有 C/FFI 相关实现必须加载并遵守 `moonbit-c-binding` 指南，明确 ownership、finalizer、native-stub 配置和 ASan 验证策略。

* `pkg.generated.mbti` 应在最终 `moon info` 后生成并审查，作为公共 API 是否符合预期的交付物。

## Implementation Steps

### Phase 1: 依赖 API 再核验与项目骨架

1. 使用 `moon ide doc`、`moon ide outline` 或读取依赖示例，确认 `Milky2018/window` 与 `Milky2018/wgpu_mbt` 的实际 import 路径和当前 MoonBit 语法。
2. 新增根 `moon.mod.json`、`README.md`、必要 `.gitignore`。
3. 新增 `core`、`backend`、`render`、`views`、`examples/counter` 目录与 `moon.pkg`。
4. 运行 `moon check`，只验证空骨架与包依赖可解析。

### Phase 2: core 契约、类型与测试

1. 实现 `core/spec.mbt` 的最小契约，避免一次性暴露过多 API。
2. 实现 `geometry.mbt`、`event.mbt`、`paint.mbt`。
3. 实现 `view.mbt`、`layout.mbt`、`app.mbt` 的最小可运行模型。
4. 添加 `core_easy_test.mbt` 与 `core_difficult_test.mbt`。
5. 运行 `moon check` 与 `moon test core`，必要时用 `moon test --update` 更新 snapshot。

### Phase 3: views 组件与纯逻辑验证

1. 实现 `label.mbt`、`padding.mbt`、`flex.mbt`。
2. 实现 `button.mbt` 状态机，确保事件命中、press/release/cancel 行为可测。
3. 添加 `views_test.mbt`，验证组合布局和交互状态。
4. 运行 `moon check`、`moon test core`、`moon test views`。

### Phase 4: render 渲染器

1. 实现 `renderer_spec.mbt` 与 `renderer.mbt`，冻结 backend 调用 renderer 的接口。
2. 实现 `shaders.mbt` 与 draw command batching/validation。
3. 实现 `wgpu_renderer.mbt` 的 instance/device/queue/surface 生命周期与 resize/render/present。
4. 添加 `render_test.mbt`，优先测试命令转换和 offscreen smoke；onscreen present 在 counter 示例验证。
5. 运行 `moon check`、`moon test render --target native`。

### Phase 5: backend 后端与 surface 桥接

1. 实现 `platform.mbt` 的 public facade。
2. 实现 `macos_app.mbt` 的 `ApplicationHandler`，连接窗口事件、runtime、renderer。
3. 实现 `native_surface.mbt`，必要时新增 `native_surface_stub.c` 与 `moon.pkg` 的 native-stub/link 配置。
4. 添加 `backend_test.mbt`，把事件转换逻辑拆成纯函数进行测试。
5. 运行 `moon check`、`moon test backend --target native`；若新增 C bridge，额外执行 ASan 验证脚本或等价 native memory smoke。

### Phase 6: Counter 示例与最终交付

1. 实现 `examples/counter/main.mbt`，组合 backend、render、views。
2. 运行 `moon run examples/counter --target native`，验证窗口出现、resize 不崩溃、hover/press/click 触发重绘。
3. 补齐 `README.md` 的运行方式、架构说明、已知限制与下一步计划。
4. 运行最终质量门：`moon check`、`moon test --target native`、`moon fmt`、`moon info`。
5. 审查 `pkg.generated.mbti` 与 README，确认公共 API 与首版范围一致。

## Verification Steps

* 骨架验证：`moon check` 在新增根模块与包配置后通过。

* 核心验证：`moon test core --target native` 覆盖 geometry、constraints、layout、hit-test、event dispatch、draw command。

* 视图验证：`moon test views --target native` 覆盖 Label/Padding/Row/Column/Button 的布局与状态机。

* 渲染验证：`moon test render --target native` 覆盖 command batching、clip stack、resize 状态与 offscreen smoke。

* 后端验证：`moon test backend --target native` 覆盖 window event 到 core event 的转换和 runtime 状态变化。

* 示例验证：`moon run examples/counter --target native` 手动 smoke，确认窗口、resize、redraw、hover、press/click 与 present 流程。

* 最终验证：`moon check --target native`、`moon test --target native`、`moon fmt`、`moon info` 全部完成，并检查生成的 `pkg.generated.mbti` 是否符合计划中的公共 API。

## Risks & Mitigations

* Surface 集成风险：`wgpu_mbt` 自建 `CAMetalLayer` 与 `window` 的 NSView 可能无法直接关联；缓解方式是在 `backend/native_surface.*` 集中封装 FFI，不让 core/views/render facade 依赖具体 handle。

* MoonBit 语法/API 漂移风险：实现前对依赖包运行 `moon ide doc`/读取 `pkg.generated.mbti`，不要按记忆写 import 或签名。

* FFI 生命周期风险：所有 native bridge 均遵守 `moonbit-c-binding`，并在最终阶段执行 ASan 或最小重复创建/销毁 smoke。

* 过度设计风险：首版只实现矩形、颜色、布局和按钮状态，不引入主题、文本栅格化、动画、虚拟 DOM diff。

* 测试窗口依赖风险：可纯测试的逻辑必须拆到 core/views/backend 转换函数，真实窗口仅用于示例 smoke。

