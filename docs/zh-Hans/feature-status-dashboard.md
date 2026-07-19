# 功能状态看板

本页跟踪 MoUI 功能证明覆盖。实现状态（supported/partial/gap）请见 [renderer-capability-report.md](../renderer-capability-report.md)。功能到 CI job 的映射请见 [功能证明矩阵](feature-proof-matrix.md)。

`feature-proof-summary.yml` CI workflow 会在每次 `ci.yml` 运行后生成 proof report。最新报告可在最近一次 `MoUI Feature Proof Summary` workflow run 的 `feature-proof-summary` artifact 中获取。

## 证明级别

| 级别 | CI workflow | 触发 | 证明内容 |
|-------|------------|---------|---------------|
| L1 | `ci.yml` | 每个 PR | API/algorithm/protocol 正确性（无真实渲染器） |
| L2 | `moui-renderer-real-skia-ci.yml` | 每个 PR 和 push-to-main | 匹配主机上的真实 Skia runtime 行为 |
| L3 | `feature-proof-summary.yml` | `ci.yml` 完成后 | 所有必需 L1 和 L2 通过 |

## 渲染器功能证明状态

来自 `RendererFeature` enum 的全部 17 个渲染器功能共享同一套 CI job 映射。L1 证明始终由 `pr-profile`（package tests）提供。L2 证明由每个 PR 上的三个平台 job 提供。

| 功能 | L1 (ci.yml) | L2 macOS | L2 Linux | L2 Windows | L3 |
|---------|-------------|----------|----------|------------|-----|
| Rect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| RoundedRect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Gradient | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Shadow | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Text | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Image | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Clip | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Transform | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| Opacity | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| LayerCompositing | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| BlendMode | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| FilterEffect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| PathVector | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| ShaderEffect | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| TextShaping | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| EmojiText | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |
| AsyncImage | `pr-profile` | `macos-real-skia` | `linux-real-skia` | `windows-real-skia` | summary |

## 发布就绪覆盖

`TextShaping`、`EmojiText` 和 `AsyncImage` 现在已在 `renderer-capability-report.md` 和结构化能力 API 中声明为 `supported`。它们的证明状态：

### TextShaping

- **实现状态**：supported
- **L1 证明**：`pr-profile` job 通过（grapheme break、caret stabilization、UAX#29 fixture）
- **L2 证明**：`macos-real-skia` / `linux-real-skia` / `windows-real-skia` 在每个 PR 上通过（SkShaper/SkParagraph smoke markers、bidi Arabic 和 mixed-direction visual-order markers，通过 `--run-text-emoji-smoke`）
- **发布就绪**：就绪。runtime evidence 在每个 PR 上自动获取。

### EmojiText

- **实现状态**：通过 `Typeface::has_color_glyphs`（font table tag query：COLR/sbix/CBDT/SVG）证明 deterministic color emoji；preflight readiness 和 emoji font fallback diagnostic 现在报告 runtime-determined `deterministic_color_emoji_ready` 和 `glyph_format`（rgba/alpha）。
- **L1 证明**：`pr-profile` job 通过（emoji cluster detection、caret stabilization、glyph format runtime check）
- **L2 证明**：`macos-real-skia` / `linux-real-skia` / `windows-real-skia` 在每个 PR 上通过（emoji glyph/raster observation markers、keycap/regional-indicator/skin-tone-modifier fallback diagnostic markers，通过 `--run-text-emoji-smoke`）
- **发布就绪**：就绪。runtime evidence 自动获取。

### AsyncImage

- **实现状态**：supported（native Skia local-file source 使用 off-main-thread file I/O 加 Skia decode，生成 decoded RGBA completion payload；provider 测试断言 `background_io` 和 `background_decode`）
- **L1 证明**：`pr-profile` job 通过（HostAsyncImageLoader dedup、late callback gating、completion routing、drain_fn spawn/drain cycle、decoded payload header 以及 provider 测试中断言的 `background_io` / `background_decode` flag）
- **L2 证明**：`macos-real-skia` / `linux-real-skia` / `windows-real-skia` 在每个 PR 上通过（local/data URI completion 后的 second-frame repaint marker，通过 `HostNativeAsyncImageSource` completion 的 deferred-completion marker，通过 `--run-renderer-smoke`）
- **发布就绪**：就绪。`moui-renderer-real-skia-ci.yml` workflow 会在每个 PR 上自动获取三个平台的 second-frame 和 deferred-completion marker。
- **Runtime 路径**：Off-main-thread file I/O 和 Skia decode 已通过平台 native worker 为 local-file source 实现（macOS 上 GCD，Linux 上 pthread，Windows 上 CreateThread）。`ImageResourceLoadCompletion` 可携带 decoded RGBA pixels、row bytes、`background_io` 和 `background_decode`，Skia 会把 decoded completion 直接应用到 image cache。

## 移动端状态

