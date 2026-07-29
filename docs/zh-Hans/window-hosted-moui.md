# 嵌入运行时后端

Android、iOS 和 HarmonyOS 使用**嵌入运行时后端**模型。它们的
`wzzc-dev/window` embedder 是 winit 风格的宿主：
`HostCmd` → `EventLoop` → `ApplicationHandler`。Surface 和输入不经过第二套
attach/inject 桥接。

这是一种宿主所有权分类，而不是设备分类。Android 和 HarmonyOS 的桌面产品只要由
平台 embedder 拥有 lifecycle、surface、input 和 event loop，就仍使用嵌入运行时
后端模型。

## 架构

```text
window/<platform>/template / 原生 Activity|UIApp|Ability
        → window HostCmd 队列
        → EventLoop.pump / run_app
        → *EmbeddedRuntimeBackend (moui/backend/{android,ios,harmonyos})
        → AndroidRuntimeSession / IosRuntimeSession / HarmonyOsRuntimeSession
        → Skia HostWindowRenderer
```

window-hosted 是唯一受支持的嵌入运行时后端路径。不要在 `HostCmd` 和
`ApplicationHandler` 之外再添加生命周期、Surface 或输入桥接。

## 包

| 部件 | 路径 |
|------|------|
| Android 嵌入运行时后端 | `moui/backend/android/window_hosted.mbt`（`AndroidEmbeddedRuntimeBackend`） |
| iOS 嵌入运行时后端 | `moui/backend/ios/window_hosted.mbt`（`IosEmbeddedRuntimeBackend`） |
| HarmonyOS 嵌入运行时后端 | `moui/backend/harmonyos/window_hosted.mbt`（`HarmonyOsEmbeddedRuntimeBackend`） |
| Counter 入口 | `examples/counter/{android,ios,harmonyos}_window_hosted` |
| window 契约 | `window/docs/mobile-hosted-backend.md` |
| 移动端状态 | `checks/platforms/{android,ios,harmonyos}.json` |

## 验证

Host-sim（不需要模拟器）：

```sh
sh scripts/window-hosted-hostsim-smoke.sh
```

VM facade（host-sim 加可选设备探针）：

```sh
# 始终运行 host-sim
sh scripts/window-hosted-vm-smoke.sh

# AVD/Simulator/HVD 就绪时：
WINDOW_HOSTED_ANDROID_AVD=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_IOS_SIM=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_HARMONYOS_HVD=1 sh scripts/window-hosted-vm-smoke.sh
```

只验证 window 包：

```sh
moon test window/modules/window/android --target native
moon test window/modules/window/ios --target native
moon test window/modules/window/harmonyos --target native
```

## 状态

| Gate | 状态 |
|------|------|
| HostCmd host-sim（window） | 脚本已固定；包测试通过 |
| MoUI window-hosted host-sim | 后端测试通过（2026-07-21） |
| Counter 包检查 | android/ios/harmonyos_window_hosted 检查通过 |
| Android AVD 安装并启动 | **通过**，2026-07-21（`moui_api34`、包 `dev.wzzc.window.hosted.counter`；原生库和 EventLoop 已启动；截图位于 `artifacts/window-hosted-android/`） |
| iOS Simulator 安装并启动 | **通过**，2026-07-21；UIKit host 移至 `window/modules/window/ios/template/Sources` 后在 iPhone 17 simulator 上启动 `WindowHostedCounter.app` |
| HarmonyOS HAP 构建 | **通过**，2026-07-21：包内 Stage/XComponent/NAPI template 构建出未签名 `WindowHostedCounter.hap` |
| HarmonyOS HVD | 没有在线目标（`hdc` 为空）；不声明设备运行时支持 |
| Showcase Android APK 真 Skia | **已修复**，2026-07-21：CMake plain/PRIVATE 混用和仅 CXX Skia flags；`artifacts/android/showcase.apk` 中 `moonbit_skia_available` 返回 1 |
| Showcase HarmonyOS HAP 真 Skia | **已修复**，2026-07-21：`build_harmonyos` 解析 Skia rsp 到 CMake；`artifacts/harmonyos/showcase.hap` 中 `moonbit_skia_available` 返回 1 |

### 黑屏排查（Android / HarmonyOS）

应用启动后 Surface 仍然黑屏、但 iOS 可以显示 UI 时：

1. 检查打包的 `.so`：`objdump -d libwindow_*.so | grep -A2 moonbit_skia_available`。
   - `mov w0, wzr`（返回 0）表示仅链接了 stub Skia；不要使用
     `--fallback-skia` 重新构建，并确认 CMake 应用了 rsp flags。
   - `mov w0, #0x1` 表示链接了真 Skia；接着检查 HostCmd 的 Surface attach /
     present 日志。
2. Android CMake 必须一致地使用关键字形式
   `target_link_libraries(... PRIVATE ...)`，避免 Skia link flags 被拒绝。
3. Skia 编译 rsp（`-std=c++17`、`-DMOUI_SKIA_HAS_SKIA` 等）只能用于 CXX：
   `$<$<COMPILE_LANGUAGE:CXX>:...>`，不能用于 C 源码。
4. HarmonyOS 的真实路径不能强制设置 `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1`；应将
   `MBW_SKIA_CXX_RSP` / `MBW_SKIA_LINK_RSP` 传给 CMake。

## 非目标

- 声称未经验证的 IME、剪贴板、辅助功能或 platform-view 支持
- 在没有匹配宿主截图的情况下声称 product_class 已提升

## 打包（仅 window templates）

```sh
export JAVA_HOME="$(/usr/libexec/java_home -v 25 2>/dev/null || /usr/libexec/java_home -v 17)"
export MOONBIT_NEW_NATIVE=0
export MOUI_SKIA_DISABLE_PREBUILD_SKIA=1
bash scripts/build-window-hosted-android-apk.sh
# 可选 AVD：使用包含 system-images host 的 ANDROID_SDK_ROOT 启动 moui_api34
adb install -r artifacts/window-hosted-android/app-debug.apk
adb shell am start -n dev.wzzc.window.hosted.counter/dev.wzzc.window.template.HostedActivity

bash scripts/build-window-hosted-ios-sim-app.sh

export HARMONYOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
bash scripts/build-window-hosted-harmonyos-hap.sh
```
