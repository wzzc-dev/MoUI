# Android 支持

Android 是 **runtime_partial** 的嵌入式原生路由：managed shell 和 host session **可用于开发和演示**（`backend` 报告 `ready=true`、`status=runtime_partial`），但在 managed-shell matching-device L3 与 presenter/GPU promotion 补齐剩余缺口之前，该平台**不是**产品完整状态。

共享移动端模板拥有规范的 Kotlin `MoUIActivity`/`MoUISurfaceView`，提供 `ANativeWindow`，通过 `Choreographer` 驱动帧，并将 lifecycle、resize、pointer、IME、clipboard、accessibility 以及 revisioned PlatformView snapshots 转发到 MoUI。`MoUIActivity` 继承 AndroidX `ComponentActivity`；其 `FrameLayout` 将 MoUI surface 放在原生 PlatformView overlay 之下。

## 状态

| 区域 | 当前状态 | 证据边界 |
| --- | --- | --- |
| 产品类别 | `runtime_partial`（见 platform-readiness-declaration） | 不是 `committed`；也不是“仅有未接线的 scaffold”。 |
| Host contract | `moui/backend/android` 中可用的 embedded session（`ready=true`） | Package tests + managed shell wiring；L3 promotion 单独处理。 |
| Platform services | `InputConnection`、clipboard、virtual a11y、PlatformView overlay 通过 `MobileHostChannel` 接线 | Capability flags 反映**代码接线**；完整 managed-shell device evidence 仍待补。 |
| Frame pacing | Input/resize request redraw；presentation 从 `Choreographer` frame ticks 运行 | 60/120 Hz device pacing evidence 待补。 |
| Skia provider | `moui/backend/android/skia` preflight `runtime_status=runtime_partial` | Provider checks 证明 wiring；checks JSON 中 presenter route 仍未 verified。 |
| Counter entrypoint | `examples/counter/android_skia` 导出薄 native hooks | 仅 compile/check evidence。 |
| APK shell | package-owned Kotlin/AndroidX managed shell staged under `artifacts/`；`examples/*/android_app` 是 Release N compatibility metadata | Packaging matrix passed；fallback APK 不是 runtime proof。 |
| First-frame runtime evidence | HUAWEI SCM-W09 设备上的非 fallback Component Gallery APK；`resource/screenshots/android-componentgallery.jpg` 中有非空 first-frame screenshot（2026-07-10） | First-frame pixels 已证明。 |
| Runtime support claim | Release N Java shell 在 emulator 上达到 **`passed`**（Component Gallery，2026-07-15）；canonical managed shell 需要新的 matching-device run | 历史证据不会自动晋升 managed shell。声明 managed-shell L3 前，需要在无 shell-side probes 的情况下重新运行 `scripts/android-mobile-runtime-evidence.sh`。 |

## 所有权

- `moui/backend/android` 拥有 `AndroidSurfaceHandle`、`AndroidRendererProvider`、readiness summaries 和 `AndroidRuntimeSession`。
- `moui/backend/android/skia` 将 `moui/render/skia` 包装为 `HostWindowRenderer`，并在编译为 Android 时将复制的 RGBA frames present 到 `ANativeWindow`。
- `examples/counter/android_skia` 是 JNI/CMake 的薄 MoonBit entrypoint。其 attach/resize/pointer/render/detach exports 保持小型，让 Android app 拥有 shell。
- `moui/mobile/android` 拥有规范 Kotlin `ComponentActivity`、`MoUISurfaceView`、PlatformView overlay/factory API、clipboard provider、virtual accessibility bridge、`Choreographer`、registered JNI adapter、`ANativeWindow` acquisition 和可复用 CMake wiring。
- `examples/counter/android_app` 和 `examples/showcase/android_app` 是仅仓库使用的 Release N Gradle metadata fixtures；managed applications 不保存它们。
- `moui/mobile/legacy/android` 保留 Release N Java shell 与 name-mangled JNI adapter，作为一个 release 的 compatibility fixture。它不会被隐式选择。

