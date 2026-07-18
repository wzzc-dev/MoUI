# 测试

MoUI 默认使用有界验证。主线包括包测试、Web `wasm-gc` 构建、静态/元数据 guard，以及当必须观察真实平台、浏览器或渲染器时显式运行的手动 smoke。不要提交生成的 `artifacts/`；它们只作为本地或 CI 证据。

## 每日

常规应用或框架工作请运行每日验证脚本：

```sh
sh scripts/check.sh --profile daily
```

该脚本运行本地依赖 guard、guidance consistency、maintenance baseline ratchets、API surface checks、renderer provider 和 native Skia entrypoint 静态检查、生成的 repository facts 和 source-file policy、smoke gate catalog validation、`moon check`、生成的 public-interface drift detection、core 包测试、Web wasm-gc 包测试、native Skia 主线包测试、`moui_tester` harness tests、`moui_devtools` snapshot/debug tests、Showcase 和 Markdown Editor app tests，以及 Web builds。

每日门禁来源于 `checks/profiles.json`，可用 `node scripts/check.mjs --profile daily --list` 检查。应与目录保持同步的代表性 command token 包括：

```sh
node scripts/lint-scripts.mjs --profile pr
node scripts/validate-check-profiles.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-api-surface.mjs
node scripts/generate-repo-docs.mjs --check
node scripts/validate-window-dependency.mjs
node scripts/validate-harmonyos-shell.mjs
node scripts/validate-harness-invariants.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-source-file-policy.mjs
node scripts/check-website-docs.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-skia-entrypoints.mjs
node scripts/validate-gpu-promotion-manifest.mjs docs/gpu-promotion-manifest.example.json
node scripts/test-validate-skia-entrypoints.mjs
moon test tools/moui/generate_repo_docs --target native
moon test tools/moui/validate_source_file_policy --target native
node --check scripts/test-moui-prebuild.mjs
node scripts/test-moui-prebuild.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node --check scripts/generate-grapheme-break-fixtures.mjs
node scripts/generate-grapheme-break-fixtures.mjs --check
node scripts/test-validate-web-runtime-handoff-manifest.mjs
node scripts/test-web-canvas2d-lazy-fallback.mjs
node scripts/test-web-bundle-tools.mjs
node scripts/test-record-web-runtime-presentation.mjs
node scripts/test-validate-web-runtime-presentation-manifest.mjs
moon test tools/moui/validate_gpu_promotion_manifest --target native
moon test tools/moui/gpu_promotion_scaffold --target native
node scripts/test-gpu-promotion-manifest-lib.mjs
node scripts/test-gpu-performance-metrics.mjs
node scripts/test-check-runner.mjs
node scripts/test-smoke-check.mjs
node scripts/smoke-check.mjs --check
node scripts/test-smoke-gate.mjs
node scripts/smoke-gate.mjs --tier nightly --dry-run --json
moon check
node scripts/check-generated-interfaces.mjs
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/sun --target native
moon test moui/backend/host --target native
moon test moui_tester --target native
moon test moui_devtools --target native
moon test moui_skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/test-validate-web-runtime-handoff.mjs
node scripts/validate-web-runtime-handoff.mjs
```

Design Systems 是 addon 诊断覆盖。修改 `moui_theme` 或 `examples/design_systems` 时，请使用 `sh scripts/check.sh --profile theme`。

Native WGPU 是诊断路线。修改该路线，或需要 full-workspace hotspot guard 时，请使用 `sh scripts/check.sh --profile full`。full profile 会运行每日维护基线，并额外运行 `moon run tools/moui/validate_maintenance_baseline --target native -- --scope full`，以报告 addon/tool 工作区中已注册的大文件热点，而不扩大每日门禁。

generated-interface 步骤会快照每个被跟踪的 `pkg.generated.mbti`，运行一次 workspace-wide `moon info`，并且只在生成产生新差异时失败。这让检查在 dirty working tree 中仍然有用，同时干净 CI checkout 仍会拒绝未提交的 public-interface drift。

`external-consumer.yml` workflow 会把 `checks/external-consumer` 复制到 checkout 外部，并在 Linux/macOS/Windows 矩阵上分别针对 registry 中的 `wzzc-dev/moui@0.1.7` 和当前 `moon package` archive 运行。它的 `moon tree` 与解析后的 `.mooncakes` 路径检查必须报告 `monorepoSource=false`：

```sh
node scripts/external-consumer-ci.mjs --source registry
node scripts/external-consumer-ci.mjs --source package
```

## 聚焦

