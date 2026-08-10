# MoUI Cross-Platform Verifiability Declaration

> Version: 2026-07-16
> Every claim below can be independently verified through its referenced CI workflow, run record, artifact name, or test file.

---

<!-- BEGIN GENERATED PLATFORM TIER MATRIX -->
| Tier | Canonical routes | Gate |
|---|---|---|
| Tier 1 | `macOS Skia`, `Web wasm-gc WebGPU (Canvas2D fallback)` | Blocking: PR build/test, daily presentation, and release evidence |
| Tier 2 | `Windows Skia`, `Linux Skia` | Blocking: L0-L2 and first frame; complete L3 may remain partial |
| Tier 3 | `macOS WGPU (CoreText, Cosmic fallback)`, `Windows WGPU (DirectWrite, Cosmic fallback)`, `Linux WGPU (Fontconfig, Cosmic fallback)`, `Android window-hosted Skia`, `iOS window-hosted Skia`, `HarmonyOS window-hosted Skia`, `macOS Sun`, `Windows Sun`, `Linux Sun`, `WeChat Skyline Canvas2D` | Non-blocking: scheduled/manual build, run, and evidence |

Tier, L0-L3 evidence, and `product_class`/`ready` are independent. Source: `checks/platform-matrix.json`; actual observations remain in `checks/platforms/*.json`.
<!-- END GENERATED PLATFORM TIER MATRIX -->

## Product Commitment Matrix (`product_class`)

This table is the single public source of truth for whether a platform can serve
as a product mainline. It differs from the mainline/diagnostic **engineering
gates** in `docs/maintenance.md`: those define the routine `check.sh` scope, not
OS product completeness.

| Platform | `product_class` | Semantics of `ready` (host API) | Evidence summary | Not yet committed |
|------|---------------|-------------------------|----------|----------|
| **macOS** | **committed** | Usable as a product mainline | L0–L2 PR gates + L3 platform runtime passed (`checks/platforms/macos.json`) | — |
| **Web** | **committed** | Usable as a product mainline | Daily wasm-gc + browser WebGPU; `checks/platforms/web.json` `runtimeL3=passed` | — |
| **Windows** | **committed_with_gaps** | Usable as a product mainline (L3 incomplete) | L0–L2 PR/real Skia; `runtimeL3=partial` | Complete IME/service L3 |
| **Linux** | **committed_with_gaps** | host `ready=true` = implementation path available, **≠** all L3 checks green | L0–L2 + first-frame L3; interactive IME and similar checks are partial | Complete interactive L3 |
| **Android** | **experimental** | `ready=false`: the window-hosted template + session compile and host-sim tests pass, but no development/demonstration usability or product commitment is made; `status=experimental` | `HostCmd` host-sim and MoUI adapter tests pass | Matching-device presenter/service evidence; GPU seven-gate claim; usability commitment |
| **iOS** | **experimental** | Same as above | `HostCmd` host-sim and MoUI adapter tests pass | Matching simulator/device presenter and VoiceOver evidence; GPU seven-gate claim; usability commitment |
| **HarmonyOS** | **experimental** | Same as above | `HostCmd` host-sim and MoUI adapter tests pass | Signed-device presenter/service evidence; GPU seven-gate claim; usability commitment |
| **WeChat Mini Program** | **experimental** | `ready=false`: the window-hosted Canvas 2D session compiles, but no development/demonstration usability or product commitment is made; `status=experimental` | Canvas 2D renderer and wasm-gc build pipeline compile; Skyline project template is staged | Real Mini Program pixel smoke; touch event verification; wx API service integrations; usability commitment |

### Linux RISC-V64 Architecture Variant

Linux RISC-V64 is recorded as `linux-skia-riscv64` under
`checks/platform-matrix.json`, not as a new canonical platform route. The
variant targets `riscv64-linux-gnu`, is Tier 3 and `experimental`, and keeps
`ready=false` while the matching-device Wayland path is unverified.

| Evidence | Initial contract | Promotion boundary |
|---|---|---|
| L0 | Cross-built `examples/showcase/linux_skia` ELF64 RISC-V | Locked sysroot, Zig wrapper, and ELF report |
| L1 | Cross-build package/link checks | Target GLib/Wayland/fontconfig pkg-config and native link success |
| L2 | QEMU offscreen Skia Raster renderer and text/emoji smokes | Real pixel markers, async second frame, and SkParagraph output |
| L3 | `pending` | Matching RISC-V64 Wayland device first frame, input, IME, clipboard, and services |