Android 保持 minSdk 23 与 targetSdk 35。managed shell 针对 SDK 36 编译，因为 AndroidX Activity 1.13.0 声明了 `minCompileSdk=36`；不支持禁用 AAR metadata check。当 host GPU surface 可用时，产品 `auto` 在 API 24+ 上优先 Vulkan 并 fallback 到 GLES（API 23 使用 GLES）。`SkiaRasterNative` 仍是显式模式和 sticky recovery fallback，并且在该路径上仍会复制完整 pixel frames。

## Focused Checks

日常 scaffold 工作使用 fallback-safe checks：

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/android --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/android/skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/android_skia --target native
scripts/build-counter-android-apk.sh --fallback-skia
```

这些检查在交付前有用，但都不能证明 Android runtime presentation。

## Skia Cross-Build

cross-building 真实原生路由时使用显式 Skia prebuild 变量：

```sh
MOUI_SKIA_PLATFORM=android \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=static \
moon check examples/counter/android_skia --target native
```

`MOUI_SKIA_PLATFORM=android` 会从 `moui_skia/skia-provider-lock.json` 选择 Android asset，而不是推断 desktop host platform。`MOUI_SKIA_ARCH` 接受 `arm64`、`x64` 或 `riscv64`，与 locked provider manifest 对齐。`MOUI_SKIA_SKIA_INCLUDE` 和 `MOUI_SKIA_SKIA_LIB_DIR` 可在 Android build system 已经 staging Skia 时覆盖 release provider。

## SDK 与 NDK 设置

MoUI 不要求仓库私有的 Android SDK 位置。使用官方 Android 工具安装 SDK/NDK，然后将 `ANDROID_HOME` 或 `ANDROID_SDK_ROOT` 指向该 SDK root。不要把机器本地 SDK 路径记录为项目要求。

仓库 helper 会安装官方 command-line tools 和 required SDK packages。它要求 `PATH` 上有 JDK，因为会使用 `sdkmanager`、`javac` 和 `keytool`。APK builds 还要求 `jlink`，因此要让 `JAVA_HOME` 指向完整 JDK，而不是精简 runtime。Android Gradle Plugin 9.x 使用 Java 17 或更新版本；Java 21 是推荐的本地默认值。Java 11 对 APK build 来说太旧，而非常新的 JDK 可能领先于 Gradle/Groovy 支持。

```sh
scripts/setup-android-sdk.sh --accept-licenses
eval "$(scripts/setup-android-sdk.sh --print-env)"
```

默认情况下，macOS 安装到 `~/Library/Android/sdk`，Linux 安装到 `~/Android/Sdk`。使用 `scripts/setup-android-sdk.sh --android-home /path/to/Android/Sdk` 可指定自定义 SDK root。

手动设置应安装：

- Android SDK Platform 36（AndroidX Activity 1.13.0 要求的 compile SDK）
- Android SDK Build-Tools 35.0.0
- Android SDK Platform-Tools
- **NDK 28.2.13676358**（由 `moui/mobile/android/mobile-app.gradle` 与 `moui/scripts/mobile/prepare-native-build.mjs` 固定；覆盖时务必谨慎）
- CMake 3.22.1
- emulator smoke：`emulator` package + 与 host arch 匹配的 system image

命令行设置示例：

```sh
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"   # macOS default
# Linux default is often ~/Android/Sdk
mkdir -p "$ANDROID_HOME/cmdline-tools"
# Unzip the official commandlinetools package so that this path exists:
#   "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmake/3.22.1/bin:$PATH"

sdkmanager --licenses
sdkmanager --install \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;35.0.0" \
  "cmake;3.22.1" \
  "ndk;28.2.13676358"
