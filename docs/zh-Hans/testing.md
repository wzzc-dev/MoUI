# 测试

MoUI 默认使用有界验证。主线包括包测试、Web `wasm-gc` 构建、静态/元数据 guard，以及当必须观察真实平台、浏览器或渲染器时显式运行的手动 smoke。不要提交生成的 `artifacts/`；它们只作为本地或 CI 证据。

## 每日

常规应用或框架工作请运行每日验证脚本：

```sh
sh scripts/check.sh --profile daily
```

该脚本运行本地依赖 guard、guidance consistency、maintenance baseline ratchets、API surface checks、renderer provider 和 native Skia entrypoint 静态检查、生成的 repository facts 和 source-file policy、smoke gate catalog validation、`moon check`、生成的 public-interface drift detection、core 包测试、Web wasm-gc 包测试、native Skia 主线包测试、内部 `moui_tests/tester` harness tests、`moui_devtools` snapshot/debug tests、Showcase 和 Markdown Editor app tests，以及 Web builds。

每日门禁来源于 `checks/profiles.json`，可用 `node scripts/check.mjs --profile daily --list` 检查。应与目录保持同步的代表性 command token 包括：

```sh
node scripts/lint-scripts.mjs --profile pr
node scripts/validate-check-profiles.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-api-surface.mjs
node scripts/generate-repo-docs.mjs --check
node scripts/validate-window-dependency.mjs
node scripts/validate-harness-invariants.mjs
node scripts/validate-maintenance-baseline.mjs
moon run tools/moui/validate_source_file_policy --target native
node scripts/check-website-docs.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-skia-entrypoints.mjs
node scripts/validate-gpu-promotion-manifest.mjs docs/gpu-promotion-manifest.example.json
node --check scripts/test-moui-prebuild.mjs
node scripts/test-moui-prebuild.mjs
node --check scripts/generate-grapheme-break-fixtures.mjs
node scripts/generate-grapheme-break-fixtures.mjs --check
node scripts/test-web-canvas2d-lazy-fallback.mjs
node scripts/test-web-bundle-tools.mjs
node scripts/smoke-check.mjs --check
moon check
node scripts/check-generated-interfaces.mjs
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui_skia_renderer --target native
moon test moui_sun_renderer --target native
moon test moui/backend --target native
moon test moui_tests/tester --target native
moon test moui_devtools --target native
moon test moui_skia --target native
moon test moui_web_renderer --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/validate-web-runtime-handoff.mjs
```

Design Systems 是 addon 诊断覆盖。修改 `moui_theme` 或 `examples/design_systems` 时，请使用 `sh scripts/check.sh --profile theme`。

Native WGPU 是诊断路线。修改该路线，或需要 full-workspace hotspot guard 时，请使用 `sh scripts/check.sh --profile full`。full profile 会运行每日维护基线，并额外运行 `moon run tools/moui/validate_maintenance_baseline --target native -- --scope full`，以报告 addon/tool 工作区中已注册的大文件热点，而不扩大每日门禁。

generated-interface 步骤会快照每个被跟踪的 `pkg.generated.mbti`，运行一次 workspace-wide `moon info`，并且只在生成产生新差异时失败。这让检查在 dirty working tree 中仍然有用，同时干净 CI checkout 仍会拒绝未提交的 public-interface drift。

### Linux RISC-V64 实验路线

RISC-V64 是 `linux/skia` 的非阻塞 scheduled/manual 架构变体，不增加第
15 条 canonical route。Ubuntu sysroot 与 Zig 锁定信息位于
`checks/toolchains/linux-riscv64.json`：

```sh
bash scripts/prepare-linux-riscv64-sysroot.sh \
  --output .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64
bash scripts/linux-riscv64-cross-build.sh \
  --sysroot .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64 \
  --target-dir _build/riscv64-linux-gnu \
  --log-dir artifacts/linux-riscv64 \
  --run-qemu
```

L0 要求 Showcase ELF 报告包含 ELF64、RISC-V 与 LP64D glibc
interpreter。L2 要求 renderer、async image second frame、text/emoji 和真实
SkParagraph marker。QEMU 证据仅属于 renderer，不能提升 Linux Wayland L3。
无需 sysroot 的 metadata/schema 与负向 helper 检查为：

```sh
node scripts/validate-platform-matrix.mjs
moon test tools/moui/validate_platform_matrix --target native
bash scripts/test-linux-riscv64-cross-build.sh
```

`.github/workflows/moui-linux-riscv64-cross-build.yml` 是 scheduled/manual
producer，上传 sysroot 包版本与 checksum manifest、Release build log、ELF
报告与 checksum，以及两类 QEMU smoke 日志。

`external-consumer.yml` workflow 会把选定的 base、Skia 或 Web fixture 复制到 checkout 外部。0.2 发布前，registry mode 继续验证稳定版 `wzzc-dev/moui@0.1.7` 的 base profile；package mode 验证 0.2 head 的 base-only、Skia 与 Web archives。package-mode `moon tree` 还会拒绝 concrete renderer 与诊断/测试依赖进入基础闭包。所有解析后的 `.mooncakes` 路径都必须报告 `monorepoSource=false`：

