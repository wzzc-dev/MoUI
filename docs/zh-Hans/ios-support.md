# iOS 支持

iOS 是 **runtime_partial** 的嵌入式原生路由：managed shell 和 host session **可用于开发和演示**（`backend` 报告 `ready=true`、`status=runtime_partial`），但在 managed SwiftUI matching-simulator L3 与 presenter/GPU promotion 补齐剩余缺口之前，该平台**不是**产品完整状态。

规范 shell 是 package-owned SwiftUI `App`，带 `UIViewRepresentable` host。其 render view 显式使用 `CAMetalLayer`，通过 `CADisplayLink` 驱动帧，并将 lifecycle、resize、touch、IME、pasteboard、accessibility、PlatformView 和 Host Service traffic 转发到 MoUI。狭窄的 Objective-C++ bridge 只协商 Embedding API v1、分发其 function table，并拥有复制后的边界数据。

## 状态

三层证据保持分离：**product GPU default**（source/`auto`）、**shell runtime smoke**（`artifacts/shell-runtime/...`）与 **seven-gate GPU promotion claim**（`gpuPromotionEvidence` / `artifacts/gpu-promotion/...`）。

| 区域 | 当前状态 | 证据边界 |
| --- | --- | --- |
| 产品类别 | `runtime_partial`（见 platform-readiness-declaration） | 不是 `committed`；也不是“Counter-only scaffold”。 |
| Host contract | `moui/backend/ios` 中可用的 embedded session（`ready=true`） | Package tests + managed shell wiring；L3 promotion 单独处理。 |
| Platform services | Swift adapters 通过 `EmbedderHostChannel` 拥有 text proxy、pasteboard、a11y container、PlatformView、Host Service channels | Capability flags 反映**代码接线**；完整 managed-shell VoiceOver/device evidence 仍待补。 |
| Frame pacing | Input/resize request redraw；presentation 从 `CADisplayLink` ticks 运行 | 60/120 Hz device pacing evidence 待补。 |
| Skia provider | `moui/backend/ios/skia` preflight `runtime_status=runtime_partial` | Provider checks 证明 wiring；checks JSON 中 presenter route 仍未 verified。 |
| Product GPU default | `auto` -> `SkiaGpuNative` / `metal-gpu` when available（`gpu_promoted=true`） | Source + rebuild `shell-build.json`；不是 seven-gate claim。 |
| Canonical SwiftUI shell | `moui_shell/ios` + framework-staged template 中真实的 `PBXNativeTarget` | Managed fallback builds 只证明 Swift/ObjC++/ABI/native packaging，不是 runtime proof。 |
| First-frame runtime evidence | 下面的非空 screenshots 与 simulator smoke 是针对 Release N UIKit shell 收集的 | 历史 pixels 对该 artifact 仍有效，但不适用于替换后的 managed shell。 |
| Runtime smoke（simulator，2026-07-15 re-verify） | Component Gallery 在冻结 UIKit shell 下 **`status=passed`**，路径为 `artifacts/mobile-runtime/ios/component_gallery/` | Managed SwiftUI lifecycle、pixels、input、IME、clipboard、accessibility、PlatformView 和 async-image evidence 必须在无 production-shell smoke probe 的情况下重新收集。 |
| GPU promotion claim | 仅 scaffold：`artifacts/gpu-promotion/ios/scaffold-latest/`（`gpuPromoted=false`） | 没有 matching-device seven-gate claim；product default 已开启。Runtime smoke pass ≠ seven-gate promotion claim。 |
| Runtime support claim | Release N UIKit simulator service smoke 已通过；canonical SwiftUI runtime claim 待补 | 重新在 Simulator 上运行 managed shell，然后补充 physical-device signing 与 live VoiceOver evidence。 |

## 所有权