Android、iOS 和 HarmonyOS 的**产品分类：`runtime_partial`**（可用的 managed-shell host 路径；不是 product-complete）。请见 [platform-readiness-declaration.md](../platform-readiness-declaration.md)。

Android、iOS 和 HarmonyOS 具有源码级 VSync 和 mobile service bridge。HarmonyOS 还拥有 native-only XComponent pointer/lifecycle ownership 和 touch-slop scroll arbitration。

Historical Component Gallery evidence 保留用于审计，但不会提升已重命名的 Showcase managed shell：

| 平台 | 状态 | Artifact | 备注 |
| --- | --- | --- | --- |
| iOS historical artifact | Release N UIKit shell **`passed`** | `artifacts/mobile-runtime/ios/component_gallery/` | 不是 Showcase evidence。 |
| Android historical artifact | Release N legacy shell **`passed`** | `artifacts/mobile-runtime/android/component_gallery/` | 不是 Showcase evidence。 |
| Showcase managed shells | fresh Android/iOS/HarmonyOS evidence pending | `artifacts/shell-runtime/<platform>/showcase/` | 需要通过真实系统输入、assistive technology 和必要的 repository test-probe plugin 重新运行。 |

CI 入口点：`moui-ios-shell-runtime-evidence.yml`、`moui-android-shell-runtime-evidence.yml`（self-hosted android）、`moui-harmonyos-shell-runtime-evidence.yml`（self-hosted harmonyos + signing）。

`SkiaGpuNative` 按 GPU readback elimination plan 第 1 阶段携带未 promoted 的 window-surface source 路径（iOS/macOS Metal、Android Vulkan/GLES、HarmonyOS EGL/GLES、Windows D3D12、Linux Wayland Vulkan）。native worker 在独立线程上证明安全的 `SkPicture`/POD handoff。它的 macOS 分支现在拥有 Ganesh/Metal context 和 drawable presentation，并在本地 first-frame smoke 后发出 `Presented`；剩余平台 worker ownership 和所有 promotion manifest 仍然 pending。第 2 阶段 promotion gate 脚手架具有 L1 package-test 证明：

| Gate | L1 证明 |
| --- | --- |
| Renderer mailbox control queue (`moui/render/render_frame_mailbox.mbt`) | `moui/render` whitebox tests（capacity-two latest-wins；`RendererControlMessage` never dropped） |
| Native Picture handoff (`moui_skia/native/skia_stub_gpu_worker.cpp`) | 聚焦 native tests（independent thread、retained picture、detach acknowledgement、zero readback counter） |
| Context-loss recovery (`moui/runtime/renderer_recovery.mbt`) | `moui/runtime` whitebox tests（Idle → Lost → Recovering → Recovered → Idle；`FallbackToRaster` after 2 failures） |
| Manifest schema + `gpuPromotionEvidence` (`tools/moui/validate_shell_runtime_manifest`) | `validate_shell_runtime_manifest_wbtest`（9 个新的 Phase 2.3 测试） |

当 host GPU surface 可用时，产品 `auto` 在每个 native Skia 平台默认使用 `SkiaGpuNative`（`gpu_promoted` 全部为 `true`）。Raster 仍然是显式/恢复路径。匹配设备 seven-gate manifest 仍然是质量证据门槛；参见 ADR 0006 和 `shell-mainline-roadmap.md`。

## 证据可追溯性

| CI workflow | Artifact 名称 | 内容 |
|------------|--------------|---------|
| `moui-renderer-real-skia-ci.yml` → `macos-real-skia` | `macos-renderer-real-skia-ci` | `moui_skia/logs/macos-*.log` |
| `moui-renderer-real-skia-ci.yml` → `linux-real-skia` | `linux-renderer-real-skia-ci` | `moui_skia/logs/linux-*.log` |
| `moui-renderer-real-skia-ci.yml` → `windows-real-skia` | `windows-renderer-real-skia-ci` | `moui_skia/logs/windows-*.log` |
| `feature-proof-summary.yml` → `summarize` | `feature-proof-summary` | `artifacts/feature-proof/proof-report.json` + `.md` |

## 更新规则

此看板是静态参考。实际 proof status 由 `feature-proof-summary.yml` 在每次 `ci.yml` 运行后动态生成。检查最新 proof status：

1. 前往 GitHub 仓库中的 **Actions** tab。
2. 找到 **MoUI Feature Proof Summary** workflow。
3. 打开最新 run，检查 `GITHUB_STEP_SUMMARY`，或下载 `feature-proof-summary` artifact。

当新的渲染器功能被添加到 `render/capabilities.mbt` 中的 `RendererFeature` enum 时，更新：
1. `docs/renderer-capability-report.md`（实现状态）
2. `docs/feature-proof-matrix.md`（证明映射）
3. 本看板（功能行）
4. `scripts/generate-feature-proof-report.mjs`（如果引入了新的 L2 job 名称，则更新功能列表）