```sh
node scripts/external-consumer-ci.mjs --source registry --profile base
node scripts/external-consumer-ci.mjs --source package --profile base
node scripts/external-consumer-ci.mjs --source package --profile skia
node scripts/external-consumer-ci.mjs --source package --profile web
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
moon test moui_skia_renderer --target native
moon test moui_web_renderer --target wasm-gc
moon test moui/backend --target native
moon test moui/backend/android --target native
moon test moui_skia_renderer --target native
moon test moui/backend/ios --target native
moon test moui_skia_renderer --target native
moon test moui/backend/harmonyos --target native
moon test moui_skia_renderer --target native
moon test moui/backend/web --target wasm-gc
moon test moui_tests/tester --target native
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
moon check examples/showcase/android_window_hosted --target native
moon check examples/showcase/ios_window_hosted --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/harmonyos_window_hosted --target native
sh scripts/window-hosted-hostsim-smoke.sh
```

仅对 native WGPU 诊断路线使用 `moon test moui_wgpu_renderer --target native`。交接前使用 `moon fmt`。公开 API 变更后运行 `moon info` 并审查 `pkg.generated.mbti` diff。

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

### 嵌入运行时后端

Android、iOS 和 HarmonyOS 都将公开 `HostCmd` 立即解码为
`wzzc-dev/window/internal/embedded_dispatch` 的物理 dispatch command。该包只维护
native FIFO 与当前 raw surface 投影，并按序触发 `ApplicationHandler` callback；逻辑
lifecycle phase、surface generation、primary window、detach 和 exit intent 唯一归
`moui/backend/common/lifecycle` 中的 `EmbeddedLifecycle`。进入 MoUI 后，
`EmbeddedSession` 组合 `frame`、`image`、`input`、`services` owner 与 renderer、
IME、semantics、platform views、transport 能力，不复制 phase 或 frame loop。
中立 `HostService*` 合约仍唯一位于 `moui/backend`；原生文件服务位于
`common/services/native`，桌面同步实现位于 `common/services/desktop`，移动端
`Pending(id)` callback queue 位于 `common/services/embedded`，filesystem image
source 位于 `common/image/native`。
更改嵌入运行时 template、entrypoint、dispatch 或 backend 后，运行可移植的 host-sim gate：

```sh
sh scripts/window-hosted-hostsim-smoke.sh
```

它覆盖三个 window host simulator、MoUI backend packages 和 Counter 嵌入运行时
entrypoints。它每晚在 CI 的 `moui-runtime-gates.yml` `window-hosted-hostsim`
job 中运行（运行时启用 dev mode、运行后关闭，因此检查永远不会留下可编辑的
`window` workspace）。`--fallback-skia` 构建只是 packaging-only diagnostic，不能建立
presenter 或 runtime claim。

对于已连接的 matching target，一次 build/run 一个平台，然后记录生成的
window-hosted verification manifest：

```sh
moui run android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json" --device <adb-serial>
moui verify android showcase --device <adb-serial> --require-passed
```

iOS 或 HarmonyOS target 使用相应命令。通过的 claim 需要观察到 presentation、input、
surface detach/recreate、IME、clipboard、accessibility 和 async-image behavior。GPU
seven-gate quality claim 仍与 runtime readiness 分开。

VM facade 总会先运行 host-sim。只启用一个可选 device leg：

```sh
WINDOW_HOSTED_ANDROID_AVD=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_IOS_SIM=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_HARMONYOS_HVD=1 sh scripts/window-hosted-vm-smoke.sh
```

`smoke/gates.json` 是 checked-in smoke gate catalog。它描述 daily、nightly 和 release smoke tier、每个 suite command、结构化 result shape、owning workflow，以及解释门禁的文档。无需运行 platform smoke 即可验证它：

```sh
node --check scripts/smoke-check.mjs
node scripts/smoke-check.mjs --check
node scripts/smoke-check.mjs --tier nightly --list
node scripts/smoke-check.mjs --tier release --json
node scripts/smoke-gate.mjs --suite web.runtime-presentation --run
```

catalog check 是 daily profile 的一部分；真实 browser/platform smoke 仍为 opt-in。`scripts/smoke-gate.mjs` 是从 catalog 中选择 suite 的统一 runner；默认 dry-run，并且在运行标记为 manual 的 command 前要求 `--allow-manual`。scheduled/manual `.github/workflows/moui-runtime-gates.yml` workflow 是 Web runtime presentation nightly smoke 和手动 macOS real Skia release smoke 的 CI 入口点。

Web script 构建 Showcase、服务仓库、在 `artifacts/smoke/web-runtime-presentation/` 下记录 Chrome/CDP browser-session manifest，并用 `validate-web-runtime-presentation-manifest.mjs` 验证它。请把结果视为该 browser session 的手动 smoke log。

Native Skia smoke log 可以显示 renderer pixels、async image second-frame behavior、可选 SkParagraph text behavior，以及 tester-owned first-frame 或 IME observation。它们是直接 pass/fail runtime log，不是 repository manifest gate。

Linux Skia first-frame evidence 请使用匹配的 Wayland host，并保持 Showcase 和 window-package smoke log 分离：

```sh
MOUI_FIRST_FRAME_EXIT=1 \
  moon run examples/showcase/linux_skia --target native
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
