# 功能证明矩阵

本页将每个 MoUI 功能映射到证明它的 CI workflow 和 job。“已证明”表示对应 CI job 在匹配主机上通过。功能状态声明位于 `render/capabilities.mbt` 和 `docs/renderer-capability-report.md`；本页跟踪的是**证明覆盖**，不是实现状态。

## 证明级别

| 级别 | 定义 | CI 触发 | 主机要求 |
|-------|-----------|------------|-----------------|
| **L1** | API 正确性、算法正确性、协议正确性 | 每个 PR (`ci.yml`) | 无（fallback-safe build） |
| **L2** | 真实渲染器/平台上的 runtime 行为 | 每个 PR 和 push-to-main (`moui-renderer-real-skia-ci.yml`) | 匹配主机真实 Skia |
| **L3** | 跨平台一致性 | `feature-proof-summary.yml` 在 `ci.yml` 完成后 | 所有 L2 平台通过 |

框架渲染代码（`moui/render/skia/`、`moui/views/`）依赖 `moui_skia` 提供的真实 Skia 链接。任何框架变更都可能影响真实渲染行为，因此每个 PR 都会在 L2 运行真实 Skia smoke。

## L1 功能（ci.yml，每个 PR）

| 功能 | 证明 job | 平台 | 通过后证明什么 |
|---------|-----------|----------|-------------------|
| Core API (View/Element/Layout/Animation) | `pr-profile` | macOS-14 | check.sh --profile pr：core 包测试通过 |
| Runtime lifecycle | `pr-profile` | macOS-14 | check.sh --profile pr：runtime effect/subscription/diagnostics |
| Views controls (Text/Button/TextField/Container/Row/Column/Flex/Stack/Scroll/List/Grid/Navigation) | `pr-profile` | macOS-14 | check.sh --profile pr：views 包测试通过 |
| Host services protocol (clipboard/menus/dialogs URL) | `pr-profile` | macOS-14 | check.sh --profile pr：backend/host 包测试通过 |
| Web wasm-gc build | `pr-profile` | macOS-14 | check.sh --profile pr：Web wasm-gc 构建成功 |
| Renderer capability report consistency | `pr-profile` | macOS-14 | check.sh --profile pr：capabilities_test.mbt 通过 |
| Text conformance (grapheme/cluster/caret) | `pr-profile` | macOS-14 | `sh scripts/check.sh --profile full` 包含文本 diagnostics |
| API surface stability | `api-surface` | macOS-14 | moon info drift check 通过 |
| Linux backend contracts | `linux-platform` | ubuntu-24.04 | `sh scripts/check.sh --profile platform` 通过 |
| Windows backend contracts | `windows-native` | windows-2022 | Windows backend MSVC 测试通过 |
| macOS packaging | `macos-packaging` | macOS-14 | Showcase app bundle 成功打包 |
| Benchmark scaffold | `benchmark-scaffold` | macOS-14 | Benchmark target 构建成功 |

## L2 功能（moui-renderer-real-skia-ci.yml，每个 PR 和 push-to-main）

所有 L2 功能都使用 release-provider 真实 Skia 并采用静态链接。每个平台 job 都运行 `verify-native-smoke-log` 和 `verify-acceptance-log` 来断言像素标记和 acceptance 标记。