```

在所有位置固定同一个 NDK（Gradle `ndkVersion`、prepare script 和 `ANDROID_NDK_HOME`）：

```sh
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
```

**libc++ packaging：** MoUI 打包完整的 NDK `libc++_shared.so`（`c++_shared` STL，`doNotStrip`）。用 NDK A 编译却混入 NDK B / stripped minimal libc++，会在 `dlopen` 时因 `std::ostringstream` 触发 `UnsatisfiedLinkError` 并导致 runtime streams 为空。如果 native 加载失败，重新安装 NDK 28.2，清理 `.cxx` / jniLibs / Gradle caches，并重新构建。

## Mobile APK Builds

Android APK builds 现在使用共享 mobile Gradle route。构建会从解析出的 `wzzc-dev/moui` 包 staging Kotlin `ComponentActivity`、registered JNI bridge、Gradle project、CMake module 和 plugin registry。仓库示例只提供 `examples/<app>/mobile.json` 与 MoonBit entrypoint；`moui/mobile/build-contracts.json` 仅由显式 Release N legacy matrix 使用。Gradle pre-build task 会生成 MoonBit C 与 Skia flags，编译 staged JNI/CMake project，并让 Gradle package/sign debug APK。

从仓库根目录构建实验性 Counter debug APK：

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-mobile-android-apk.sh --app counter
```

用同一路由构建 Showcase：

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-mobile-android-apk.sh --app showcase
```

Renderer mode 是显式且可审计的：

```sh
scripts/build-mobile-android-apk.sh --app counter --renderer auto
scripts/build-mobile-android-apk.sh --app counter --renderer skia-raster
```

对真实 Skia 包，`auto` 和 `skia-gpu` 选择 GPU（`gpuPromoted: true`）。Fallback-Skia builds 与显式 `skia-raster` 保持 CPU presenter。

安装了多个并行 NDK 版本时，固定 **28.2.13676358**：

```sh
ANDROID_HOME=/path/to/Android/Sdk \
ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/28.2.13676358 \
scripts/build-mobile-android-apk.sh --app counter
```

默认 APK 路径通过 `moui_skia/build.js` 解析 locked Android Skia provider，使用 dynamic Android Skia artifact 以便打包 native dependencies，构建 app 的 native library，打包共享 Kotlin `SurfaceView`/PlatformView-overlay glue，并写出：

```text
artifacts/android/counter/app-debug.apk
artifacts/android/showcase/app-debug.apk
```

默认 `arm64-v8a` APK 包含 `libmoui_counter_android.so`、`libskia.so` 和 NDK `libc++_shared.so`。只有显式 static-link 实验才设置 `MOUI_SKIA_LINK_MODE=static`。

packaging-only smoke 使用：

```sh
scripts/build-counter-android-apk.sh --fallback-skia
scripts/build-component-gallery-android-apk.sh --fallback-skia
```

`--fallback-skia` 验证 MoonBit C generation、JNI、CMake、Kotlin/resource packaging 和 debug signing。它会报告 native Skia unavailable，且不得用作 first-frame runtime evidence。

旧的 app-specific build scripts 仍作为 `scripts/build-mobile-android-apk.sh --app ...` 的 compatibility wrappers。

默认构建始终选择 managed shell。在 Release N compatibility window 中，维护者可以显式构建冻结的 Java fixture：

```sh
scripts/build-mobile-android-apk.sh \
  --app counter \
  --fallback-skia \
  --legacy-java-shell \
  --compile-sdk 35
```

该 flag 会以一个整体切换 Java/Kotlin source root、manifest Activity/provider 和 CMake JNI glue root。它是 compatibility audit，不是第二个 production mode。

外部 app 应使用 `moui new --platform android`，或将 Android block 加入 schema v2 `mobile.json`。Managed builds 会派生固定 runtime ABI 并 stage canonical project；app 仓库中没有 `android.native` export map 或 native project copy：

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-android-apk.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json"
```

仅当应用需求超出 managed plugin contract 时，才使用 `moui mobile eject android --output android_app`。后续构建传入 `--ejected-shell --android-project android_app`；MoUI 会验证 versioned lock，但绝不会覆盖该项目。

## 模拟器设置与 Smoke

三层证据保持分离：**product GPU default**（source/`auto`）、**mobile runtime smoke (L2)** 与 **seven-gate GPU promotion claim (L3)**。

