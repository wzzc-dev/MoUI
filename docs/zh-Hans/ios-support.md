# iOS 支持

iOS 使用**嵌入运行时后端**路径，目前状态为 **experimental**（product_class `experimental`，`ready=false`）：代码路径可编译且 host-sim tests 通过，但在匹配模拟器/设备证据落地前，不做任何开发/演示可用性或产品承诺。
`wzzc-dev/window/ios` 拥有 UIKit 生命周期、Surface 与输入回调；
`moui/backend/ios` 组装 MoUI runtime session，`moui_skia_renderer`
提供呈现器。

## 入口

| 部件 | 位置 |
|---|---|
| App 逻辑 | `examples/<app>/app` |
| 移动端元数据 | `examples/<app>/moui.mobile.json` |
| MoonBit 入口 | `examples/<app>/ios_window_hosted` |
| iOS host 模板 | `wzzc-dev/window/ios/template` |
| MoUI 嵌入运行时后端 | `moui/backend/ios/window_hosted.mbt` |

入口创建 `IosEmbeddedRuntimeBackend` 并调用 `window/ios::EventLoop.run_app`。
UIKit 生命周期、Surface 与触摸事件只能通过这条路径进入应用。

## 工具链

- Xcode 15.4 或更新版本
- Swift 5 或更新版本
- iOS deployment target 15.0 或更新版本
- 模板 Info.plist 保留 `UILaunchScreen` 与
  `UIApplicationSupportsMultipleScenes=false`

## Xcode 与模拟器设置

从 Apple 安装 Xcode，选择当前 developer directory，并在构建前确认 Simulator SDK：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

通过 Xcode 的 Devices and Simulators 创建或选择模拟器，再在运行应用前启动它。使用
UDID，不要假定某个设备名称一定存在：

```sh
xcrun simctl list devices available
xcrun simctl boot <simulator-udid>
xcrun simctl bootstatus <simulator-udid> -b
open -a Simulator
```

构建前运行 `moui doctor --platform ios`。

## 构建与运行

```sh
moon check examples/showcase/ios_window_hosted --target native
moui build ios showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui run ios showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
```

`--prepare-only` 在生成输入后停止。`--fallback-skia` 只用于打包诊断，不能提升
iOS runtime readiness。

## 验证与证据

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/ios --target native
```

模拟器或设备证据必须包含首帧、触摸/输入、Surface detach/recreate、IME、剪贴板、
无障碍和异步图片。仅在匹配 host 证据验证实际 presenter route 后更新
`checks/platforms/ios.json`。

## 状态

该路径可编译并可用于模板集成，但仍为 **experimental**（product_class `experimental`，`ready=false`）。升级条件见
`docs/platform-readiness-declaration.md` 与 `docs/window-hosted-moui.md`。