| 功能 | macOS job | Linux job | Windows job | 通过后证明什么 |
|---------|-----------|-----------|-------------|-------------------|
| Rect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 Skia rect 填充/描边像素 |
| RoundedRect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 Skia rounded rect 像素 |
| Gradient | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 Skia linear/radial gradient 像素 |
| Shadow | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 Skia shadow blur 像素 |
| Text | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 FontMgr fallback 和 glyph-run 渲染 |
| Image | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 PNG/JPEG 解码和绘制 |
| Clip | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 rect/rounded/path clip 像素 |
| Transform | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 affine transform 像素 |
| Opacity | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 save-layer opacity 像素 |
| LayerCompositing | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 layer/mask composition 像素 |
| BlendMode | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 blend mode 像素 |
| FilterEffect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 blur/saturation/color-matrix 像素 |
| PathVector | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 path fill/stroke 像素 |
| ShaderEffect | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 procedural shader 像素 |
| TextShaping | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 SkShaper/SkParagraph shaping，bidi Arabic/mixed-direction visual-order |
| EmojiText | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 emoji cluster 渲染，keycap/regional-indicator/skin-tone-modifier fallback，通过 `Typeface::has_color_glyphs` 做确定性的 color glyph format 检测（font table tag query：COLR/sbix/CBDT/SVG），diagnostic 中的已解析字体名（`resolved_font_name` 字段） |
| AsyncImage | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | 真实 completion 后 second-frame repaint，通过 HostNativeAsyncImageSource 的 deferred-completion，off-main-thread local-file I/O 以及平台 native worker（GCD/pthread/CreateThread）上的 Skia decode，provider 测试中验证带 `background_io` 和 `background_decode` 的 decoded RGBA completion payload |

## L3 跨平台一致性

Mobile host-channel、IME replacement/selection、semantics action validation、renderer selection 和 mailbox behavior 具有 L1 package-test 证明。Mobile L3 是独立的，并且在每个平台的 window-hosted verification 于匹配设备或模拟器上通过之前保持 pending。它要求 presentation、actual detach、IME、text/image clipboard、accessibility tree/focus/action 和 async image observations。

已注册 suite 覆盖 Android 和 iOS Counter/Showcase，以及 HarmonyOS Demo/Showcase。GPU promotion 不属于当前 L1/L2 渲染器证明；它需要 `../window-hosted-moui.md` 中的逐平台性能和恢复 evidence。

## L2 GPU Direct Presentation 第 1 阶段能力

GPU readback elimination plan 的第 1 阶段已落地 window-surface GPU source 路径（见 ADR 0006 和 `.trae/documents/gpu-readback-elimination-plan.md`）。产品策略现在让所有 native Skia 平台上的 `auto` 默认使用 GPU（`gpu_promoted=true`）；匹配设备 seven-gate manifest（`readbackEliminated`、`rendererThread`、`mailboxOk`、`performance`、`memory`、`contextLoss`、`rasterFallback`）仍然是质量证据门槛，而不是 product-default gate。

| 平台 | 后端 | Surface route | 第 1 阶段 source | 第 2 阶段 promotion |
| --- | --- | --- | --- | --- |
| iOS | Metal | `MetalGpuSurfaceRoute` | worker-owned source；simulator GPU build/first frame | pending physical-device manifest |
| macOS | Metal | `MetalGpuSurfaceRoute` | worker-owned context/picture replay/present；local first-frame smoke | matching-host claim recorded 2026-07-14 |
| Android | Vulkan / GLES | `VulkanGpuSurfaceRoute` / `EglGpuSurfaceRoute` | worker-owned source；minSdk 23 GPU APK build | pending Vulkan and GLES device manifests |
| HarmonyOS | EGL/GLES | `EglGpuSurfaceRoute` | worker-owned source；native/HAP build | pending signed-device manifest |
| Windows | Direct3D 12 | `Direct3DGpuSurfaceRoute` | worker-owned source；MSVC validation pending | pending matching-device manifest |
| Linux | Vulkan (Wayland) | `VulkanGpuSurfaceRoute` | worker-owned source；Wayland build/validation pending | pending matching-device manifest |
| Web | WebGPU | browser canvas | device-loss/fallback source path | pending Chrome WebGPU manifest |

第 2 阶段 promotion gate 脚手架具有 L1 package-test 证明：