| 层级 | 含义 | Android “GPU feasible” 门槛 |
| --- | --- | --- |
| L1 packaging | 非 fallback APK，`selected=skia-gpu`，`gpuPromoted=true` | 必需 |
| L2 runtime | 进程加载 native + configure log：`skia-gpu-native`、`vulkan-gpu` 或 `egl-gpu`，**`gpuAvailable=true`**，attach + 非空 frame | **必需** |
| L3 seven-gate claim | 600s perf/memory/context-loss，`claimed=true` | **非必需** |

`scripts/setup-android-sdk.sh` 安装 platform-tools、platforms、build-tools、CMake 和 NDK，**不**安装 emulator 或 system images。接下来安装这些组件。

### 安装 emulator + system image + AVD

Host arch：Apple Silicon / arm64 hosts 使用 `arm64-v8a` images；x86_64 hosts 使用 `x86_64`。

```sh
scripts/setup-android-sdk.sh --accept-licenses --ndk 28.2.13676358
eval "$(scripts/setup-android-sdk.sh --print-env)"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Emulator binary + API 34 Google APIs image (adjust API/arch as needed)
sdkmanager --install \
  "emulator" \
  "system-images;android-34;google_apis;arm64-v8a"

# Create AVD once (name is local; use any stable name)
echo no | avdmanager create avd \
  -n moui_api34 \
  -k "system-images;android-34;google_apis;arm64-v8a" \
  -d pixel_6 \
  --force

avdmanager list avd
```

### 启动模拟器

```sh
# Prefer GPU host acceleration when available
emulator -avd moui_api34 -gpu host -no-snapshot-save &
# Headless CI-style alternative:
# emulator -avd moui_api34 -gpu swiftshader_indirect -no-window -no-audio -no-snapshot-save &

adb wait-for-device
adb devices -l
# Wait until boot completed
adb shell getprop sys.boot_completed   # expect 1
```

不要在低内存 host 上同时运行 Android 和 HarmonyOS 模拟器。

### 构建非 fallback APK (L1)

```sh
scripts/build-mobile-android-apk.sh --app showcase --renderer auto
# Optional packaging checks:
# unzip -l artifacts/android/showcase/app-debug.apk | rg 'lib/.*/(libshowcase|libskia|libc\+\+_shared)'
# python3 -c "import os; p='…/libc++_shared.so'; print(os.path.getsize(p))"  # expect multi-MB, not ~1MB stripped
```

Artifact：`artifacts/android/showcase/app-debug.apk`  
Meta：`artifacts/android/showcase/native/mobile-build.json` ->
`selected=skia-gpu`、`gpuPromoted=true`、`fallbackSkia=false`。

### 安装 + 手动启动（不运行完整 recorder）

```sh
SERIAL="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
APK=artifacts/android/showcase/app-debug.apk

adb -s "$SERIAL" install -r "$APK"
adb -s "$SERIAL" logcat -c
# Activity is the shared template class (not applicationId-relative).
adb -s "$SERIAL" shell am start -n \
  dev.wzzc.moui.componentgallery/dev.wzzc.moui.mobile.MoUIActivity
# If start fails: adb shell cmd package resolve-activity --brief dev.wzzc.moui.componentgallery

# Continuous GPU configure evidence (do not use one-shot logcat dumps only)
adb -s "$SERIAL" logcat -s MoUIMobile:V | tee /tmp/moui-android-cg.log
# Expected line shape:
# moui-mobile renderer configure … status={"platform":"android","selected":"skia-gpu-native",
#   "surfaceRoute":"vulkan-gpu"|"egl-gpu","gpuAvailable":true,"gpuPromoted":true,…}

# Optional screenshot
adb -s "$SERIAL" exec-out screencap -p > /tmp/moui-android-cg.png
```