- `moui/backend/ios` 拥有 `IosViewHandle`、`IosRendererProvider`、readiness summaries 和 `IosRuntimeSession`。
- `moui/backend/ios/skia` 将 `moui/render/skia` 包装为 `HostWindowRenderer`，并在编译为 iOS 或 iOS Simulator 时将复制的 RGBA frames present 到 UIKit `UIImageView` child。
- `examples/counter/ios_skia` 和 `examples/showcase/ios_skia` 是薄 MoonBit entrypoints。它们只安装 app program 和 renderer 配置；`backend/ios` 注册回调供 `moui_shell/embedding` 的固定 Embedding API v1 symbols 调用。
- `moui_shell/ios` 拥有规范 Swift package、SwiftUI scene lifecycle、`CAMetalLayer` view、display link、UIKit host adapters、plugin registry、ABI bridge 和 canonical Xcode template。
- 正常 managed applications 将 identity 保存在 `shell.json`，并且不拥有 Xcode project；需要原生项目所有权时使用 `moui shell eject ios`。

iOS 15 仍是 deployment floor。Product `auto` 在可用时优先 Metal `CAMetalLayer` / worker-owned GPU path；raster compatibility path 仍通过 `NSData -> CGImage -> UIImage -> UIImageView` present，用于显式 `skia-raster` 与 sticky recovery fallback。

## Focused Checks