The independent evidence file is
`checks/architecture-evidence/linux-skia-riscv64.json`. QEMU L2 evidence does
not promote `checks/platforms/linux.json` or the Linux Wayland runtime claim.

### Two Prohibited Misstatements

1. **Do not** state “all six platforms are product-ready / all L3 checks are green.”
2. **Do not** state “the three embedded runtime backends are entirely nonfunctional / lifecycle glue is unwired / only a Counter app exists.” The embedded runtime backends and IME/clipboard/a11y channels exist; the gap is in the **evidence loop and promotion**, not an absent host path.

### Do Not Conflate the Three Status Sets

| Dimension | Meaning |
|------|------|
| Host availability (`ready`) | `true` only when development/demonstration can rely on the window-hosted template + MoUI session (Linux-aligned: implementation complete and usable); `false` for `experimental` platforms until matching-device evidence lands |
| Runtime evidence (`status` / smoke) | Matching-host observation: `passed` / `partial` / packaging-only; mobile product_class `experimental` is deliberately below `runtime_partial` |
| Product-completeness commitment | All L3 checks green + `actualPresenterRoute` verified + GPU seven-gate claimed |

Mobile product_class `experimental` means: code paths compile and host-sim
tests pass, but **no** development/demonstration usability or product
commitment is made until matching-device presenter/service evidence is
recorded. It is a *downgrade* from the previous `runtime_partial` claim
(see ADR 0021); it does **not** claim the backends are nonfunctional.

The structured status source is
`checks/platforms/{macos,windows,linux,web,android,ios,harmonyos}.json`.
**Do not raise** `runtimeL3` / `actualPresenterRoute` **without new evidence**.

The GPU product default (`NativeGpuPlatform::gpu_promoted=true`) and the
a seven-gate **quality claim** are tracked separately; see ADR 0006.

---

## Repository and Usage

### Clone the Repository

```bash
# 方式一：GitLink（国内推荐，速度快）
git clone git@code.gitlink.org.cn:wzzc/MoUI.git
cd MoUI
git submodule update --init --recursive

# 方式二：GitHub
git clone git@github.com:wzzc-dev/MoUI.git
cd MoUI
git submodule update --init --recursive
```

### Environment Requirements

- MoonBit toolchain (see `.moonbit-toolchain` for the version)
- Local development: macOS 14+ (recommended), Linux (Wayland), or Windows (MSVC 2022)
- Install dependencies before the first run:

```bash
moon update
```

### Routine Validation

```bash
# 快速检查
moon fmt --check
moon check --target all

# 完整开发验证套件
sh scripts/check.sh --profile daily

# 公共接口漂移检测
moon info
git diff --exit-code -- '**/pkg.generated.mbti'

# 运行示例（macOS）
moon run examples/mo_workbench/macos_skia --target native
moon run examples/markdown_editor/macos_skia --target native
moon run examples/showcase/macos_skia --target native
```

---

## I. Declaration Entity

| Item | Value |
|------|-----|
| Project name | MoUI — cross-platform MoonBit UI framework |
| Repository | `https://github.com/wzzc-dev/MoUI` |
| Main branch | `main` |
| Declaration scope | Framework core + rendering pipeline + platform backends + text system + example applications |
| Rendering backends | Skia Raster Native (mainline), WebGPU wasm-gc (Web), WGPU (experimental; engineering gate `diagnostic`) |

## II. Target Platforms and Evidence Levels

| Level | Definition | CI trigger | Host requirement |
|------|------|---------|----------|
| **L0 — Compile/API** | Successful compilation, stable public API, formatting compliance | Every PR (`ci.yml`) | None (fallback-safe build) |
| **L1 — Algorithm/Protocol** | Package tests pass without a real renderer | Every PR (`ci.yml`) | None |
| **L2 — Runtime Behavior** | Pixel-level rendering verification with real Skia/WebGPU | Every PR (`moui-renderer-real-skia-ci.yml`) | Matching host |
| **L3 — Full-Platform Evidence** | Full-platform runtime behavior, including first-frame presentation, IME, clipboard, and window services | Scheduled + manual trigger | Matching host (Wayland/MSVC/AppKit) |