| Gate | Source | L1 证明 |
| --- | --- | --- |
| Renderer mailbox control queue | `moui/render/render_frame_mailbox.mbt` | `moui/render` whitebox tests（capacity-two latest-wins；control messages never dropped） |
| Native Picture handoff | `moui_skia/native/skia_stub_gpu_worker.cpp` | 聚焦 native worker tests（`SkPicture` retain、independent thread、detach acknowledgement、zero readback counter）、macOS worker-owned Metal first-frame smoke、Android NDK GPU build、HarmonyOS native/HAP build 和 iOS simulator GPU build |
| Context-loss recovery state machine | `moui/runtime/renderer_recovery.mbt` | `moui/runtime` whitebox tests（Idle → Lost → Recovering → Recovered → Idle；terminal `FallbackToRaster`） |
| GPU promotion evidence | `docs/gpu-promotion-runbook.md` | promotion claim 前仍需要 matching-device evidence |

只有在 worker-owned presentation 和匹配硬件 manifest 通过 `--require-passed` 后，第 2 阶段逐平台 promotion 才可以翻转该平台的 `gpu_promoted` 值。

`feature-proof-summary.yml` 在 `ci.yml` 或 `moui-renderer-real-skia-ci.yml` 完成后运行（通过 `workflow_run`）。它收集 `ci.yml` 和 `moui-renderer-real-skia-ci.yml` 的所有 job 状态，生成 proof report，并验证覆盖：

- L1 job 必须通过（ci.yml）。
- L2 job 必须在三个平台全部通过（moui-renderer-real-skia-ci.yml）。

## Artifact 路径

| CI job | Artifact 名称 | 内容 |
|--------|--------------|---------|
| `macos-real-skia` | `macos-renderer-real-skia-ci` | `moui_skia/logs/macos-*.log`（native/renderer/text-emoji/acceptance） |
| `linux-real-skia` | `linux-renderer-real-skia-ci` | `moui_skia/logs/linux-*.log`（native/renderer/text-emoji/acceptance） |
| `windows-real-skia` | `windows-renderer-real-skia-ci` | `moui_skia/logs/windows-*.log`（native/renderer/text-emoji/acceptance） |
| `summarize` | `feature-proof-summary` | `artifacts/feature-proof/proof-report.json` + `.md` |

## 为新功能添加 CI 证明

1. 如果功能是 L1（不需要真实渲染器）：在合适的 `moui/` 包下添加 package test。`ci.yml` 中的 `pr-profile` job 会通过 `check.sh --profile daily` 拾取它。
2. 如果功能是 L2（需要真实 Skia）：向 `moui_skia/scripts/native_smoke/` 添加 smoke 断言，并在需要时更新 `moui_skia/native/capabilities.json`。`moui-renderer-real-skia-ci.yml` job 会自动拾取它。
3. 将该功能添加到上面的表格。
4. 如果引入了新的 L2 feature job 名称，更新 `scripts/generate-feature-proof-report.mjs` 的功能列表。

## 触发参考

| Workflow | 触发条件 | Paths filter |
|----------|------------------|-------------|
| `ci.yml` | push/PR to main | none (always) |
| `moui-skia-provider-fallback-ci.yml` | push/PR to main | `moui_skia/**` (moui_skia package self-test) |
| `moui-renderer-real-skia-ci.yml` | push/PR to main | none (validates framework rendering on push and every PR) |
| `moui-runtime-gates.yml` | schedule nightly + manual | none |
| `moui-macos-app-real-skia-manual.yml` | manual | none (MoUI macOS app/runtime validation) |
| `moui-skia-provider-macos-real-skia-manual.yml` | manual | none |
| `moui-skia-provider-linux-real-skia-nightly.yml` | weekly + manual | none |
| `moui-skia-provider-windows-real-skia-manual.yml` | manual | none |
| `moui-skia-provider-real-skia-acceptance.yml` | push-to-main + weekly + manual | `moui_skia/**` on push; none on schedule/manual |
| `feature-proof-summary.yml` | `workflow_run` on `ci.yml` or `moui-renderer-real-skia-ci.yml` completed | none |
