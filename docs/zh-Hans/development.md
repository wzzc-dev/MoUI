# 开发

本页是本地 setup、workspace shape、documentation sync、app iteration 和 validation 的根维护者指南。面向产品的网站文档由 `scripts/sync-website-docs.mjs` 从这个 `docs/` 目录生成。

## 本地 setup

MoonBit 包生态变化很快。如果依赖相关 build 失败，先运行 `moon update`，检查已解析的 package version，并在修改 MoUI 代码前确认失败是否来自 registry/cache/dependency 问题。

## 工作区成员

`moon.work` 是 workspace membership 的 source of truth。生成的 [Repository facts](../repository-facts.md#workspace-members) 页面列出每个成员，并将 workspace examples 与 `examples/catalog.json` 合并。新增或移除 example 时，更新 catalog 以及 `docs/examples.md` 中对应的 descriptive entry；不要把完整 workspace list 复制到手写 docs。

## 应用迭代

MoonBit-native Playground 位于 `website/playground`。它的可见 editor 是一个 `moui_richtext` 控件；小型 JavaScript host 只限于浏览器 Worker、iframe 和 Wasm APIs。用以下命令 build 和 stage：

```sh
moon test website/playground/app --target native
moon build website/playground/web_wasm --target wasm-gc
node scripts/generate-playground-assets.mjs --out dist/playground
```

保持 `website/tutorial/lessons` 下的课程源码可 compile-check。asset generator 会把这些源码、app-safe dependency manifest 以及 pinned `@moonbit/moonc-worker` asset 复制到静态 Playground 输出中。

共享应用逻辑属于 `examples/<name>/app`。平台入口应保持很薄，并放在 `web_wasm`、`macos_skia`、`windows_skia` 或 `linux_skia` 等名称下。Showcase 对桌面和移动端也遵循同一约定（`android_window_hosted`、`ios_window_hosted`、`harmonyos_window_hosted`），而它的 WGPU 和 Sun 目录保持为显式 diagnostic renderer routes。

使用最小有用循环：

```sh
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/web-bundle-size.mjs examples/counter/web_wasm --json
```

Android、iOS 和 HarmonyOS 使用嵌入运行时后端路线。匹配的
`wzzc-dev/window` template 负责 native lifecycle、surface creation 和 input；MoUI
`*_window_hosted` 入口提供 program 和 Skia provider。不再有应用专用 native export
table 或第二套 lifecycle bridge。

在调用平台 toolchain 之前使用 host-sim 检查：

```sh
moon check examples/showcase/android_window_hosted --target native
moon check examples/showcase/ios_window_hosted --target native
moon check examples/showcase/harmonyos_window_hosted --target native
sh scripts/window-hosted-hostsim-smoke.sh
```

通过 `moui_cli` 从应用元数据构建：

```sh
moui build android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui build ios showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui build harmonyos showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
```

`--fallback-skia` 只能用于打包诊断；要提出运行时声明，仍需要匹配的设备或模拟器证据。
平台专用 SDK 设置和证据边界见 [Android](../android-support.md)、
[iOS](../ios-support.md) 和 [HarmonyOS](../harmonyos-support.md)。

`moon update` 会刷新 registry packages，包括 `window` fork package。默认 `sh scripts/check.sh --profile daily` 路径守护 dependency shape 和 repo-local `moui_skia` acceptance surface。Skia binding 是主 checkout 的一部分，位于 `moui_skia`。

这会让基础 `moui/moon.mod` 只保留 `wzzc-dev/window`，而
`moui_skia_renderer/moon.mod` 显式声明 `wzzc-dev/moui` 与
`wzzc-dev/moui_skia` binding。`wzzc-dev/moui_theme` 仍是 addon module，
local workspace members 从 `moon.work` 解析。确切列表会生成到
[Repository facts](../repository-facts.md#workspace-members)。

```moonbit
import {
  "wzzc-dev/window@0.5.4-0.1.7",
  "wzzc-dev/moui@0.1.12",
  "wzzc-dev/moui_skia@0.1.10",
}
```

MoonBit 包生态仍不如更老的语言生态成熟。失败的 build 可能来自 registry cache state、package publication mistakes 或 dependency regressions，也可能来自 MoUI 代码。当 dependency-related failures 出现时，先运行 `moon update`，检查 resolved package versions，并确认 `wzzc-dev/window@0.5.4-0.1.7` 或其他包是否改变了行为。

`window` package 仍携带 MoUI smoke helpers 和 evidence docs。使用
`scripts/run-window-package-smoke.sh <platform>` 将已解析的 registry package 解包到临时目录，并在不创建本地 checkout 的情况下运行这些 helpers。例如在 macOS 上：

```sh
WINDOW_MOUI_MACOS_SMOKE_LOG_PATH=artifacts/platform-evidence/macos/window-macos-runtime-smoke.log \
  scripts/run-window-package-smoke.sh macos --run
```

Skia binding 可在主仓库的 `moui_skia` 中编辑。默认 daily check 会验证 fallback-safe Skia package tests（`moon test moui_skia --target native`）和 binding workspace 的 platform status contract。binding workspace 自带
`moui_skia/scripts/verify-platform-status.sh` 和
`moui_skia/scripts/verify-native-capability-contract.sh`，它们要求
`skia-platform-status.json`、`skia-provider-lock.json`、
`SKIA_PLATFORM_STATUS.md`、`native/capabilities.json` 和 `native/ownership.json`，用于证明 editable binding workspace 仍有 pinned real Skia artifact/status contract、CI evidence wiring、fallback parity、FFI ownership/borrow coverage 和 native smoke marker coverage。这不能证明 MoUI platform entrypoint 已经用 real Skia 渲染；要获得 renderer-level proof，请在配置 real Skia native link flags 后使用
`scripts/macos-skia-renderer-smoke.sh`。
binding/provider GitHub Actions workflows 维护在仓库根 `.github/workflows/moui-skia-*.yml`；如果 `moui_skia` 变成独立仓库，这些 workflows 预期随它移动。根
`.github/workflows/moui-renderer-real-skia-ci.yml` workflow 仍由 MoUI 拥有，因为它证明 framework renderer integration against Skia binding，而 `.github/workflows/copilot-setup-steps.yml` 会从 `moui_skia` workspace 为 GitHub Copilot coding agent runs 设置 MoonBit。保持 workflow files 在根 `.github/workflows` 目录，使 GitHub 能在此 monorepo 布局中发现它们。

GitHub Actions 通过 repository-local `.github/actions/setup-moonbit` action 安装 MoonBit。pinned compiler version 位于根 `.moonbit-toolchain` 文件；将 CI 移到新的 MoonBit toolchain version 时更新该文件，而不是在每个 workflow 中硬编码 installer arguments。

更新此仓库时，更新所有参与 workspace 的 Git checkouts，而不只是 root checkout。这包括主 MoUI 仓库和 `.agents/skills/moonbit-skills`、`window` 等 Git submodules。然后运行 `moon update` 刷新 registry dependencies。`moui_skia` 随主 MoUI checkout 更新。

新 clone 时，在初始 checkout 中获取 submodules：

```sh
git clone --recurse-submodules git@github.com:wzzc-dev/MoUI.git
```

如果仓库 clone 时未带 submodules，初始化一次：

```sh
git submodule update --init --recursive
```

### Window Submodule 与本地源码模式

根 README 有意不把此 workflow 放进 quick start。普通 MoUI builds 不需要本地 `window/` checkout。

`window` submodule 的两个模块默认**不是** `moon.work` workspace member。MoonBit 会从 mooncakes.io 解析 `wzzc-dev/window`（每个 consumer 的 `moon.mod` 中 pinned 的 published version）。`window/` submodule checkout 只用于开发者需要编辑 window source 并在发布前于 MoUI 内验证变更时切换到 local-source dev mode。

要本地编辑 window source：

```sh
sh scripts/window-dev-mode.sh on      # add both nested window modules (local override)
# edit window/ source; moon test/run picks up changes immediately
sh scripts/window-dev-mode.sh off     # remove ./window; resolve from mooncakes.io
```

`scripts/validate-window-dependency.mjs`（由 `check.sh --profile daily` 和 CI 运行）会在 `moon.work` 列出任一嵌套 window 模块时失败。只有编辑 window 源码时才运行 `sh scripts/window-dev-mode.sh on`，完成后关闭 dev mode 再执行正常校验。发布新 window 版本后，更新 `moui/moon.mod`、`moui_skia/moon.mod`、`moui_webview/moon.mod` 和 `examples/markdown_editor/moon.mod` 中的 pinned version，然后运行 `moon update` 刷新 registry cache。

在 Windows 上，使用 repository update helper：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

`moui_skia` workspace member 由 root repository pull 更新；window dependency 从 mooncakes.io 解析（或在 dev mode 打开时从 `window` submodule checkout 解析）。

Mo Workbench 依赖 `bobzhang/openseek`，现在从 mooncakes.io 解析（pinned 在 `examples/mo_workbench/moon.mod` 中，例如 `bobzhang/openseek@0.2.2`）。不需要 git submodule 或 `./openseek` workspace member。新 openseek release 发布后，运行 `moon update` 刷新 resolved registry version。如果开发期间需要本地 `bobzhang/openseek` checkout，请使用 mooncakes 自身 local override 机制，而不是把 `./openseek` 加入 `moon.work`。运行 Mo Workbench native：

```sh
export OPENAI_API_KEY=...   # or DEEPSEEK=...
export OPENAI_BASE_URL=...  # optional OpenAI-compatible API URL
moon run examples/mo_workbench/macos_skia --target native
```

## 验证

日常本地开发优先使用有界 daily check：

```sh
sh scripts/check.sh --profile daily
```

详细 daily gate membership、focused package checks、maintenance ratchets 和 addon diagnostic variants 位于 [testing.md](../testing.md)。release gate evidence、provenance 和 smoke catalog policy 使用 [release-readiness.md](../release-readiness.md)。

## 脚本工具策略

保持 scripts 首先简单、清晰、可维护。当两种方案同样清晰时，优先用 MoonBit 编写 repository rules、static validation、structure scans、deterministic generators，以及任何能受益于 `moon check`/`moon test` 覆盖的逻辑。

长期维护的 CI tools 使用 `tools/...` MoonBit packages。当用户或 CI 已经调用 `node scripts/*.mjs` 时，保留 checked-in Node entrypoints 作为 `scripts/lib/moonbit-tool-runner.mjs` 上的 compatibility wrappers。`.mbtx` 只用于短小 standalone developer scripts；一旦它成为维护 gate，就提升为 `tools/...` package。

Node 保留给 browser/CDP、Web smoke capture、HTTP/GitHub artifact work、npm ecosystem tools，以及用 JavaScript 更清晰的 command execution。sh/PowerShell 保持为 environment variables、shell syntax、platform setup 和 OS-specific command dispatch 的薄 orchestration。Windows MSVC、vcpkg 和 zlib setup 保持在 `scripts/windows/setup_msvc_deps.ps1`、`scripts/windows/msvc_env.ps1` 等 PowerShell helpers 中；MoonBit 可以验证这些流程周边的 manifests 或 guidance，但不应安装 machine tools。

只将 `rule`/`dev_build` 用于 deterministic package build inputs：一个声明的 input 在 package build 前创建一个声明的 output。不要用 `rule`/`dev_build` 安装 MSVC、vcpkg、zlib、Chrome、CI runners 或其他 machine environment dependencies；不要用它运行 smoke tests、访问网络或修改 global/user state。

只在配置本地 Skia link flags 后运行 real Skia native smoke：

```sh
scripts/macos-skia-renderer-smoke.sh
```

该 opt-in check 同时运行 `moui_skia` native binding smoke 和 MoUI 的 renderer-level smoke（`moui_tests/skia_renderer_smoke/native`），后者通过 `moui_skia_renderer` 渲染一个小 `DrawCommand` frame 并验证 presenter pixels。renderer smoke 包括有界 `TextRun.frame` text clipping 和通用 glyph-run text pixel check。
脚本会 build 这些 smoke packages 并直接运行生成的 native executables，使失败通过进程 exit status 传播。

在 macOS 上，如果希望脚本为你解析 Skia 并接线临时 package link flags，请使用专用 helper。默认它使用来自 `moui_skia` 的 pinned JetBrains Skia binary provider：

```sh
scripts/macos-skia-renderer-smoke.sh
```

仓库默认 package files 有意避免 machine-local Skia paths。直接本地命令使用 `moui_skia` prebuild hook 在 build time 解析 pinned release provider 和 link mode：

```sh
export MOUI_SKIA_LINK_MODE=dynamic
moon run examples/showcase/macos_skia --target native
moon run examples/mo_workbench/macos_skia --target native
```

直接 `moon run`/`moon build` 命令使用 `MOUI_SKIA_LINK_MODE=dynamic|static|auto`。`--link-mode dynamic|static|auto` script option 仍可用于 helper-driven smoke runs，并会覆盖本次调用的 environment。在 `auto` 中，当 helper 构建 app entrypoint 时会使用 shared provider artifact，因为 split static Skia archives 在 transitive app link boundary 上对顺序敏感；带 `--skip-showcase-build` 的 renderer-only smoke 继续使用 static artifact。
Skia/Metal link flags 由 `moui_skia` prebuild 注入（`${build.MOUI_SKIA_CC_LINK_FLAGS}`）；不要把 machine-local absolute paths 写入 example `moon.pkg` 文件。

当所选 Skia library directory 包含 SkShaper module libraries 时传入 `--enable-skshaper`。helper 随后会用 SkShaper define 配置 `moui_skia/native`，链接 `libskshaper`、`libskunicode_core`、`libskunicode_icu`、`libharfbuzz` 和 `libicu`，并验证 MoUI renderer smoke log 证明 optional shaped-run path 可用。

当你希望 helper 启动已构建的 `examples/showcase/macos_skia` executable、等待首个 Skia-presented frame、然后自动退出时，添加 `--run-showcase-smoke`。添加 `--run-markdown-smoke` 对 `examples/markdown_editor/macos_skia` 执行同样操作：

```sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

renderer smoke 和普通 macOS Skia app entrypoints 使用默认 system-FontMgr text path，包括启用时的 optional SkShaper。first-frame Showcase 和 Markdown Editor smokes 设置各自 entrypoint 的 exit-after-first-present flag，并且这些 entrypoints 仅在 smoke run 中显式选择 `EmptyTypeface`。这让 first-frame AppKit presentation evidence 保持在更安全的 default-font retry path 上，同时保留正常 app default，使其继续 exercise platform font lookup、emoji retry 和链接时的 optional SkShaper。

当你已有 Skia checkout 或 binary package 时使用 `--skia-provider existing`：

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

使用 `--skia-provider source` 可在运行同一个 MoUI renderer smoke 前，通过
`moui_skia/scripts/macos-build-skia.sh` 构建小型 CPU Skia library：

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider source \
  --work-dir .skia-cache/macos
```

它会临时配置 `moui_skia/native`、`moui_tests/skia_renderer_smoke/native`、`examples/showcase/macos_skia`、`examples/markdown_editor/macos_skia` 和
`examples/mo_workbench/macos_skia`，运行 MoUI renderer pixel smoke，构建 macOS Skia Showcase entrypoint，并在退出前恢复所有 touched `moon.pkg` files。

## 预览循环

迭代 Showcase 或另一个 Web wasm-gc example 时使用轻量预览循环：

```sh
sh scripts/preview-loop.sh
sh scripts/preview-loop.sh --watch
sh scripts/preview-loop.sh --package examples/counter/web_wasm --watch
sh scripts/preview-loop.sh --package examples/markdown_editor/web_wasm --watch
sh scripts/preview-loop.sh --package website/web_wasm --watch
```

预览 website 时，先运行 `node scripts/sync-website-docs.mjs`，或对 `website/web_wasm` 使用 preview loop；website 会从 `website/web_wasm/docs/` fetch same-origin Markdown files。

对于 release-style Web output，使用 package helper，而不是直接 serve debug `_build` tree：

```sh
node scripts/package-web-app.mjs examples/counter/web_wasm --out artifacts/web/counter
```

helper 使用 `--release --strip` build，复制 `index.html`、app wasm、MoUI Web runtime JS 和 package-local `assets/`，然后写入 `.gz`/`.br` siblings 以及 `bundle-size.json`。大图片、长 Markdown、大 JSON 和 fixtures 应放在 Web entrypoint 的 `assets/` 目录下，并用 `assets/story/buttons.json` 等 relative URLs 引用。Text/Markdown/JSON resources 应通过 Web host 的 same-origin text-file service 加载；image sources 应保持为 URL strings，使 renderer 能在 wasm module 外加载它们。

## 框架迭代

编辑 internals 时使用聚焦 package tests：

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/runtime --target native
moon test moui/backend --target native
moon test moui/render --target native
moon test moui_skia_renderer --target native
moon test moui_web_renderer --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test moui_skia --target native
```

引入新的 public names 前使用 `moon ide doc`、`moon ide outline`、`moon ide peek-def` 和 `moon ide find-references`。尽量让 edits 保持 package-local。如果 public API 变化，运行 `moon info` 并审查 `pkg.generated.mbti` diff。

## 文档同步

根 `docs/` 是 maintainer 和 website Markdown pages 的来源。
`website/web_wasm/docs/` 是 website app 消费的本地预览副本。

编辑 docs 后：

```sh
node scripts/sync-website-docs.mjs
node scripts/check-website-docs.mjs
```

sync 命令刷新被忽略的本地预览副本。check 命令会生成并验证隔离的临时副本，因此干净 checkout 中不要求存在 `website/web_wasm/docs/`。

GitHub Pages 会在站点根目录打包 `website/web_wasm`，并用
`scripts/package-web-app.mjs` 将 Showcase 和 Markdown Editor Web 入口分别放到
`/showcase/` 和 `/markdown-editor/`，用
`node scripts/package-website-playground.mjs --out dist/pages/playground` 嵌入 Playground，然后用
`node scripts/sync-website-docs.mjs --out dist/pages/docs` stage docs。本地同一布局是一条命令：

```sh
sh scripts/package-website-site.sh
# optional: --out dist/pages --skip-docs --skip-playground --no-verify
cd dist/pages && python3 -m http.server 8080 --bind 127.0.0.1
```

保持 root docs 不含 machine-local paths 和生成的 `artifacts/` evidence。

## Daily Validation

日常交付运行 daily validation script：

```sh
sh scripts/check.sh --profile daily
```

此节只保留入口。完整 daily command inventory、focused checks、addon diagnostics、WGPU diagnostic route 和 current-host backend variants 维护在 [testing.md](../testing.md)。

## 真实 Renderer 与平台 Smoke

真实 browser、renderer 和 platform smoke runs 是 opt-in，因为它们需要匹配 hosts、已配置 renderer dependencies 或 browser/runtime evidence。smoke command catalog 使用 [testing.md](../testing.md#smoke)，release evidence 和 provenance policy 使用 [release-readiness.md](../release-readiness.md)。Smoke commands 会把 logs 和 manifests 写入 `artifacts/`；不要提交 artifacts，并在 release notes 中引用 CI run、uploaded artifact 或 local smoke log。

## CI 与工具链

GitHub Actions 通过 `.github/actions/setup-moonbit` 安装 MoonBit。pinned compiler version 位于 `.moonbit-toolchain`；将 CI 移到新的 MoonBit toolchain version 时更新该文件。当前 pin 是 MoonBit `0.10.4`（`moonc v0.10.4+ade96c819`）。

MoonBit 0.10.4 会将裸 `{}` 视为 empty maps / JSON objects / blocks 的歧义写法。在使用位置优先写 `Map([])`、`Json::empty_object()` 或 `{ () }`。`assert_eq` 和相关 debug helpers 现在要求 `Debug` 而不是 `Show`。

`ci.yml` 通过 checked wrappers 表达 routine gates：PR profile gate 运行 `sh scripts/check.sh --profile pr`，Linux platform contracts 运行 `sh scripts/check.sh --profile platform`。Windows MSVC job 有意把 setup、backend/provider tests 和 packaging 保持为显式 PowerShell steps；它只添加一个 wrapper contract check：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Pr -DryRun -Json -SkipSubmoduleInit
```

`moui_skia` 的 binding workflows 位于根 `.github/workflows/`，使用
`moui-skia-*` 前缀，使 GitHub 能在此 monorepo 布局中发现它们。不要把 workflow files 移入 sub-workspace `.github/workflows` directories。MoUI-owned renderer/platform workflows，例如
`moui-renderer-real-skia-ci.yml` 和 `moui-macos-app-real-skia-manual.yml`，保持 `moui-*` 前缀，而不是 package-owned `moui-skia-*` 前缀。

在 Windows 上，刷新本地 checkouts 时使用 repository update helper：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

在 Windows 上，daily checks 使用 native PowerShell entry point（不需要 MSYS）。它会在首次运行时初始化 `window` submodule，并运行与 `scripts/check.sh --profile daily` 相同的 bounded mainline package checks：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Daily
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Platform
```

或者，在 Git Bash 下运行 shell 版本：

```sh
sh scripts/check.sh --profile platform
```

`moon build examples/showcase/macos_skia --target native` 或
`moon build examples/showcase/linux_skia --target native` 等 native platform example builds 会链接 platform stubs 和 native renderer libraries，因此 cold builds 可能很慢。只在验证当前 host platform 的 executable examples 时包含它们：

```sh
sh scripts/check.sh --profile full
```

## Native Packaging Helpers

packaging helpers 会把已支持的 native example packages 包装成 platform-shaped output directories。它们有意只是 `moon build` 的薄 wrappers，不替代 release signing、notarization、installers 或 store packaging。

macOS `.app` bundle：

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos_skia \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0 \
  --build-version 1
```

bundle 默认写入 `dist/macos/<name>.app`。传入 `--no-build` 可从 `_build/native` 打包已经 build 的 executable。bundle 包含 `Contents/Resources/moui-package.json`，使用 schema version 1，记录 platform、output kind、app name、source MoonBit package、bundle id、version、build number、executable、bundle name 和 runtime file metadata。helper 会在报告成功前验证该 manifest。

Windows native 使用 Visual Studio C++ build tools 和 vcpkg `zlib:x64-windows`。build/package helpers 是 renderer-aware：native Skia packages 保持在 Skia route，不下载或 bundle `wgpu_native.dll`；而显式 WGPU diagnostic packages 保留 MSVC dynamic WGPU setup。先 build 一次 entrypoint，再 package portable folder：

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -AppName MoUIShowcase `
  -Version 0.1.0 `
  -BuildNumber 1
```

helper 导入 `vcvarsall.bat`，将 `CC` 和 `CXX` 设为 `cl.exe`，为 native stubs 应用共享 MSVC `CL`/`LINK` flags，并使用 vcpkg `zlib:x64-windows`。当 package 导入 WGPU 时，它还会设置 `MBT_WGPU_LINK_MODE=dynamic`，并在未提供 `-WgpuNativeRoot` 时提取官方 `wgpu-windows-x86_64-msvc-release.zip` release。其文件夹写入 `dist\windows-msvc\<AppName>`，并包含 `run.cmd`、schema manifest 和所选 renderer 需要的 runtime DLLs。Skia packages 省略 `wgpu_native.dll`；WGPU packages 包含 WGPU release metadata，并通过 `run.cmd` 设置 `MBT_WGPU_NATIVE_ROOT`。
如果 Visual Studio bundled vcpkg 报告 classic mode unavailable，请从 repository root 使用 `setup_msvc_deps.ps1 -InstallZlib`；该脚本会在 `.tools\vcpkg-msvc` 下创建一个小型 ignored manifest workspace，并使用 manifest mode 安装 `zlib:x64-windows`。

setup 后直接运行 Showcase Skia mainline 时，在同一个 PowerShell 进程中 dot-source MSVC environment：

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
```

仅为显式 native WGPU diagnostics 使用 `windows_wgpu` entrypoint：

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_wgpu --target native }"
```

手动 manifest validation：

```sh
node scripts/validate-package-manifest.mjs \
  "dist/macos/MoUI Showcase.app/Contents/Resources/moui-package.json" \
  --platform macos
```

有用的聚焦命令：

```sh
moon test moui_wgpu_renderer --target native
moon test moui_skia_renderer --target native
moon test moui_sun_renderer --target native
moon test moui_skia --target native
sh scripts/check.sh --profile theme
moon test moui_sun/graphics --target native
moon test moui_sun/text --target native
moon test moui_sun/renderer --target native
moon test moui_sun/softbuffer --target native
moon build moui_tests/skia_renderer_smoke/native --target native
moon test moui_web_renderer --target wasm-gc
moon test moui_tests/tooling --target native
moon test moui/backend/web --target wasm-gc
node scripts/validate-renderer-provider-manifests.mjs
sh scripts/check.sh --profile platform
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_service_native_transport --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/package-web-app.mjs examples/counter/web_wasm --out artifacts/web/counter
sh scripts/check.sh --profile full
moon build examples/showcase/macos_skia --target native
moon build examples/design_systems/macos_skia --target native
moon build examples/showcase/windows_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/showcase/macos_sun --target native
moon build examples/showcase/windows_sun --target native
moon build examples/showcase/linux_skia --target native
moon build examples/showcase/linux_sun --target native
```

PDF Workbench app-only 和 `pdflite_adapter` checks 默认不再下载 PDFium。仅在验证 native PDFium raster adapter 时设置 `MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1`，或提供 `MOUI_PDFIUM_INCLUDE` 加 `MOUI_PDFIUM_LIB_DIR` 来使用本地 PDFium install，而不下载锁定 prebuild。

只在匹配且已配置的 host 上使用 direct native example builds。check profiles 会把 shared platform service checks、current-host backend/provider checks 和 slow native example builds 分开。仅在显式验证实验性 WGPU diagnostic route 时运行 native WGPU 和 Cosmic text-provider entrypoint builds。

## Mooncakes 集成说明

MoUI 在使用 Mooncakes frontends 和 tooling 时保持 production runtime boundaries 显式：

- Layout 保持平台无关，但具体 flex/grid/list/stack placement 现在由 `moui/views` 中的 concrete `ViewNode` 实现，并通过 `View::from_node` 构造；`core/` 不应为单个 controls 增长 layout-engine dependencies。
- `Milky2018/moon_accesskit` 是 `backend` 使用的 native accessibility tree representation；`@core.SemanticsNode` 保持平台无关，Web 继续使用其 ARIA adapter。
- `Milky2018/moon_zeno` 驱动 renderer path tessellation，将 MoUI
  `DrawPath` / `PathSpec` values 转换为 triangle meshes。SVG parsing 仍是 importer frontend 的职责。
- `mizchi/markdown` 驱动 Markdown Editor 的 package-local parser adapter 和 rich text mapping。app-level editing model 见 [Markdown Editor](../markdown-editor.md)。
- `mizchi/svg` 驱动 `render.import_svg(String) -> SvgImportResult`，将 parsed SVG scene graph nodes lowering 为 MoUI `DrawCommand` 值。
- `moonbitlang/quickcheck` 和 `mizchi/pixelmatch` 从 `moui_tests/tooling/` 中使用，用于 property 和 pixel-diff coverage。

text stack 有自己的维护页面，因为它横跨 `core`、native Skia、diagnostic `moui_wgpu_renderer` providers 和 browser host assets。更改 `TextSystem`、native text providers、embedded font registration 或 Web text measurement 前见 [Text system](../text-system.md)。

## Guidance Maintenance

当 development change 影响 package layout、docs placement、validation commands、platform setup、renderer capability status、example structure 或 text system 时，也检查 `AGENTS.md` 和 `skills/` 下的 repo-local skills。当它们的说明否则会过期时，在同一变更中更新它们。
