# Android 支持

Android 使用 **window-hosted** 移动端路径，目前状态为 `runtime_partial`。
`wzzc-dev/window/android` 拥有 Android 生命周期、Surface 与输入队列；
`moui/backend/android` 将这些回调转换为 MoUI runtime session，
`moui/backend/android/skia` 提供呈现器。

## 入口

| 部件 | 位置 |
|---|---|
| App 逻辑 | `examples/<app>/app` |
| 移动端元数据 | `examples/<app>/moui.mobile.json` |
| MoonBit 入口 | `examples/<app>/android_window_hosted` |
| Android host 模板 | `wzzc-dev/window/android/template` |
| MoUI adapter | `moui/backend/android/window_hosted.mbt` |

入口创建 `AndroidWindowHostedApp` 并通过 `window/android::EventLoop` 运行。
不要在 window event loop 之外增加第二套生命周期、Surface 或输入桥接。

## 工具链

- JDK 17 或更新版本（推荐 JDK 21）
- Android SDK compile API 36、target API 35
- NDK `28.2.13676358`、CMake `3.22.1`
- Gradle `9.6.1` 或兼容的 wrapper
- application minSdk 23

## SDK、NDK 与模拟器设置

使用完整 JDK，并把 SDK 根目录设置为本机实际安装位置；仓库不要求固定的机器本地路径。

```sh
export JAVA_HOME=/path/to/full-jdk
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

scripts/setup-android-sdk.sh --accept-licenses --ndk 28.2.13676358
eval "$(scripts/setup-android-sdk.sh --print-env)"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

该 helper 安装 platform-tools、API 36、Build-Tools 35.0.0、CMake 3.22.1 和锁定的
NDK；不会安装模拟器镜像。Apple Silicon 使用 `arm64-v8a` 镜像，x86_64 主机使用对应的
`x86_64` 镜像。

```sh
sdkmanager --install \
  "emulator" \
  "system-images;android-34;google_apis;arm64-v8a"
echo no | avdmanager create avd \
  -n moui_api34 \
  -k "system-images;android-34;google_apis;arm64-v8a" \
  -d pixel_6 \
  --force

emulator -avd moui_api34 -gpu host -no-snapshot-save &
adb wait-for-device
adb shell getprop sys.boot_completed
```

构建前运行 `moui doctor --platform android`。

## 构建与运行

```sh
moon check examples/showcase/android_window_hosted --target native
moui build android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui run android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
```

`--prepare-only` 只生成 native 输入，不执行 Gradle。`--fallback-skia`
只验证打包，不能作为 renderer 或 runtime 证据。

## 验证与证据

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/android --target native
```

提升运行时结论前，匹配设备或模拟器必须记录首帧、输入、Surface
detach/recreate、IME、剪贴板、无障碍与异步图片观察。实际 presenter route
验证前，`checks/platforms/android.json` 保持 `partial`。

## 状态

该路径可用于开发与模板集成，但尚不是完整 Android 产品结论。证据边界见
`docs/platform-readiness-declaration.md` 与 `docs/window-hosted-moui.md`。