Playground-focused 检查应同时覆盖 MoonBit editor 行为和静态 browser bundle：

```sh
moon test moui_richtext/code_editor --target native
moon check moui_richtext/code_editor --target wasm-gc
moon test website/playground/app --target native
moon build website/playground/web_wasm --target wasm-gc
node scripts/generate-playground-assets.mjs --out dist/playground
node --check website/playground/host/compiler-worker.js
node --check website/playground/host/playground-bridge.js
node --check website/playground/host/preview-host.js
node scripts/test-playground-assets.mjs --root dist/playground
```

编辑实现代码时，请使用更小的包检查：

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/runtime --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/host --target native
moon test moui/backend/android --target native
moon test moui/backend/android/skia --target native
moon test moui/backend/ios --target native
moon test moui/backend/ios/skia --target native
moon test moui/backend/harmonyos --target native
moon test moui/backend/harmonyos/skia --target native
moon test moui/backend/web --target wasm-gc
moon test moui_tester --target native
moon test moui_devtools --target native
moon test moui_skia --target native
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/excel/cell --target native
moon test examples/excel/formula --target native
moon test examples/excel/sheet --target native
moon test examples/excel/xlsx --target native
moon test examples/excel/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_service_native_transport --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon check examples/counter/android_skia --target native
scripts/build-counter-android-apk.sh --fallback-skia
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/ios_skia --target native
scripts/build-counter-ios-app.sh --fallback-skia
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/harmonyos_demo/harmonyos_skia --target native
scripts/build-harmonyos-demo-app.sh --fallback-skia
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/harmonyos_skia --target native
scripts/build-showcase-harmonyos-hap.sh --fallback-skia
```

仅对 native WGPU 诊断路线使用 `moon test moui/render/wgpu --target native`。交接前使用 `moon fmt`。公开 API 变更后运行 `moon info` 并审查 `pkg.generated.mbti` diff。

当拆分超大的实现或测试文件、减少源码级 `pub(all)`、收缩根 facade，或修改 MoonBit-backed validator wrapper script 时，请运行 maintenance baseline guard，并在同一变更中下调相关预算。MoonBit-backed JS validator 应保持为 `scripts/lib/moonbit-tool-runner.mjs` 上的薄兼容 shim；避免在那里重新引入本地 process runner、直接 filesystem parsing 或 hard-coded native `_build` executable path。

## 脚本工具策略

脚本变更遵循与框架代码相同的 clarity-first 规则。当工作是仓库验证、源码或 manifest 扫描、确定性生成，或可由 `moon check` 和 `moon test` 覆盖的 smoke catalog planning 时，优先使用 MoonBit `tools/...` 包。当 CI 或用户已依赖现有 `node scripts/*.mjs` 命令时，将其保留为稳定 wrapper。

Node 保留用于 browser/CDP、Web smoke、HTTP/GitHub artifacts、npm ecosystem 工作，以及 `scripts/smoke-gate.mjs` execution layer。sh/PowerShell 保持轻薄，用于环境设置和平台分发；Windows MSVC、vcpkg 和 zlib 设置仍由 PowerShell 负责。`.mbtx` 只用于短小 standalone scripts，然后把维护中的 CI 行为升级到 `tools/...`。

`rule`/`dev_build` 不是 task runner。只有当包构建需要确定性的 pre-build input/output generation step 时才使用它。不要用它安装 MSVC、vcpkg、zlib、Chrome、CI runner 或其他机器依赖，也不要把它用于 smoke execution、networking 或 global environment mutation。

## 检查 Profile

`scripts/check.mjs` 是受检查的 profile runner：

```sh
node scripts/check.mjs --profile pr --list
sh scripts/check.sh --profile daily
sh scripts/check.sh --profile platform
sh scripts/check.sh --profile theme
sh scripts/check.sh --profile full
```

CI profile job 使用 shell wrapper 表达门禁意图：`ci.yml` 针对 PR profile gate 运行 `sh scripts/check.sh --profile pr`，针对 Linux platform contracts 运行 `sh scripts/check.sh --profile platform`。Windows MSVC job 保持其 MSVC/build/package step 显式，并只用以下命令验证 PowerShell wrapper 能解析 PR profile：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Pr -DryRun -Json -SkipSubmoduleInit
```

编辑时使用聚焦的 `moon test ...` 包命令。`platform` profile 从 host/Web contract 的共享 platform service checks 和 opportunistic Linux protocol/cache sanity 开始，然后由 `checks/profiles.json` 拥有 host-specific backend/provider package step。`theme` 覆盖 Design Systems addon diagnostics，`full` 添加 full-workspace hotspot scanning、text diagnostics、capture scaffolds、theme checks、platform checks 和 current-host native example builds。

Capture scaffold 会为 screenshot 或 benchmark handoff 在忽略的 `artifacts/` 路径下写入本地 manifest。它们不是 checked-in capability declaration：

```sh
node scripts/conformance-capture-scaffold.mjs --mode golden
node scripts/conformance-capture-scaffold.mjs --mode benchmark
```

## 功能证明矩阵

每个 MoUI 功能都映射到证明它的 CI job。完整映射见 [功能证明矩阵](feature-proof-matrix.md)，当前 proof status 见 [功能状态看板](feature-status-dashboard.md)。`feature-proof-summary.yml` workflow 会在每次 `ci.yml` 运行后生成 proof report。

证明级别：

- **L1**（每个 PR，`ci.yml`）：通过包测试证明 API/algorithm/protocol 正确性。
- **L2**（每个 PR 和 push-to-main，`moui-renderer-real-skia-ci.yml`）：在 macOS/Linux/Windows 匹配 host 上证明真实 Skia runtime behavior。
- **L3**（`feature-proof-summary.yml`）：所有必需 L1 和 L2 通过。

## Smoke

### GPU promotion scaffolds（Wave A）

待处理 manifest 和 gap report（**不会**翻转 `gpu_promoted`）：

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos
node scripts/validate-gpu-promotion-manifest.mjs docs/gpu-promotion-manifest.example.json
```

参见 [gpu-promotion-runbook.md](../gpu-promotion-runbook.md)。

当行为依赖真实渲染器、浏览器或平台 host 时，使用 smoke run：

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
scripts/macos-skia-renderer-smoke.sh --run-ime-smoke
sh scripts/ci-web-runtime-presentation.sh
```

对于 Android packaging 变更，`scripts/build-counter-android-apk.sh --fallback-skia` 是快速 build-system smoke，覆盖 MoonBit C export、registered JNI/CMake、Kotlin/resource packaging 和 debug signing。它不是真实 Skia renderer 或 platform runtime evidence。Android first-frame/input/lifecycle claim 仍要求不带 fallback 的 `scripts/build-counter-android-apk.sh`，并在匹配设备或模拟器上运行且记录观察结果。
canonical Android build entrypoint 现在是 `scripts/build-mobile-android-apk.sh --app <counter|showcase>`；app-specific script 是兼容 wrapper。它默认使用 managed Kotlin shell。`--legacy-java-shell --compile-sdk 35` 只用于审计冻结的 Release N compatibility fixture。

对于 iOS packaging 变更，`scripts/build-counter-ios-app.sh --fallback-skia` 是快速 build-system smoke，覆盖 MoonBit C export、canonical SwiftUI/UIKit host adapter、ABI bridge、iOS runtime compatibility、native-stub compilation、bundle layout 和 ad-hoc simulator signing。它不是真实 Skia renderer 或 platform runtime evidence。iOS first-frame/input/lifecycle claim 仍要求不带 fallback 的 `scripts/build-counter-ios-app.sh`，并在匹配模拟器或设备上运行且记录观察结果。
canonical iOS build entrypoint 现在是 `scripts/build-mobile-ios-app.sh --app <counter|showcase>`，通过 checked-in 的真实 `PBXNativeTarget`；`--legacy-uikit-shell` 只选择冻结的 Release N fixture。运行 `sh moui/mobile/ios/tests/run-ios-managed-shell-tests.sh` 进行聚焦 shell contract audit。使用 `node scripts/record-mobile-runtime-smoke.mjs --platform <android|ios|harmonyos> --app <counter|showcase|harmonyos_demo> --require-passed` 生成用于 release/manual claim 的 checked mobile runtime manifest。recorder 要求 before/after pixel change 和 application receipt log；成功 input injection 或 process termination 本身不是证据。
iOS 路线要求 Meta `idb` 和 `idb-companion`；stock `simctl ui` 不会注入 tap/swipe event。recorder 从当前 accessibility tree 推导 tap，用 `simctl launch` 返回的 PID 过滤 unified log，并使用 idb HOME event 触发真实 background detach。

Showcase 是 service acceptance target。它的 mobile entrypoint 会直接打开 `platform/mobile-service-probe`。一次只在一个 target 上运行 non-fallback build 和 recorder：

```sh
scripts/build-mobile-android-apk.sh --app showcase
node scripts/record-mobile-runtime-smoke.mjs \
  --platform android --app showcase --device <adb-serial> \
  --assistive-tech --require-passed

scripts/build-mobile-ios-app.sh --app showcase
node scripts/record-mobile-runtime-smoke.mjs \
  --platform ios --app showcase --device <simulator-udid> \
  --assistive-tech --require-passed

scripts/build-component-gallery-harmonyos-hap.sh
node scripts/record-mobile-runtime-smoke.mjs \
  --platform harmonyos --app showcase --device <hdc-target> \
  --require-passed
```

probe 按以下顺序驱动：聚焦带 label 的 text field，注入 IME text，通过 native edit command 复制，seed/read system pasteboard 并粘贴回来，激活带 label 的 action，旋转并恢复 target，滚动，然后检查 app log 中 deferred image 的 loading 和 ready frame。clipboard pass 要求 text write 和 read 都完成；resize pass 要求两个不同的 logged physical size。只有真实 TalkBack、VoiceOver 或 HarmonyOS screen-reader session 发出 tree、focus 和 targeted action log 时，accessibility 才通过。

Mobile manifest 使用 `passed`、`partial` 和 `failed`。带有部分 verified observation 的 nonblank run 是 `partial`，不是 `failed`；这会保留已收集证据，同时准确显示仍缺哪些 observation。没有可用证据的 build/install/launch/capture run 仍是 `failed`。Release command 继续使用 `--require-passed`，因此 `partial` 不能通过 release gate。

recorder 还会从 `moui-mobile renderer configure ... status={...}` 捕获可选 `renderer` block（或 fallback 到 `mobile-build.json`）。当 `renderer.gpuPromoted=true` 时，它会附加一个 **pending** seven-gate `gpuPromotionEvidence` skeleton，让 schema validation 通过而不声称 performance/memory/context-loss gate。产品 GPU default 和 seven-gate quality claim 仍然分开。

本地证据快照（2026-07-15）：

- **Historical iOS Component Gallery** under the Release N UIKit shell：`artifacts/mobile-runtime/ios/component_gallery/`（**`passed`**，Metal `gpuAvailable=true`）；这不计作 Showcase evidence
- **Historical HarmonyOS Component Gallery**：`artifacts/mobile-runtime/harmonyos/component_gallery/`（**`partial`**，EGL first frame；services incomplete）；这不计作 Showcase evidence
- **Historical Android Component Gallery**：`artifacts/mobile-runtime/android/component_gallery/`（**`partial`**，Vulkan attach/nonblank/input/a11y/async-image）；这不计作 Showcase evidence。不要在低内存主机上同时运行 Android + HarmonyOS emulator。
- **Showcase managed shells**：新证据路径为 `artifacts/mobile-runtime/<platform>/showcase/`；三大移动平台上的 matching-device evidence 都 pending。
- GPU promotion scaffolds：`artifacts/gpu-promotion/{ios,harmonyos,android}/scaffold-latest/`（不是 L2 proof）

**GPU feasibility (L2) grep：**

```sh
rg -n 'renderer configure|surfaceRoute|gpuAvailable' \
  artifacts/mobile-runtime/ios/component_gallery/runtime-stream.log \
  artifacts/mobile-runtime/android/component_gallery/runtime-stream.log \
  artifacts/mobile-runtime/harmonyos/component_gallery/runtime-stream.log
```

**Android emulator install → APK → verify（copy block）：** 完整步骤在 [android-support.md - Emulator Setup And Smoke](../android-support.md#emulator-setup-and-smoke)。

```sh
scripts/setup-android-sdk.sh --accept-licenses --ndk 28.2.13676358
eval "$(scripts/setup-android-sdk.sh --print-env)"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
sdkmanager --install "emulator" "system-images;android-34;google_apis;arm64-v8a"
echo no | avdmanager create avd -n moui_api34 \
  -k "system-images;android-34;google_apis;arm64-v8a" -d pixel_6 --force
emulator -avd moui_api34 -gpu host -no-snapshot-save &
adb wait-for-device
scripts/build-mobile-android-apk.sh --app showcase --renderer auto
node scripts/record-mobile-runtime-smoke.mjs \
  --platform android --app showcase --device "$(adb devices | awk '/\tdevice$/{print $1; exit}')"
rg -n 'renderer configure|surfaceRoute|gpuAvailable|UnsatisfiedLinkError' \
  artifacts/mobile-runtime/android/showcase/runtime*.log
```

除非 manifest 断言 `gpuPromotionClaim=true` 或 `gpuPromotionEvidence.claimed=true`，否则 mobile runtime `--require-passed` 不要求 seven-gate GPU claim threshold。

在 iOS Simulator 上，rotation 当前通过 macOS UI scripting 使用 Simulator 的 Device menu，因为 Xcode 26.3 `simctl io` 没有 rotate operation。请给运行 `osascript` 的 terminal/automation process 授予 Accessibility 权限；否则 resize 会有意保持 `no`。仅修改 simulator VoiceOver preference 不是 action evidence。需要 focus/action log 时，请使用物理设备或 live assistive-technology session。

对于 HarmonyOS packaging 变更，`scripts/build-harmonyos-demo-app.sh --fallback-skia` 和 `scripts/build-component-gallery-harmonyos-hap.sh --fallback-skia` 是快速 build-system smoke，覆盖 MoonBit C export、package-owned ArkTS Stage Ability/XComponent managed shell、fixed-ABI NAPI bridge、generated plugin registry、native glue compilation、native-stub compilation 和 staged HAP archives。checked-in app-owned project 是 Release N fixture。这些构建不是真实 Skia renderer 或 platform runtime evidence。HarmonyOS first-frame/input/lifecycle claim 仍要求 non-fallback HAP，并在匹配设备或模拟器上运行且记录 observation。

HarmonyOS release/manual smoke 通过 `hdc` 使用同一 recorder：

```sh
node scripts/record-mobile-runtime-smoke.mjs --platform harmonyos --app harmonyos_demo --require-passed
node scripts/record-mobile-runtime-smoke.mjs --platform harmonyos --app showcase --require-passed
```

通过的 mobile evidence 要求实际 lifecycle detach、IME state 和 edit、system text-clipboard write/read completion、accessibility tree/focus/action，以及 async-image loading/ready observation。PNG clipboard interoperability 是单独的手动 cross-app check，不得从 text probe 推断。缺失 observation 保持 pending/failed，而不是从 API presence 推断。

`smoke/gates.json` 是 checked-in smoke gate catalog。它描述 daily、nightly 和 release smoke tier、每个 suite command、结构化 result shape、owning workflow，以及解释门禁的文档。无需运行 platform smoke 即可验证它：

```sh
node --check scripts/smoke-check.mjs
node --check scripts/test-smoke-check.mjs
node scripts/test-smoke-check.mjs
node scripts/test-validate-mobile-runtime-manifest.mjs
node scripts/smoke-check.mjs --check
node scripts/smoke-check.mjs --tier nightly --list
node scripts/smoke-check.mjs --tier release --json
node scripts/smoke-gate.mjs --tier nightly --dry-run --json
node scripts/smoke-gate.mjs --suite web.runtime-presentation --run
```

catalog check 是 daily profile 的一部分；真实 browser/platform smoke 仍为 opt-in。`scripts/smoke-gate.mjs` 是从 catalog 中选择 suite 的统一 runner；默认 dry-run，并且在运行标记为 manual 的 command 前要求 `--allow-manual`。scheduled/manual `.github/workflows/moui-runtime-gates.yml` workflow 是 Web runtime presentation nightly smoke 和手动 macOS real Skia release smoke 的 CI 入口点。

Web script 构建 Showcase、服务仓库、在 `artifacts/smoke/web-runtime-presentation/` 下记录 Chrome/CDP browser-session manifest，并用 `validate-web-runtime-presentation-manifest.mjs` 验证它。请把结果视为该 browser session 的手动 smoke log。

Native Skia smoke log 可以显示 renderer pixels、async image second-frame behavior、可选 SkParagraph text behavior，以及 tester-owned first-frame 或 IME observation。它们是直接 pass/fail runtime log，不是 repository manifest gate。

Linux Skia first-frame evidence 请使用匹配的 Wayland host，并保持 Showcase、Markdown Editor 和 window-package smoke log 分离：

```sh
MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/showcase/linux_skia --target native
MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/markdown_editor/linux_skia --target native
scripts/run-window-package-smoke.sh linux --run
```

## 发布说明

Release readiness 应引用相关 CI run、已上传 artifact 或 smoke log。不要把生成的 `artifacts/` JSON 作为长期事实来源提交。

## Agent 与 Skill 检查

修改仓库 guidance 时，请同步更新这些 surface：

- `docs/`
- `AGENTS.md`
- `skills/moui-app-development/SKILL.md`
- `skills/moui-framework-development-skill/SKILL.md`
- `tools/moui/validate_guidance_consistency/*`

然后运行：

```sh
node scripts/check-website-docs.mjs
```