如果 app 立即因 `UnsatisfiedLinkError` / missing `ostringstream` vtable 崩溃，应先修复 NDK/libc++ packaging（见 [SDK 与 NDK 设置](#sdk-与-ndk-设置)），再判断 GPU 不可用。

### 记录 + 校验 smoke (L2)

```sh
SERIAL="$(adb devices | awk '/\tdevice$/{print $1; exit}')"

scripts/build-mobile-android-apk.sh --app showcase --renderer auto
node scripts/record-mobile-runtime-smoke.mjs \
  --platform android --app showcase --device "$SERIAL"
node scripts/validate-mobile-runtime-manifest.mjs \
  artifacts/mobile-runtime/android/showcase/mobile-runtime-smoke.json
# Full service gate only when observations are green:
# node scripts/record-mobile-runtime-smoke.mjs \
#   --platform android --app showcase --device "$SERIAL" --require-passed
```

Evidence directory：`artifacts/mobile-runtime/android/showcase/`

```sh
rg -n 'renderer configure|surfaceRoute|gpuAvailable|UnsatisfiedLinkError' \
  artifacts/mobile-runtime/android/showcase/runtime-stream.log \
  artifacts/mobile-runtime/android/showcase/runtime.log
```

**L2 GPU 通过条件：**

| 检查 | 期望 |
| --- | --- |
| Native load | 没有 `UnsatisfiedLinkError` |
| configure | `selected=skia-gpu-native` |
| route | `vulkan-gpu`（API 24+ 首选）或 `egl-gpu` |
| | **`gpuAvailable":true`** |
| Frame | 非空 first frame + attach |
| Better | IME/clipboard/a11y/async-image -> `status=passed` |

Packaging-only（`gpuAvailable=false`、empty stream、fallback-Skia APK）**不是** GPU-feasible L2。

### GPU feasibility snapshot（本地，2026-07-15）

`artifacts/mobile-runtime/android/component_gallery/` 下的历史 Component Gallery smoke：

- `status`：**`passed`**（`--require-passed` ok，2026-07-15）
- `renderer.selected`：`SkiaGpuNative`
- `surfaceRoute`：**`vulkan-gpu`**
- `gpuAvailable` / `gpuPromoted`：**true**
- Observations：attach、detach、nonblank first frame、resize、representative input、scroll、IME、clipboard write/read、accessibility tree/focus/action、async-image、clean shutdown 全部 **yes**；`realDeviceSigning` 在 emulator 上仍为 pending。Shell-side service smoke + semantics probe plan 覆盖 uiautomator 无法看到的 Canvas virtual-node discovery。

## 所需运行时证据

完整 **`passed`** 的 Android runtime claim 至少需要非 fallback APK 加 matching device/emulator evidence：

- Activity/Surface lifecycle 创建并 dispose `AndroidRuntimeSession`。
- `ANativeWindow` presentation 具有非空 first-frame pixels。
- Resize 和 pointer callbacks 到达 `HostRuntimeDriver`。
- Text input/IME observations，或显式 pending status。
- Clipboard、accessibility、async image 和 packaging observations，或显式 pending status。

当 configure 证明 GPU route 且 first-frame 非空时，可更早声明 **GPU feasibility (L1+L2)**（见上表）。L3 seven-gate claim 仍然独立（普通 smoke 中 `gpuPromotionEvidence.claimed=false`）。

已检查的 smoke catalog 包含 release/manual Android mobile runtime suites。非 fallback build 后，用以下命令记录和校验：

```sh
node scripts/record-mobile-runtime-smoke.mjs --platform android --app counter --device <serial>
node scripts/record-mobile-runtime-smoke.mjs --platform android --app showcase --device <serial>
# release bar only when complete:
node scripts/record-mobile-runtime-smoke.mjs \
  --platform android --app showcase --device <serial> --require-passed
```

Showcase 在移动端直接打开 `platform/mobile-service-probe`。Recorder 在 Android accessibility tree 中定位其 text field 与 action，注入 IME text，使用原生 Copy/Cut/Paste key events，旋转并恢复设备，滚动，并要求 async-image loading/ready logs。对 physical-device acceptance，传入 `--device <adb-serial> --assistive-tech`，且 TalkBack 已安装并启用。passed run 要求两种不同的已记录 surface sizes，以及 accessibility tree、focus 和 targeted action receipts；普通 coordinate taps 不能替代 TalkBack actions。

在晋升 image clipboard support 之前，device acceptance 仍必须手动通过另一个 app round-trip 一个 PNG。
