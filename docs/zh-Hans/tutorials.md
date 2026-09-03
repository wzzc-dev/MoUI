# MoUI 教程骨架

这些骨架让新示例与当前包边界保持一致。它们刻意保持简短：复制这个形态，然后先补齐包内测试，再扩展行为。

## 创建 View

1. 在 `views/` 下添加公开 constructor，并返回 `@moui.View[Msg]`。
2. 将具体可复用 custom view 行为放在 `moui/views`，然后由 `views/` 暴露面向 app 的 constructor。复用现有 state、style、binding、semantics 和 layout 类型。
3. 在 `moui/views` 的 `tests/smoke` 包或聚焦 `*_test.mbt` 中添加测试。
4. 当 view 面向用户时，添加 Showcase 入口。
5. 运行 `moon test moui/views --target native` 和 `moon info`。

将可复用内置行为实现为 concrete `@core.ViewNode`，并用 `@core.View::from_node` 包装。不要从 app-facing facade 重导出 `ViewNode`，也不要为新控件添加 `@core.View::primitive_*_view` constructor、`ViewLoweringSink` 或 runtime lowering arm。

## 创建 Custom Layout

1. 第一版使用 `@views.custom_children_layout`。
2. 阅读 `CustomLayoutContext.child_sizes`、`child_baselines`、`child_alignment_guides`、`child_priorities`、`safe_area`、`viewport` 和 `layout_direction`。
3. 在 `CustomLayoutContext.cache` 中存储可复用 measurement。
4. 使用 `CustomPlacementContext::mirror_x` 进行 RTL-aware x 放置。
5. 在 `moui/views`（`tests/smoke` 或聚焦 `*_test.mbt`）中添加测试；如果 runtime contract 变化，则添加 core white-box 测试。

## 创建平台服务

1. 先把类型化 request/response 添加到 `backend`。
2. 通过 `HostServiceCapabilities` 对 dispatch 进行 gate。
3. 在相关 backend package 中添加 platform-local bridge constructor。
4. 用 `HostServiceBridge::unavailable` 显式表示不可用平台。
5. 添加 host 测试以及至少一个 backend scaffold 测试。

## 修改文本行为

1. 在修改 measurement、shaping、glyph rasterization、embedded font registration 或 startup text-engine 选项前，先阅读 `docs/text-system.md`。
2. 保持 `core` 仅限于中立的 `TextSystem` contract 和确定性 fallback。
3. 将原生 provider 工作放在相关 `moui_wgpu_renderer/*` 包下，并让 Web 文本修改与 `backend/web` 对齐。
4. 为被修改的边界添加聚焦 core、renderer、backend 或 provider 测试。
5. 当行为或维护规则变化时，更新 `docs/text-system.md`、`docs/renderer-capability-report.md` 和 guidance 文件。

## 更新 Renderer 能力

1. 添加或更新 `@core.DrawCommand` intent。
2. 更新 `render/capabilities.mbt` 中的 renderer fallback planning。
3. 更新 native/Web renderer 行为，或报告计划中的 fallback。
4. 更新 `docs/renderer-capability-report.md`。
5. 运行 `moon test moui/render --target native`、`moon test moui_wgpu_renderer --target native` 和 `moon test moui_web_renderer --target wasm-gc`。

## 添加 Showcase 入口

1. 将共享行为放在 `examples/showcase/app`。
2. 添加 category metadata、preview、API notes、semantics notes、test coverage 和 renderer notes。
3. 优先使用能展示真实控件的 list-detail entry，而不是静态文案。
4. 运行 `moon test examples/showcase/app --target native`。

## 更新 Guidance

1. 当 docs placement、validation command、package layout、example structure、renderer status、platform behavior 或 text architecture 变化时，检查 `AGENTS.md` 和 `skills/`。
2. 保持 skill instruction 简短且可操作。
3. 如果 guidance 文件不需要编辑，请在 handoff 中说明已经检查过。