### Evidence Criteria

- L2 renderer proof and L3 platform-runtime proof are recorded separately. A
  successful real-Skia render does not mean platform windows, IME, clipboard,
  accessibility, and other services have all passed.
- First-frame/Wayland evidence in L3 proves only that the corresponding platform
  route can present its first frame on a matching host. Describe a platform
  runtime as fully passed only when observations for IME, window services, input,
  clipboard, and similar capabilities also have matching-host logs.
- The “current” status on this page is based on the most recent verifiable
  successful workflow run. Historical failed or partially successful runs may
  provide diagnostic context, but must not override newer successful evidence.

## III. Platform Evidence Matrix

### 3.1 macOS / Darwin

| Evidence type | Status | Verification method | Most recent passing record |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ Passed | `ci.yml → pr-profile` → `sh scripts/check.sh --profile pr`, including `moon check` | Every PR |
| L0: `moon fmt --check` | ✅ Passed | `ci.yml → pr-profile` → `moon fmt --check` | Every PR |
| L0: `moon info` | ✅ No drift | `ci.yml → api-surface` → `moon info -p <pkg>` + `git diff --exit-code` | Every PR |
| L1: `moon test` package tests | ✅ Passed | `ci.yml → pr-profile` → `moon test moui/{core,views,render,backend,...}` | Every PR |
| L1: text-consistency tests | ✅ Passed | Covered locally/before release by `sh scripts/check.sh --profile full`; real Skia text proof is covered by the renderer-proof workflow | Before release / renderer proof |
| L2: real Skia renderer | ✅ All 17 features passed | `moui-renderer-real-skia-ci.yml → macos-real-skia` | Every PR |
| L2: text/emoji (SkParagraph) | ✅ Passed | `moui-renderer-real-skia-ci.yml → macos-real-skia --run-text-emoji-smoke` | Every PR |
| L2: async images | ✅ Passed | `moui-renderer-real-skia-ci.yml → macos-real-skia --run-renderer-smoke` | Every PR |
| L3: macOS platform-runtime evidence | ✅ Passed | `MoUI macOS Platform Evidence` → GitHub Actions Run [27217345886](https://github.com/wzzc-dev/MoUI/actions/runs/27217345886) | 2026-06-17 |
| L3: native macOS first frame | ✅ Passed | Same workflow; Showcase macOS Skia first-frame log, artifact `moui-macos-platform-runtime-evidence` | run 27217345886 |
| L3: macOS IME runtime | ✅ Passed | Same workflow; all 22 observations are `yes` (`imeCandidateAnchor`, `imeCompositionVisual`, and so on) | run 27217345886 |

**Verification path**: `artifacts/tmp-gh-macos-platform-runtime-evidence-27217345886/conformance/platform-runtime-evidence.json` → `macos` entry `status=passed`, `evidenceProvenance.kind=github-actions`

### 3.2 Windows / MSVC

| Evidence type | Status | Verification method | Most recent passing record |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ Passed | `ci.yml → windows-native` → `moon check` (cross-platform; not separately run in Windows CI, but protected by `check.sh --profile daily`) | Every PR |
| L0: `moon info` | ✅ No drift | `ci.yml → api-surface` | Every PR |
| L1: Windows backend tests | ✅ Passed | `ci.yml → windows-native` → `moon test moui/backend/windows --target native` + `moon test moui_skia_renderer --target native` | Every PR, Run [28964136358](https://github.com/wzzc-dev/MoUI/actions/runs/28964136358) |
| L1: Windows Skia factory/binding tests | ✅ Passed | `moon test moui_skia_renderer --target native` in the same job | Every PR |
| L1: Windows MSVC build | ✅ Passed | `ci.yml → windows-native` → MSVC Skia entrypoint builds successfully; artifact uploaded | Every PR |
| L2: real Skia renderer (Windows) | ✅ Passed | `moui-renderer-real-skia-ci.yml → windows-real-skia` | Every PR |
| L2: Windows text/emoji | ✅ Passed | `moui-renderer-real-skia-ci.yml → windows-real-skia --run-text-emoji-smoke` | Every PR |
| L2: Windows async images | ✅ Passed | `moui-renderer-real-skia-ci.yml → windows-real-skia --run-renderer-smoke` | Every PR |
| L3: Windows platform-runtime evidence | ⏳ **Pending** | Must be produced on an MSVC matching host through the following process: | — |
| L3: Windows first-frame presentation | ⏳ **Pending** | `MOUI_FIRST_FRAME_EXIT=1 moon run examples/showcase/windows_skia --target native` | — |
| L3: Windows IME runtime | ⏳ **Pending** | Requires the full platform-evidence recording process on an MSVC environment | — |

#### Windows L3 Evidence Completion Plan

Windows platform-runtime evidence is currently marked `pending` in
`platform-runtime-evidence.json`; all 22 observations are `pending`. Complete it
as follows:

```
# 1. 在 Windows MSVC 主机上构建 Showcase
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly

# 2. 运行首帧退出测试
set MOUI_FIRST_FRAME_EXIT=1
moon run examples/showcase/windows_skia --target native

# 3. 收集运行时日志至 artifacts/platform-evidence/windows/
```

**Prerequisites**: Windows MSVC toolchain + vcpkg zlib + a real Skia provider.
The `moui-skia-provider-windows-real-skia-manual.yml` CI workflow provides the
complete environment and can be manually triggered with `workflow_dispatch`.

#### Windows Evidence References

| Reference | Details |
|----------|------|
| CI workflow | `moui-skia-provider-windows-real-skia-manual.yml` — supports both MSVC and MinGW toolchains |
| Log artifact | `windows-real-skia-smoke-log` — includes preflight/smoke/acceptance logs |
| Build artifact | `moui-showcase-windows-msvc-portable` — CI run 28509416649 |
| Evidence-recording script | `window/scripts/record_moui_evidence.sh` — supports the Windows backend |
| Runtime-capture script | `window/scripts/capture_moui_runtime_evidence.sh` — end-to-end Windows runtime-evidence capture |

### 3.3 Linux / Wayland

| Evidence type | Status | Verification method | Most recent passing record |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ Passed | `ci.yml → pr-profile` → `sh scripts/check.sh --profile pr`, including `moon check` | Every PR |
| L0: `moon info` | ✅ No drift | `ci.yml → api-surface` | Every PR |
| L1: Linux backend tests | ✅ Passed | `ci.yml → linux-platform` → `sh scripts/check.sh --profile platform` | Every PR |
| L1: Linux package tests | ✅ Passed | `ci.yml → linux-platform` — native tests for core/views/render/backend | Every PR |
| L2: real Skia renderer (Linux) | ✅ Passed | `moui-renderer-real-skia-ci.yml → Linux renderer real Skia` | Run [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550), 2026-07-08 |
| L2: Linux text/emoji/async images | ✅ Passed | The same workflow reports successful text/emoji smoke and renderer smoke | Run 28964136550 |
| L2: historical partial Linux renderer record | ℹ️ Historical diagnostic | Run [27217209784](https://github.com/wzzc-dev/MoUI/actions/runs/27217209784) once had a failed Linux text check; superseded by newer run 28964136550 | 2026-06-17 |
| L3: Linux first-frame / Wayland runtime route | ✅ Passed | `MoUI Linux Platform Evidence` → `Linux platform runtime evidence` job | Run [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278), 2026-07-07 |
| L3: complete Linux platform-service / IME evidence | ⏳ **Partially passed** | First-frame rendering verified (CI Run 28889055278); services complete at code level (clipboard, file dialog, directory listing, IME, AT-SPI, and so on); all 8 WSL2 IME probe fields passed (`enabled/hint/surrounding/cursor/updated/updated_hint/updated_cursor/disabled=true`), but interactive input (pointer/keyboard) and the complete destroy sequence still require strict input-log evidence from a matching Wayland desktop host | 2026-07-11 |

#### Linux L3 Evidence Details

The `moui-linux-platform-evidence.yml` CI workflow runs every Monday at 05:17 UTC:

```
workflow: MoUI Linux Platform Evidence
environment: ubuntu-24.04 + Weston headless + Wayland
证据制品: moui-linux-platform-evidence
  ├── linux-platform-evidence-preflight.log
  ├── linux-skia-first-frame.log
  ├── linux-platform-evidence-summary.log
  └── weston-headless.log
```

Most recent successful run: GitHub Actions Run
[28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278), commit
`8a054c5914adbfa34a6943570c1ceb01cc603ef5`.

The evidence script uses the dedicated
`moui_tests/tester/linux_skia_first_frame_smoke` test program (similar to macOS
`moui_tests/tester/macos_skia_first_frame_smoke`), hard-coded with
`first_frame_smoke_auto_exit=true`; it exits automatically and prints a marker
after presenting the first frame. That run proves the Linux Wayland + Skia
first-frame route.

Code-level service completeness: the Linux backend is now fully wired—clipboard
(text + image dynamic buffer + GTK fallback), file dialog (portal + zenity),
directory listing (`@fs.read_dir`), text/binary file I/O, open URL (portal +
xdg-open), system theme, native menus (zenity + kdialog), IME, drag-drop, AT-SPI
accessibility, GLib timer, client-side decorations, multi-window, platform-view
plugins, and async image loading (pthread + Skia decode). `readiness()` is marked
`ready: true` with `blocked_by: []`.

#### WSL2 Validation Results (2026-07-11)

End-to-end runtime-evidence capture for the Linux backend was performed in a
WSL2 + WSLg (Debian 13 on Windows) environment:

```
bash window/scripts/capture_moui_runtime_evidence.sh linux \
  --log artifacts/platform-evidence/linux/moui-linux-runtime.log
```

**Passed checks:**
- ✅ Wayland surface/handle/probe: all operate normally (`wl_display`,
  `wl_surface`, `xdg_surface`, and `xdg_toplevel` are all nonzero)
- ✅ Present: `present result=0`
- ✅ Cursor: `Icon(Text)`
- ✅ Resize + repaint: requested 400×240 → actual 320×180, with
  `pre_present_notify` confirmation
- ✅ **IME probes: all 8 fields passed!** `enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true`
- ✅ Clipboard data device: `clipboard=true clipboard_roundtrip=true drag_drop=true`
- ✅ `check_ci.sh` CI check passed

**Checks not passed (due to non-interactive WSL2 environment constraints):**
- ❌ `pointer=false` — no mouse events are injected automatically
- ❌ `keyboard=false` — no keyboard events are injected automatically
- ❌ `current=false` (monitor) — the window did not receive focus
- ❌ Destroy sequence incomplete — the process exited after timeout

**Conclusion:** The IME protocol is functionally complete in WSL2/WSLg; all IME
probe fields passed. A complete L3 platform-runtime pass still requires running
with `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` on a **real Wayland desktop** (Ubuntu
24.04+), where an operator provides actual keyboard input (for example, pressing
`a`) and a mouse click while the smoke-test window has focus to obtain pointer/
keyboard evidence.

Complete IME runtime evidence still requires a matching-host Wayland execution
of `capture_moui_runtime_evidence.sh linux`.

#### Linux Evidence References

| Reference | Details |
|----------|------|
| CI workflow | `moui-linux-platform-evidence.yml` — Weston headless compositor + 60-minute timeout |
| Evidence script | `scripts/linux-platform-evidence.sh` — seven-step automated evidence collection |
| Linux Skia dependency script | `moui_skia/scripts/install-linux-smoke-deps.sh` |
| Renderer-proof artifact | Logs uploaded by `moui-renderer-real-skia-ci.yml` run 28964136550: `linux-renderer-real-skia-ci` |
| Evidence-recording script | `window/scripts/record_moui_evidence.sh` — supports the Linux backend |
| Runtime-capture script | `window/scripts/capture_moui_runtime_evidence.sh` — end-to-end Linux runtime-evidence capture |
| WSL2 validation run | Local capture log `artifacts/platform-evidence/linux/moui-linux-runtime.log` — 2026-07-11, WSL2 + WSLg; all 8 IME fields passed |

### 3.4 Web / Wasm-gc

| Evidence type | Status | Verification method | Most recent passing record |
|----------|------|----------|-------------|
| L0: build | ✅ Passed | `ci.yml → pr-profile` → Showcase/Markdown Editor Web wasm-gc build | Every PR |
| L1: Web backend tests | ✅ Passed | `ci.yml → pr-profile` → `moon test moui/backend/web --target wasm-gc` | Every PR |
| L1: WebGPU adapter tests | ✅ Passed | `ci.yml → pr-profile` → `moon test moui_web_renderer --target wasm-gc` | Every PR |
| L2: Web browser presentation | ✅ Passed | `checks/platforms/web.json` `rendererL2=passed` (`browser-webgpu`); CI / Pages browser session | Aligned with the structured platform contract |
| L3: Web runtime-presentation manifest | ✅ Passed | `checks/platforms/web.json` `runtimeL3=passed` (browser presentation manifest); `scripts/ci-web-runtime-presentation.sh` / `record-web-runtime-presentation.mjs` | Aligned with the structured contract; do not downgrade without new evidence |

## IV. Per-Feature Renderer Evidence Chain

The following 17 renderer features have a corresponding L2 CI job on each of
the three native platforms.

| Feature | macOS L2 | Windows L2 | Linux L2 |
|------|----------|------------|----------|
| Rect | ✅ macos-real-skia | ✅ windows-real-skia | ✅ linux-real-skia |
| RoundedRect | ✅ | ✅ | ✅ |
| Gradient | ✅ | ✅ | ✅ |
| Shadow | ✅ | ✅ | ✅ |
| Text | ✅ | ✅ | ✅ |
| Image | ✅ | ✅ | ✅ |
| Clip | ✅ | ✅ | ✅ |
| Transform | ✅ | ✅ | ✅ |
| Opacity | ✅ | ✅ | ✅ |
| LayerCompositing | ✅ | ✅ | ✅ |
| BlendMode | ✅ | ✅ | ✅ |
| FilterEffect | ✅ | ✅ | ✅ |
| PathVector | ✅ | ✅ | ✅ |
| ShaderEffect | ✅ | ✅ | ✅ |
| TextShaping | ✅ | ✅ | ✅ |
| EmojiText | ✅ | ✅ | ✅ |
| AsyncImage | ✅ | ✅ | ✅ |

**Verification entrypoint**: `moui-renderer-real-skia-ci.yml` runs on every PR.
The most recently verified successful run across all three platforms is
[28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550), head
SHA `91f596e80d5a5f80d30fa94a8510e5ce4653189e`.

## V. Verifiable CI Run Records

| Workflow | Run ID | Key passing jobs | Uploaded artifacts | SHA |
|--------|---------|----------------|----------|-----|
| MoUI CI | [28964136358](https://github.com/wzzc-dev/MoUI/actions/runs/28964136358) | Windows MSVC native smoke, Linux platform contracts, Public API surface, PR profile gate, macOS packaging smoke, Benchmark scaffold | moui-showcase-windows-msvc-portable, moui-webview-demo-windows-msvc-portable, moui-showcase-macos-app ... | `91f596e` |
| MoUI Renderer Real Skia CI | [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550) | macOS renderer real Skia, Linux renderer real Skia, Windows renderer real Skia | macOS/Linux/Windows renderer real Skia logs | `91f596e` |
| MoUI macOS Platform Evidence | [27217345886](https://github.com/wzzc-dev/MoUI/actions/runs/27217345886) | macOS platform runtime evidence → status=passed; Native Skia renderer proof (macos) → status=passed | moui-macos-platform-runtime-evidence, moui-renderer-proof-skia-native-macos | `5bb2d810` |
| MoUI Linux Platform Evidence | [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278) | Linux platform runtime evidence → first-frame Wayland route success | moui-linux-platform-evidence | `8a054c` |
| Deploy Website | [28964136340](https://github.com/wzzc-dev/MoUI/actions/runs/28964136340) | Build website, Deploy website | github-pages | `91f596e` |

## VI. Missing Evidence and Completion Plan

### 6.1 Windows L3 — Platform Runtime

| Missing item | Completion action | Prerequisites | Estimated effort |
|--------|---------|----------|---------|
| Showcase Windows first-frame log | Run `moon run examples/showcase/windows_skia --target native` with `MOUI_FIRST_FRAME_EXIT=1` | Windows MSVC environment + real Skia provider | One manual CI trigger |
| Markdown Editor Windows first-frame log | Same as above, using the Markdown Editor entrypoint | Same as above | One manual CI trigger |
| Windows IME runtime observations | Windows flow in `window/scripts/capture_moui_runtime_evidence.sh` + `record_moui_evidence.sh` | Windows host + MSVC + real Skia | One local or CI run |
| Windows full evidence-manifest update | Write results to the Windows entry in `platform-runtime-evidence.json` | Complete the preceding three items | One PR |

### 6.2 Linux L3 — Complete Platform Runtime

| Missing item | Completion action | Prerequisites | Estimated effort |
|--------|---------|----------|---------|
| Linux first-frame / Wayland route log | `scripts/linux-platform-evidence.sh` | ✅ Passed (CI Run 28889055278; local WSL2/Wayland 2026-07-11) | ✅ Completed |
| Linux IME runtime observations (interactive input) | Run `window/scripts/capture_moui_runtime_evidence.sh linux --require-input`, or run `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 bash window/scripts/check_moui_linux_smoke.sh --run` on a real Wayland desktop and ensure an operator provides input while the window has focus | Wayland desktop host + interactive input | One local run |
| Linux IME protocol functionality | WSL2 validation passed: all 8 IME probe fields (`enabled/hint/surrounding/cursor/updated/updated_hint/updated_cursor/disabled`) are true | Validated with `capture_moui_runtime_evidence.sh` on WSL2 + WSLg | ✅ Completed (WSL2 2026-07-11) |
| Complete Linux platform-service observations | Clipboard images, directory listing, font fallback | Directory listing and clipboard images implemented and tested; first-frame rendering verified | ✅ Completed (code level) |
| Linux full evidence-manifest update | Write the complete service/IME results to the Linux entry in `platform-runtime-evidence.json` | Complete interactive-input IME runtime observation | One PR |

### 6.3 Android / iOS / HarmonyOS — Window-hosted Mainline

The embedded runtime route is `wzzc-dev/window` `HostCmd` → `EventLoop` →
`ApplicationHandler` → MoUI `*EmbeddedRuntimeBackend`. Host-sim coverage verifies the
template callback path, backend adapters, and Counter entrypoints without an
emulator:

```sh
sh scripts/window-hosted-hostsim-smoke.sh
```

| Platform | Current evidence | Remaining work |
|------|--------|------|
| Android | host-sim and package checks | matching-device presentation, input, lifecycle, and service evidence |
| iOS | host-sim and package checks | matching simulator/device presentation, input, lifecycle, and service evidence |
| HarmonyOS | host-sim and package checks | signed-device presentation, input, lifecycle, and service evidence |

Use `scripts/window-hosted-vm-smoke.sh` with one of
`WINDOW_HOSTED_ANDROID_AVD=1`, `WINDOW_HOSTED_IOS_SIM=1`, or
`WINDOW_HOSTED_HARMONYOS_HVD=1` when the corresponding target is available.

The GPU seven-gate (`gpuPromotionEvidence.claimed=true`) remains an independent
L3 quality declaration and is not claimed in this round.

## VII. Verification Instructions

The following commands independently verify the declarations locally or in CI:

```bash
# L0 — 公共 API 核验
moon info
git diff --exit-code -- '**/pkg.generated.mbti'

# L0 — 格式化核验
moon fmt --check

# L1 — 全包测试核验
sh scripts/check.sh --profile daily

# L2 — 真实 Skia 渲染核验（需真实 Skia binding 链接）
moon run moui_skia/scripts/native_smoke --target native

# L2 — 文本/表情符号核验（需真实 Skia）
moon run moui_tests/skia_text_emoji_smoke/native --target native

# L3 — macOS 平台运行时证据（macOS 主机）
MOUI_FIRST_FRAME_EXIT=1 moon run examples/showcase/macos_skia --target native

# L3 — Linux 首帧 / Wayland route 证据（Wayland 主机）
moon run moui_tests/tester/linux_skia_first_frame_smoke --target native

# L3 — Windows 平台运行时证据（MSVC 主机）（需要安装、配置 MSVC 工具链）
set MOUI_FIRST_FRAME_EXIT=1
moon run examples/showcase/windows_skia --target native

# Web 运行时呈现记录
node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223
```
