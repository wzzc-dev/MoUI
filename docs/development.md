# Development

This page is the root maintainer guide for local setup, workspace shape,
documentation sync, app iteration, and validation. Product-facing website docs
are generated from this `docs/` directory by `scripts/sync-website-docs.mjs`.

## Local Setup

The MoonBit package ecosystem moves quickly. If a dependency-related build
fails, first run `moon update`, inspect the resolved package version, and check
whether the failure is a registry/cache/dependency issue before changing MoUI
code.

## Workspace Members

`moon.work` is the source of truth for workspace membership. The generated
[Repository facts](repository-facts.md#workspace-members) page lists every
member and combines workspace examples with `examples/catalog.json`. When
adding or removing an example, update the catalog and its descriptive entry in
`docs/examples.md`; do not copy the full workspace list into hand-written docs.

## App Iteration

The MoonBit-native Playground lives under `website/playground`. Its visible
editor is a `moui_richtext` control; the small JavaScript host is limited to
browser Worker, iframe, and Wasm APIs. Build and stage it with:

```sh
moon test website/playground/app --target native
moon build website/playground/web_wasm --target wasm-gc
node scripts/generate-playground-assets.mjs --out dist/playground
```

Keep course sources under `website/tutorial/lessons` compile-checkable. The
asset generator copies those sources, the app-safe dependency manifest, and
the pinned `@moonbit/moonc-worker` asset into the static Playground output.

Shared app logic belongs in `examples/<name>/app`. Platform entrypoints should
stay thin and live under names such as `web_wasm`, `macos_skia`,
`windows_skia`, or `linux_skia`. `examples/component_gallery` intentionally uses
`macos`, `linux`, `windows`, `android`, `ios`, `harmonyos`, and `web`; the
Skia-backed entries omit `_skia` because Skia is the default renderer route for
Component Gallery.

Use the smallest useful loop:

```sh
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/web-bundle-size.mjs examples/counter/web_wasm --json
```

Android is currently an embedded native scaffold rather than a full app-owned
event loop. For Android Skia cross-build checks, set
`MOUI_SKIA_PLATFORM=android` and an explicit `MOUI_SKIA_ARCH` so the prebuild
selects the locked Android Skia artifact instead of the desktop host artifact:

```sh
MOUI_SKIA_PLATFORM=android MOUI_SKIA_ARCH=arm64 \
  moon check examples/counter/android_skia --target native
```

To build the experimental Counter Android debug APK, first install Android SDK
Platform 36, Build-Tools 35.0.0, Platform-Tools, NDK, and CMake through Android
Studio's SDK Manager, the official `sdkmanager` command-line tools, or the
repository helper. See
[android-support.md](android-support.md#android-sdk-and-ndk) for the full setup
flow. Make sure a complete JDK is installed first so `java`, `javac`, `jlink`,
and `keytool` are available. The managed shell targets SDK 35 but compiles
against SDK 36 because AndroidX Activity 1.13.0 requires it. Use Java 17 or
newer for Android Gradle Plugin 9.x; Java 21 is the recommended local default.
The shortest path is:

```sh
scripts/setup-android-sdk.sh --accept-licenses
eval "$(scripts/setup-android-sdk.sh --print-env)"
scripts/build-mobile-android-apk.sh --app counter
```

If you already have an Android SDK installed, point `ANDROID_HOME` at that SDK
root and run:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-mobile-android-apk.sh --app counter
```

Set `ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/<version>` only when you need to
pin a specific side-by-side NDK; otherwise the script uses the latest NDK under
`$ANDROID_HOME/ndk`.

For a packaging-only smoke that avoids the Android Skia provider download, use
`scripts/build-counter-android-apk.sh --fallback-skia`. That compatibility
wrapper calls `scripts/build-mobile-android-apk.sh --app counter`. The APK proves the
MoonBit C/JNI/CMake/SDK packaging path only; real Android runtime evidence still
requires a device or emulator run with the default real-Skia path.

Mobile app registration is split by publish boundary. Repository examples edit
`examples/<app>/mobile.json` and use compatibility defaults in
`moui/mobile/build-contracts.json`; external apps should keep the native
contract directly in their own `mobile.json`. The reusable mobile templates and
build entrypoints live under `moui/mobile` and `moui/scripts/mobile` so they
are available after publishing the `wzzc-dev/moui` package. Run
`node scripts/check-mobile-app-config.mjs` for a fast repository example
registration consistency check before attempting a full APK, `.app`, or HAP
build.

See [android-support.md](android-support.md) for the Activity/Surface ownership
boundary and runtime-evidence requirements.

iOS is also an embedded native scaffold rather than a full app-owned event
loop. For iOS Simulator Skia cross-build checks, set `MOUI_SKIA_PLATFORM=iosSim`
and an explicit `MOUI_SKIA_ARCH` so the prebuild selects the locked simulator
artifact instead of the desktop host artifact:

```sh
MOUI_SKIA_PLATFORM=iosSim MOUI_SKIA_ARCH=arm64 \
  moon check examples/counter/ios_skia --target native
```

To build the experimental Counter iOS Simulator app, install/select Xcode and
run:

```sh
scripts/build-mobile-ios-app.sh --app counter
```

The default output is `artifacts/ios/counter/MoUICounter.app`. Use
`scripts/build-counter-ios-app.sh --fallback-skia` for a packaging-only smoke
that avoids the iOS Skia provider download. That `.app` proves the MoonBit
C/canonical SwiftUI shell/ABI bridge/native-stub/bundle path only; real iOS
runtime evidence still requires a simulator or device run with the default
real-Skia path. Xcode 15.4+, Swift 5 language mode, and iOS 15+ are required.
Use `--legacy-uikit-shell` only for the frozen Release N compatibility fixture.

See [ios-support.md](ios-support.md) for the SwiftUI/UIKit ownership boundary,
single-scene ABI v1 rule, plugin/eject contract, Xcode CLI setup, simulator
install commands, and runtime-evidence requirements.

HarmonyOS is also an embedded native scaffold. For HarmonyOS Skia cross-build
checks, set `MOUI_SKIA_PLATFORM=harmonyos`, `MOUI_SKIA_ARCH=arm64`, and dynamic
linking so the prebuild selects the locked HarmonyOS Skia release artifact:

```sh
MOUI_SKIA_PLATFORM=harmonyos MOUI_SKIA_ARCH=arm64 MOUI_SKIA_LINK_MODE=dynamic \
  moon check examples/harmonyos_demo/harmonyos_skia --target native
```

The standalone demo lives at `examples/harmonyos_demo` rather than extending
Counter. `examples/harmonyos_demo/app` owns the platform-neutral UI,
`examples/harmonyos_demo/harmonyos_skia` owns the MoonBit native exports, and
`examples/harmonyos_demo/harmonyos_app` owns the app-specific Stage
Ability/XComponent shell over the package-published `moui/mobile/harmonyos`
NAPI/CMake template. Use `scripts/build-harmonyos-demo-app.sh --fallback-skia`
for a packaging-only smoke that avoids the HarmonyOS Skia download and validates
MoonBit C generation, native glue compilation, and staged HAP layout. External
apps can copy `moui/mobile/harmonyos/template` and build with
`moui/scripts/mobile/build-harmonyos-hap.sh`. Real HarmonyOS runtime evidence
still requires a non-fallback build plus matching device/emulator first-frame,
input, resize, and lifecycle smoke.

See [harmonyos-support.md](harmonyos-support.md) for the Stage
Ability/XComponent ownership boundary, SDK/toolchain installation, emulator
setup, SDK environment variables, and runtime evidence requirements.

`moon update` refreshes registry packages, including the `window` fork package.
The default `sh scripts/check.sh --profile daily` path guards dependency shape and the
repo-local `moui_skia` acceptance surface. The Skia binding is part of the main
checkout at `moui_skia`.

This keeps `wzzc-dev/window` and `wzzc-dev/moui_skia` declared in
`moui/moon.mod`, keeps `wzzc-dev/moui_theme` as an addon module, and resolves
local workspace members from `moon.work`. The exact list is generated into
[Repository facts](repository-facts.md#workspace-members).

```moonbit
import {
  "wzzc-dev/window@0.5.1-0.1.7",
  "wzzc-dev/moui_skia@0.1.7",
}
```

The MoonBit package ecosystem is still not as mature as older language
ecosystems. A failing build can come from registry cache state, package
publication mistakes, or dependency regressions as well as from MoUI code. When
dependency-related failures appear, first run `moon update`, inspect the
resolved package versions, and check whether `wzzc-dev/window@0.5.1-0.1.7` or
another package changed behavior.

The `window` package still carries MoUI smoke helpers and evidence docs. Use
`scripts/run-window-package-smoke.sh <platform>` to extract the resolved
registry package into a temporary directory and run those helpers without
creating a local checkout. For example, on macOS:

```sh
WINDOW_MOUI_MACOS_SMOKE_LOG_PATH=artifacts/platform-evidence/macos/window-macos-runtime-smoke.log \
  scripts/run-window-package-smoke.sh macos --run
```

The Skia binding is editable in the main repository at `moui_skia`. The default
daily check validates fallback-safe Skia package tests (`moon test moui_skia
--target native`) and the binding workspace's platform status contract. The
binding workspace itself ships
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`, which require
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, and `native/ownership.json`
to prove the editable binding workspace still has a pinned real Skia
artifact/status contract, CI evidence wiring, fallback parity, FFI
ownership/borrow coverage, and native smoke marker coverage. That does not prove
a MoUI platform entrypoint has rendered with real Skia; use
`scripts/macos-skia-renderer-smoke.sh` after configuring real Skia native link
flags for that renderer-level proof.
The binding/provider GitHub Actions workflows are maintained at the repository
root as `.github/workflows/moui-skia-*.yml`; these are the workflows expected
to move with `moui_skia` if it becomes its own repository. The root
`.github/workflows/moui-renderer-real-skia-ci.yml` workflow stays
MoUI-owned because it proves framework renderer integration against the Skia
binding, and `.github/workflows/copilot-setup-steps.yml` sets up MoonBit from
the `moui_skia` workspace for GitHub Copilot coding agent runs. Keep workflow
files in the root `.github/workflows` directory so GitHub discovers them in
this monorepo layout.

GitHub Actions installs MoonBit through the repository-local
`.github/actions/setup-moonbit` action. The pinned compiler version lives in
the root `.moonbit-toolchain` file; update that file when moving CI to a new
MoonBit toolchain version instead of hard-coding installer arguments in each
workflow.

When updating this repository, update all Git checkouts that participate in the
workspace, not just the root checkout. That includes the main MoUI repository
and Git submodules such as `.agents/skills/moonbit-skills` and `window`. Then
run `moon update` so registry dependencies are refreshed. `moui_skia` updates
with the main MoUI checkout.

For a fresh clone, fetch submodules in the initial checkout:

```sh
git clone --recurse-submodules git@github.com:wzzc-dev/MoUI.git
```

If the repository was cloned without submodules, initialize them once:

```sh
git submodule update --init --recursive
```

### Window Submodule And Local Source Mode

The root README intentionally keeps this workflow out of the quick start.
Ordinary MoUI builds do not need a local `window/` checkout.

The `window` submodule is **not** a `moon.work` workspace member by default.
MoonBit resolves `wzzc-dev/window` from mooncakes.io (the published version
pinned in each consumer's `moon.mod`). The `window/` submodule checkout exists
only so developers can switch to local-source dev mode when they need to edit
window source and validate changes inside MoUI before publishing.

To edit window source locally:

```sh
sh scripts/window-dev-mode.sh on      # add ./window to moon.work (local override)
# edit window/ source; moon test/run picks up changes immediately
sh scripts/window-dev-mode.sh off     # remove ./window; resolve from mooncakes.io
```

`scripts/validate-window-dependency.mjs` (run by `check.sh --profile daily` and
CI) fails if `moon.work` lists `./window` on the main branch, so the default
state stays on the published dependency. Do not add `./window` to committed
workspace state just to fix a MoUI build. After publishing a new window version,
update the pinned version in `moui/moon.mod`, `moui_skia/moon.mod`,
`moui_webview/moon.mod`, and `examples/markdown_editor/moon.mod`, then run
`moon update` to refresh the registry cache.

On Windows, use the repository update helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

The `moui_skia` workspace member is updated by the root repository pull; the
window dependency resolves from mooncakes.io (or from the `window` submodule
checkout when dev mode is on).

Mo Workbench depends on `bobzhang/openseek`, which now resolves from
mooncakes.io (pinned in `examples/mo_workbench/moon.mod`, e.g.
`bobzhang/openseek@0.2.2`). No git submodule or `./openseek` workspace member is
required. Run `moon update` to refresh the resolved registry version when a new
openseek release ships. If you need a local `bobzhang/openseek` checkout during
development, use mooncakes' own local override mechanism rather than adding
`./openseek` to `moon.work`. Run Mo Workbench native:

```sh
export OPENAI_API_KEY=...   # or DEEPSEEK=...
export OPENAI_BASE_URL=...  # optional OpenAI-compatible API URL
moon run examples/mo_workbench/macos_skia --target native
```

## Validation

For routine local development, prefer the bounded daily check:

```sh
sh scripts/check.sh --profile daily
```

The detailed daily gate membership, focused package checks, maintenance
ratchets, and addon diagnostic variants live in [testing.md](testing.md). Use
[release-readiness.md](release-readiness.md) for release gate evidence,
provenance, and smoke catalog policy.

## Script Tooling Policy

Keep scripts simple, clear, and maintainable first. When two approaches are
similarly clear, prefer MoonBit for repository rules, static validation,
structure scans, deterministic generators, and any logic that benefits from
`moon check`/`moon test` coverage.

Use `tools/...` MoonBit packages for long-lived CI tools. Keep the checked-in
Node entrypoints as compatibility wrappers over
`scripts/lib/moonbit-tool-runner.mjs` when users or CI already call
`node scripts/*.mjs`. Use `.mbtx` only for short standalone developer scripts;
promote it to a `tools/...` package once it becomes a maintained gate.

Keep Node for browser/CDP, Web smoke capture, HTTP/GitHub artifact work, npm
ecosystem tools, and command execution that is clearer in JavaScript. Keep
sh/PowerShell as thin orchestration for environment variables, shell syntax,
platform setup, and OS-specific command dispatch. Windows MSVC, vcpkg, and zlib
setup stay in PowerShell helpers such as `scripts/windows/setup_msvc_deps.ps1`
and `scripts/windows/msvc_env.ps1`; MoonBit may validate manifests or guidance
around those flows, but it should not install machine tools.

Use `rule`/`dev_build` only for deterministic package build inputs: a declared
input creates a declared output before package build. Do not use
`rule`/`dev_build` to install MSVC, vcpkg, zlib, Chrome, CI runners, or other
machine environment dependencies; do not use it to run smoke tests, access the
network, or mutate global/user state.

Run the real Skia native smoke only after configuring local Skia link flags:

```sh
scripts/macos-skia-renderer-smoke.sh
```

That opt-in check runs both the `moui_skia` native binding smoke and MoUI's
renderer-level smoke at `moui/tests/skia_renderer_smoke/native`, which renders a
small `DrawCommand` frame through `render/skia` and verifies presenter pixels.
The renderer smoke includes bounded `TextRun.frame` text clipping alongside the
general glyph-run text pixel check.
The script builds those smoke packages and runs the produced native executables
directly so failures propagate through the process exit status.

On macOS, use the dedicated helper when you want the script to resolve Skia and
wire the temporary package link flags for you. By default it uses the pinned
JetBrains Skia binary provider from `moui_skia`:

```sh
scripts/macos-skia-renderer-smoke.sh
```

The repository default package files intentionally avoid machine-local Skia
paths. Direct local commands use the `moui_skia` prebuild hook to resolve the
pinned release provider and link mode at build time:

```sh
export MOUI_SKIA_LINK_MODE=dynamic
moon run examples/showcase/macos_skia --target native
moon run examples/mo_workbench/macos_skia --target native
```

Use `MOUI_SKIA_LINK_MODE=dynamic|static|auto` for direct `moon run`/`moon build`
commands. The `--link-mode dynamic|static|auto` script option remains available
for helper-driven smoke runs and overrides the environment for that invocation.
In `auto`, the helper uses the shared provider artifact when it builds an app
entrypoint, because split static Skia archives are order-sensitive at the
transitive app link boundary; renderer-only smoke with
`--skip-showcase-build` keeps using the static artifact.
Skia/Metal link flags are injected by the `moui_skia` prebuild
(`${build.MOUI_SKIA_CC_LINK_FLAGS}`); do not write machine-local absolute
paths into example `moon.pkg` files.

Pass `--enable-skshaper` when the selected Skia library directory includes the
SkShaper module libraries. The helper then configures `moui_skia/native` with
the SkShaper define, links `libskshaper`, `libskunicode_core`,
`libskunicode_icu`, `libharfbuzz`, and `libicu`, and verifies the MoUI renderer
smoke log proves the optional shaped-run path was available.

Add `--run-showcase-smoke` when you want the helper to launch the built
`examples/showcase/macos_skia` executable, wait for the first Skia-presented
frame, and then exit automatically. Add `--run-markdown-smoke` to do the same
for `examples/markdown_editor/macos_skia`:

```sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

The renderer smoke and normal macOS Skia app entrypoints use the default
system-FontMgr text path, including optional SkShaper when enabled. The
first-frame Showcase and Markdown Editor smokes set each entrypoint's
exit-after-first-present flag, and those entrypoints explicitly select
`EmptyTypeface` only for the smoke run. This keeps first-frame AppKit
presentation evidence on the safer default-font retry path while preserving the
normal app default that exercises platform font lookup, emoji retry, and
optional SkShaper when linked.

Use `--skia-provider existing` when you already have a Skia checkout or binary
package:

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Use `--skia-provider source` to build the small CPU Skia library through
`moui_skia/scripts/macos-build-skia.sh` before running the same
MoUI renderer smoke:

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider source \
  --work-dir .skia-cache/macos
```

It temporarily configures `moui_skia/native`,
`moui/tests/skia_renderer_smoke/native`, `examples/showcase/macos_skia`,
`examples/markdown_editor/macos_skia`, and
`examples/mo_workbench/macos_skia`, runs the MoUI renderer pixel smoke, builds
the macOS Skia Showcase entrypoint, and restores all touched `moon.pkg` files
before exiting.

## Preview Loop

Use the lightweight preview loop when iterating on Showcase or another Web
wasm-gc example:

```sh
sh scripts/preview-loop.sh
sh scripts/preview-loop.sh --watch
sh scripts/preview-loop.sh --package examples/counter/web_wasm --watch
sh scripts/preview-loop.sh --package examples/markdown_editor/web_wasm --watch
sh scripts/preview-loop.sh --package website/web_wasm --watch
```

When previewing the website, run `node scripts/sync-website-docs.mjs` first or
use the preview loop for `website/web_wasm`; the website fetches same-origin
Markdown files from `website/web_wasm/docs/`.

For release-style Web output, use the package helper instead of serving the
debug `_build` tree directly:

```sh
node scripts/package-web-app.mjs examples/counter/web_wasm --out artifacts/web/counter
```

The helper builds with `--release --strip`, copies `index.html`, the app wasm,
MoUI Web runtime JS, and package-local `assets/`, then writes `.gz`/`.br`
siblings plus `bundle-size.json`. Keep large images, long Markdown, large JSON,
and fixtures under the Web entrypoint's `assets/` directory and reference them
with relative URLs such as `assets/story/buttons.json`. Text/Markdown/JSON
resources should load through the Web host's same-origin text-file service;
image sources should stay as URL strings so the renderer can load them outside
the wasm module.

## Framework Iteration

Use focused package tests while editing internals:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/runtime --target native
moon test moui/backend/host --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test moui_skia --target native
```

Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
`moon ide find-references` before introducing new public names. Keep edits
package-local where possible. If public API changes, run `moon info` and review
the `pkg.generated.mbti` diff.

## Documentation Sync

Root `docs/` is the source for maintainer and website Markdown pages.
`website/web_wasm/docs/` is the local preview copy consumed by the website app.

After editing docs:

```sh
node scripts/sync-website-docs.mjs
node scripts/check-website-docs.mjs
```

The sync command refreshes the ignored local preview copy. The check command
generates and validates an isolated temporary copy, so it does not require
`website/web_wasm/docs/` to exist in a clean checkout.

GitHub Pages packages `website/web_wasm` with
`scripts/package-web-app.mjs website/web_wasm --out dist/pages`, then stages
the same Markdown set with
`node scripts/sync-website-docs.mjs --out dist/pages/docs`. Keep root docs free
of machine-local paths and generated `artifacts/` evidence.

## Daily Validation

Run the daily validation script for routine handoff:

```sh
sh scripts/check.sh --profile daily
```

Keep this section as an entrypoint only. The full daily command inventory,
focused checks, addon diagnostics, WGPU diagnostic route, and current-host
backend variants are maintained in [testing.md](testing.md).

## Real Renderer And Platform Smoke

Real browser, renderer, and platform smoke runs are opt-in because they require
matching hosts, configured renderer dependencies, or browser/runtime evidence.
Use [testing.md](testing.md#smoke) for the smoke command catalog and
[release-readiness.md](release-readiness.md) for release evidence and
provenance policy. Smoke commands write logs and manifests under `artifacts/`;
do not commit artifacts, and cite the CI run, uploaded artifact, or local smoke
log in release notes.

## CI And Toolchain

GitHub Actions installs MoonBit through `.github/actions/setup-moonbit`. The
pinned compiler version lives in `.moonbit-toolchain`; update that file when
moving CI to a new MoonBit toolchain version. The current pin is MoonBit
`0.10.4` (`moonc v0.10.4+ade96c819`).

MoonBit 0.10.4 treats bare `{}` as ambiguous for empty maps / JSON objects /
blocks. Prefer `Map([])`, `Json::empty_object()`, or `{ () }` at the use site.
`assert_eq` and related debug helpers now require `Debug` rather than `Show`.

Workspace member `./third_party/mizchi_image` temporarily overrides registry
`mizchi/image@0.4.2` with a local `derive(Debug)` patch so dependency checks
pass under 0.10.4. Remove that member once mooncakes ships a compatible image
release (see `third_party/mizchi_image/MOUI_PATCH.md`).

`ci.yml` expresses routine gates through the checked wrappers: the PR profile
gate runs `sh scripts/check.sh --profile pr`, and Linux platform contracts run
`sh scripts/check.sh --profile platform`. The Windows MSVC job intentionally
keeps setup, backend/provider tests, and packaging as explicit PowerShell steps;
it adds only a wrapper contract check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Pr -DryRun -Json -SkipSubmoduleInit
```

The binding workflows for `moui_skia` live in root `.github/workflows/` with
the `moui-skia-*` prefix so GitHub discovers them in this monorepo layout. Do
not move workflow files into sub-workspace `.github/workflows` directories.
MoUI-owned renderer/platform workflows, such as
`moui-renderer-real-skia-ci.yml` and `moui-macos-app-real-skia-manual.yml`,
keep the `moui-*` prefix instead of the package-owned `moui-skia-*` prefix.

On Windows, use the repository update helper when refreshing local checkouts:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

On Windows, use the native PowerShell entry point for daily checks (no MSYS
required). It initializes the `window` submodule on first run and runs the
same bounded mainline package checks as `scripts/check.sh --profile daily`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Daily
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Platform
```

Alternatively, run the shell version under Git Bash:

```sh
sh scripts/check.sh --profile platform
```

Native platform example builds such as
`moon build examples/showcase/macos_skia --target native` or
`moon build examples/showcase/linux_skia --target native` link platform stubs
and native renderer libraries, so cold builds can be slow. Include them only
when validating the current host platform's executable examples:

```sh
sh scripts/check.sh --profile full
```

## Native Packaging Helpers

The packaging helpers wrap already-supported native example packages into
platform-shaped output directories. They are intentionally thin wrappers around
`moon build` and do not replace release signing, notarization, installers, or
store packaging.

macOS `.app` bundle:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos_skia \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0 \
  --build-version 1
```

The bundle is written under `dist/macos/<name>.app` by default. Pass
`--no-build` to package an already-built executable from `_build/native`. The
bundle includes `Contents/Resources/moui-package.json` using schema version 1
with platform, output kind, app name, source MoonBit package, bundle id,
version, build number, executable, bundle name, and runtime file metadata. The
helper validates that manifest before reporting success.

Windows native uses Visual Studio C++ build tools and vcpkg `zlib:x64-windows`.
The build/package helpers are renderer-aware: native Skia packages stay on the
Skia route and do not download or bundle `wgpu_native.dll`, while explicit WGPU
diagnostic packages keep the MSVC dynamic WGPU setup. Build the entrypoint once,
then package the portable folder:

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

The helper imports `vcvarsall.bat`, sets `CC` and `CXX` to `cl.exe`, applies
shared MSVC `CL`/`LINK` flags for native stubs, and uses vcpkg
`zlib:x64-windows`. When the package imports WGPU, it also sets
`MBT_WGPU_LINK_MODE=dynamic` and extracts the official
`wgpu-windows-x86_64-msvc-release.zip` release when no `-WgpuNativeRoot` is
supplied. Its folder is written under `dist\windows-msvc\<AppName>` and
includes `run.cmd`, the schema manifest, and the runtime DLLs needed by the
selected renderer. Skia packages omit `wgpu_native.dll`; WGPU packages include
the WGPU release metadata and set `MBT_WGPU_NATIVE_ROOT` through `run.cmd`.
If Visual Studio's bundled vcpkg reports that classic mode is unavailable,
use `setup_msvc_deps.ps1 -InstallZlib` from the repository root; the script
creates a small ignored manifest workspace under `.tools\vcpkg-msvc` and uses
manifest mode to install `zlib:x64-windows`.

To run the Showcase Skia mainline directly after setup, dot-source the MSVC
environment in the same PowerShell process:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
```

Use the `windows_wgpu` entrypoint only for explicit native WGPU diagnostics:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_wgpu --target native }"
```

Manual manifest validation:

```sh
node scripts/validate-package-manifest.mjs \
  "dist/macos/MoUI Showcase.app/Contents/Resources/moui-package.json" \
  --platform macos
```

Useful focused commands:

```sh
moon test moui/render/wgpu --target native
moon test moui/render/skia --target native
moon test moui/render/sun --target native
moon test moui_skia --target native
sh scripts/check.sh --profile theme
moon test moui_sun/graphics --target native
moon test moui_sun/text --target native
moon test moui_sun/renderer --target native
moon test moui_sun/softbuffer --target native
moon build moui/tests/skia_renderer_smoke/native --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/tests/tooling --target native
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
moon build examples/design_systems/windows_skia --target native
moon build examples/design_systems/linux_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/pdf_workbench/windows_skia --target native
moon build examples/pdf_workbench/linux_skia --target native
moon build examples/showcase/macos_sun --target native
moon build examples/showcase/windows_sun --target native
moon build examples/markdown_editor/windows_skia --target native
moon build examples/showcase/linux_skia --target native
moon build examples/showcase/linux_sun --target native
moon build examples/markdown_editor/linux_skia --target native
```

PDF Workbench app-only and `pdflite_adapter` checks no longer download PDFium by
default. Set `MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1` only when validating the
native PDFium raster adapter, or provide `MOUI_PDFIUM_INCLUDE` plus
`MOUI_PDFIUM_LIB_DIR` to use a local PDFium install without downloading the
locked prebuild.

Use the direct native example builds only on a matching configured host. The
check profiles keep shared platform service checks, current-host
backend/provider checks, and slow native example builds separate. Run native
WGPU and Cosmic text-provider entrypoint builds only when explicitly validating
the experimental WGPU diagnostic route.

## Mooncakes Integration Notes

MoUI keeps production runtime boundaries explicit when using Mooncakes
frontends and tooling:

- Layout stays platform-neutral, but concrete flex/grid/list/stack placement now
  lives in `moui/views` via `View::node`; `core/` should not grow layout-engine
  dependencies for individual controls.
- `Milky2018/moon_accesskit` is the native accessibility tree representation
  used by `backend/host`; `@core.SemanticsNode` remains platform-neutral, and
  Web continues to use its ARIA adapter.
- `Milky2018/moon_zeno` powers renderer path tessellation from MoUI
  `DrawPath` / `PathSpec` values into triangle meshes. SVG parsing remains the
  importer frontend's job.
- `mizchi/markdown` powers the Markdown Editor's package-local parser adapter
  and rich text mapping. See [Markdown Editor](markdown-editor.md) for the
  app-level editing model.
- `mizchi/svg` powers `render.import_svg(String) -> SvgImportResult`, lowering
  parsed SVG scene graph nodes into MoUI `DrawCommand` values.
- `moonbitlang/quickcheck` and `mizchi/pixelmatch` are exercised from
  `moui/tests/tooling/` for property and pixel-diff coverage.

The text stack has its own maintenance page because it spans `core`,
native Skia, diagnostic `render/wgpu` providers, and browser host assets. See
[Text system](text-system.md) before changing `TextSystem`, native text
providers, embedded font registration, or Web text measurement.

## Guidance Maintenance

When a development change affects package layout, docs placement, validation
commands, platform setup, renderer capability status, example structure, or the
text system, also check `AGENTS.md` and the repo-local skills under `skills/`.
Update them in the same change when their instructions would otherwise become
stale.