日常 scaffold 工作使用 fallback-safe checks：

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/ios --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/ios/skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/ios_skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/ios_skia --target native
sh moui_shell/ios/tests/run-ios-managed-shell-tests.sh
scripts/build-shell-ios-app.sh --app counter --fallback-skia
scripts/build-shell-ios-app.sh --app showcase --fallback-skia
```

这些检查在交付前有用，但都不能证明 iOS runtime presentation。

## Skia Cross-Build

cross-building 真实原生路由时使用显式 Skia prebuild 变量：

```sh
MOUI_SKIA_PLATFORM=iosSim \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=static \
moon check examples/counter/ios_skia --target native
```

`MOUI_SKIA_PLATFORM=iosSim` 从 `moui_skia/skia-provider-lock.json` 选择 iOS Simulator asset；device builds 使用 `ios`。`MOUI_SKIA_ARCH` 对 locked simulator artifacts 接受 `arm64` 或 `x64`。Counter app script 默认使用 static Skia，因为第一个 simulator app scaffold 不需要打包单独的 `libskia.dylib`。

## Xcode 设置

managed shell 需要 Xcode 15.4 或更新版本。Package builder 会在 artifact directory 下 staging 规范真实 `PBXNativeTarget`；该 target 的 build phase 调用 core builder，并写出完整 executable bundle。从 Mac App Store 或 Apple Developer downloads 安装 Xcode，然后选择它：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

不需要仓库私有 SDK directory。Core builder 使用 `xcrun --sdk <sdk>` 选择 Clang、Swift 和 SDK path，以 Swift 5 language mode 编译，并强制 iOS 15 deployment floor。

## Mobile Xcode Builds

iOS builds 使用 package-owned minimal `PBXNativeTarget` 作为 primary entrypoint。Applications 不在 source tree 中保留 managed Xcode project。
可复用 SwiftUI shell、native build script、canonical Xcode template 和 compatibility contracts 位于 package-published `moui_shell` 与 `moui_shell/scripts` 目录下。Builder 从仓库示例的 `examples/<app>/shell.json` 或外部 app 自有的 `shell.json` 读取 app-facing metadata，然后生成 MoonBit C 与 Skia response files，编译 ABI adapter、狭窄 Objective-C++ bridge、Swift package module、generated app configuration 和 plugin sources，最后写出 Simulator `.app` bundle。

从仓库根目录构建实验性 Counter iOS Simulator app：

```sh
scripts/build-shell-ios-app.sh --app counter
```

用同一路由构建 Showcase：

```sh
scripts/build-shell-ios-app.sh --app showcase
```

默认输出为：

```text
artifacts/ios/counter/MoUICounter.app
artifacts/ios/showcase/MoUIShowcase.app
```

有用选项：

```sh
scripts/build-shell-ios-app.sh --app counter --arch x86_64
scripts/build-shell-ios-app.sh --app counter --deployment-target 15.0
scripts/build-shell-ios-app.sh --app counter --sdk iphoneos --arch arm64
scripts/build-shell-ios-app.sh --app counter --renderer auto
```

允许的 renderer modes 为 `auto`、`skia-gpu` 和 `skia-raster`。Generated build metadata 和 startup logs 会记录 requested 与 selected modes。对真实 Skia 包，`auto` 与 `skia-gpu` 选择 GPU；fallback-Skia builds 与显式 `skia-raster` 保持 CPU presenter。

`--sdk iphoneos` 只构建 unsigned device bundle。真实设备安装仍需要 provisioning 和 signing，这超出了第一个 iOS scaffold 的范围。

packaging-only smoke 使用：

```sh
scripts/build-counter-ios-app.sh --fallback-skia
scripts/build-component-gallery-ios-app.sh --fallback-skia
```

`--fallback-skia` 验证 MoonBit C generation、SwiftUI/UIKit host-adapter 与 ABI bridge compilation、runtime compatibility、native-stub compilation、bundle layout 和 ad-hoc simulator signing。它会报告 native Skia unavailable，且不得用作 first-frame runtime evidence。

managed SwiftUI shell 是默认值。输出 bundle 会在 `MOUIShellMode` 中记录所选 route。

应用可直接使用 `scripts/build-shell-ios-app.sh --app ...`；managed shell 不保留旧 runner 分支。

外部 schema v1 app 在 application workspace 中只保留 `shell.json`、resources、plugins 和 MoonBit shell entrypoint。package-published script 会自动 staging canonical Xcode project：

```sh
.mooncakes/wzzc-dev/moui_shell/scripts/build-ios-app.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/shell.json"
```

只有当 app 需要拥有并 version native project 时，才使用 `moui shell eject ios --output <dir>`。`--xcode-project` 保留给 ejected shells；managed path 不需要它。

保留 template 的空 `UILaunchScreen` dictionary。没有现代 launch screen declaration 时，iOS 可能以 legacy `320x480` compatibility mode 运行 app，导致 presentation letterbox 并改变 touch-coordinate mapping。

## Scene 与 Extension Contract

Embedding API v1 支持一个 active iOS scene。每个 managed `Info.plist` 都将 `UIApplicationSupportsMultipleScenes` 设为 false；如果仍然请求第二个并发 scene，Swift scene lease 会返回 `-1001`。Surface detach 会为 background/foreground 和 view recreation 保留 application session；`destroy_application` 是 process-terminal，并会单独调用。

规范 shell 接受来自 `shell.json` 和 source-based `moui.plugin.json` manifests 的 app-owned configuration。Shell API v1 plugins 可注册 native PlatformView factories 和 named Host Service channel handlers。Resolver 会编译声明的 Swift/Objective-C++ sources、复制声明的 resources、拒绝 reserved `moui.*` names，并让 package managers、build scripts、frameworks 和 prebuilt native libraries 留在 managed route 之外。

需要 custom Xcode build phases、binary frameworks、managed manifest 之外的 entitlements，或不同 scene architecture 的 app，必须通过拥有自己的 native project 和 shell 来 eject。Eject 之后的稳定边界是 `moui_embedding_api_v1.h`；应用必须保持 ABI compatibility、length-driven data ownership、session-generation checks 和 detach/destroy separation。

## Simulator Smoke

构建非 fallback app 后，将其安装并启动到已启动的 simulator：

```sh
xcrun simctl install booted artifacts/ios/counter/MoUICounter.app
xcrun simctl launch booted dev.wzzc.moui.counter
```

在晋升任何 runtime claim 前记录 screenshot 和 log evidence。catalog-backed recorder 会自动化本地 evidence shape：

```sh
node scripts/record-shell-runtime-smoke.mjs --platform ios --app counter --require-passed
node scripts/record-shell-runtime-smoke.mjs --platform ios --app showcase --require-passed
```

iOS recorder 使用 Meta `idb`，因为 Apple 原生 `simctl` 没有 tap 或 swipe subcommand。运行 iOS smoke 前安装 client 与 companion：

```sh
brew tap facebook/fb
brew trust --formula facebook/fb/idb-companion
brew install idb-companion
pipx install fb-idb
```

Recorder 连接 companion，等待非空 accessibility tree，选择第一个有有效 frame 的 enabled button，点击其中心，并发送真实 HOME event 以触发 lifecycle detach。Input 只有在当前 launched PID 记录 pointer receipt 且 before/after pixels 改变时才通过。

Showcase 在 iOS 上直接打开 `platform/mobile-service-probe`。Recorder 通过 accessibility label 找到 `Service probe text` 和 `Activate service probe`，使用 `idb ui text`，驱动原生 Select/Copy/Paste menu，用 `simctl pbcopy`/`pbpaste` 写入并读取 Simulator pasteboard，滚动页面，并等待 deferred-image loading/ready logs。只有在有 live VoiceOver session 可用时才添加 `--assistive-tech`。

Xcode 26.3 不通过 `simctl io` 暴露 rotation；recorder 通过 `osascript` 使用 Simulator Device menu。macOS 必须向该 automation process 授予 Accessibility permission。没有该权限时，app 无法产生第二个 surface size，因此 `resize` 保持 `no`。没有实际激活 VoiceOver 的 preference write 不满足 accessibility focus/action evidence。

2026-07-14 本地 iPhone 17 Pro Simulator Component Gallery smoke 针对 Release N UIKit shell，在 `artifacts/mobile-runtime/ios/component_gallery/mobile-runtime-smoke.json` 中为 schema-valid **`status=passed`**（用 `--require-passed` 校验）。这是历史证据；新的 Showcase managed-shell evidence 仍待补。

该 artifact 记录了 lifecycle attach/detach、nonblank first frame、resize、representative input + scroll、IME、clipboard write/read、accessibility tree/focus/action、async-image loading/ready、clean shutdown，以及带 **pending** seven-gate skeleton 的 Metal GPU configure（`SkiaGpuNative` / `metal-gpu` / `gpuPromoted=true`，`gpuPromotionEvidence.claimed=false`）。Simulator `realDeviceSigning` 保持 `pending`。

该 artifact 仍是 legacy shell 的历史证据。它不能用于晋升 canonical SwiftUI shell。请对非 fallback managed build 重新运行同一个 recorder，并从外部收集真实交互。Production Swift 与 Objective-C++ shell sources 有意不包含环境变量驱动的 accessibility 或 service smoke probe。

仍然相关的 recorder 行为：

- continuous `log stream`（使 attach/IME/clipboard 不会被 scroll 淹没）
- service-probe-first idb planning
- seven-gate thresholds 只在断言 promotion claim 时强制执行

## 物理设备验收

先构建设备 artifact：

```sh
scripts/build-shell-ios-app.sh \
  --app showcase --sdk iphoneos --arch arm64
```

当前 builder 有意输出 unsigned bundle。安装前用 app 的真实 team/profile provision 并签名，然后在启用 VoiceOver 的设备上运行同一 probe，收集 app logs/screenshots。验收要求中文组合输入和 emoji/ZWJ 编辑、system text 与 PNG clipboard round trips、VoiceOver tree/focus/activate、portrait-landscape-portrait resize、async-image loading/ready、background detach 和 clean relaunch。`realDeviceSigning=yes` 只能来自该 signed installed run。

## 所需运行时证据

passed iOS runtime claim 至少需要非 fallback simulator/device app 加 matching evidence：

- SwiftUI scene lifecycle attach/detach 一个 `IosRuntimeSession`，并有单独的 terminal application destroy。
- managed `CAMetalLayer`-backed `UIView` present 非空 first-frame pixels，且其 PlatformView overlay 不吞掉 MoUI input。
- Resize 和 touch callbacks 到达 `HostRuntimeDriver`。
- Text input/IME observations，或显式 pending status。
- Clipboard、accessibility、async image、real-device signing 和 packaging observations，或显式 pending status。

在这些 observations 存在之前，请将 iOS 描述为 experimental embedded scaffold，而不是 passed platform。
