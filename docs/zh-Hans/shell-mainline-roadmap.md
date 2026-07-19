# 移动端主线与 GPU 路线图

本文档记录 Android、iOS 和 HarmonyOS 的实现与晋升状态。Native Skia 是移动端主线。Native WGPU 仍然是诊断路由。

## 产品类别

Android、iOS 和 HarmonyOS 都是 **`runtime_partial`**，尚未达到产品完整状态，也不是“仅有未接线的实验性 glue”。

| 层级 | 状态 |
| --- | --- |
| Managed shell + embedded session | 可用于开发和演示（`backend` `ready=true`） |
| Host services（IME/clipboard/a11y channel） | 已在源码中通过 `EmbedderHostChannel` + shell adapters 接线 |
| Runtime smoke | 历史 full smoke 经常来自 **legacy** shells；managed 重新证明仍待完成；HarmonyOS 为 partial + signing |
| Product complete / GPU seven-gate claim | **尚未**声明 |

规范的 product-class 表：
[平台就绪申报](platform-readiness-declaration.md)。

## 当前状态

| 区域 | 源码中已实现 | 运行时证据 |
| --- | --- | --- |
| VSync | Android `Choreographer`、iOS `CADisplayLink`、HarmonyOS `displaySync.create()` 驱动 `frame_tick`；输入不再同步触发 present | matching-device full smoke 待补 |
| HarmonyOS input | Native XComponent 是唯一的 pointer/surface 来源；touch-slop 仲裁会在 Scroll Begin/Move 前发出 pointer Cancel，并在滚动时抑制 Pointer Up | matching-device 单击与滚动顺序证明待补 |
| IME | 共享 replace/selection 事件和 mobile IME snapshots；Android `InputConnection`、iOS UIKit text proxy、HarmonyOS transparent `TextInput` proxy | 中文组合输入、emoji/ZWJ、selection、candidate-anchor 设备证明待补 |
| Clipboard | 异步 host channel，支持 text 和 image payload；Android `ClipboardManager`/`FileProvider`、iOS `UIPasteboard`、HarmonyOS pasteboard ArrayBuffer path | 跨应用 text/PNG round-trip 证明待补 |
| Accessibility | revisioned flat semantics snapshots 与 targeted runtime action routing；三端都有原生 virtual/container nodes | tree、focus 与 action 的 screen-reader 证明待补 |
| Renderer selection | 形式化的 `SkiaGpuNative`/`HostGpuSurface` descriptor，以及 `auto`/`skia-gpu`/`skia-raster` selection；`NativeRendererSelection` 携带 `surface_route` | 产品默认：所有原生平台 `gpu_promoted=true`；`auto` 在可用时选择 GPU，显式请求或 recovery fallback 时走 raster |
| Renderer mailbox | 容量为二的 latest-wins frame mailbox，control messages 不可丢弃，拒绝过期 surface-generation；native `std::thread` 安全持有 `SkPicture` 与 POD metadata 并确认 detach | Desktop hosts 轮询 pending frame 且不重复提交；mobile sessions 在每个 VSync drain completions；matching-device stress evidence 仍待补 |
| Context-loss recovery | `moui/runtime/renderer_recovery.mbt` 中的 `RendererRecovery` 状态机（Idle -> Lost -> Recovering -> Recovered -> Idle；连续 2 次失败后终止为 `FallbackToRaster`；3-VSync deadline）；hybrid rendering 保持同一个 runtime，并将后续帧路由到 raster | Mock fallback/state-preservation tests 通过；matching-device forced-loss 与 deadline evidence 待补 |
| Direct GPU presentation | iOS/macOS Metal、Android Vulkan/GLES、HarmonyOS EGL/GLES、Windows D3D12 和 Linux Wayland Vulkan 都已有 worker-owned paths。Android GPU APK、HarmonyOS GPU HAP 和 iOS simulator GPU App 构建通过；macOS 有本地 first-frame smoke。 | Physical iOS/Android/HarmonyOS、Windows MSVC、Linux Wayland 与完整 promotion manifests 仍待补 |
| Mobile runtime smoke | Recorder 写出可选 `renderer`（当 `gpuPromoted=true` 时附带 pending `gpuPromotionEvidence` skeleton，`claimed=false`） | iOS Simulator CG Release N UIKit shell **`passed`**（Metal），canonical SwiftUI re-run 待补；Android CG **`partial`**（`vulkan-gpu` + `gpuAvailable=true`，NDK28 libc++）；HarmonyOS HVD CG **`partial`**（`egl-gpu` + `gpuAvailable=true`）。Emulator install/verify：`docs/android-support.md` / `docs/harmonyos-support.md`。 |

当 host GPU surface 可用时，`SkiaGpuNative` 是所有 native Skia 平台的产品 `auto` 默认值。`SkiaRasterNative` 仍然是显式模式和 sticky recovery fallback。iOS/macOS Metal、Android Vulkan/GLES、HarmonyOS EGL/GLES、Windows D3D12 与 Linux Wayland Vulkan 均已有 window-surface GPU paths。GPU descriptor、offscreen GPU surface 或 `PictureRecorded` worker completion 仍不能算作 direct presentation；GPU 生产路径禁止 full-frame readback 或 platform image intermediates。

三个移动端构建入口都接受 `--renderer auto|skia-gpu|skia-raster`。生成的 `shell-build.json` 和原生启动日志会记录 requested 与 selected mode。对真实 Skia 包，`auto` 和 `skia-gpu` 选择 GPU（`gpuPromoted: true`）；fallback-Skia 或显式 `skia-raster` 保持 raster。

Worker submission 与 presentation 是分离的契约。queued frame 或 `PictureRecorded` completion 不推进 first-frame 或 image-resource tracking。Providers 只计数 `Presented`；desktop event loops 会继续轮询 pending frame 而不再次记录它，Android、iOS 和 HarmonyOS 则从各自平台 VSync callbacks drain completions。Cached layers 与 platform-view pixels 都是 immutable picture 的一部分，因此终止 GPU fallback 可以在 raster 上重放相同内容，而无需重建 app state。

## Mobile Host Channel

`moui/backend/host` 拥有 `EmbedderHostChannel`、`EmbedderImeRequest`、revisioned semantics snapshots，以及 JSON update/response envelopes。Android JNI、iOS Obj-C++ 和 HarmonyOS NAPI 只负责把通用 wire contract 翻译为原生平台服务。Clipboard responses 保留 request id 与 session lifetime；dispose 之后到达的 responses 会被忽略。

`AppRuntime::dispatch_semantics_action` 会先验证当前 node 声明了所请求的 action。它按 `ElementId` 分发，而不是再次进行 screen-coordinate hit test。`SetText` 使用 `ReplaceText`；focus、activation、submit、selection、expand/collapse/dismiss 和 normalized scrolling 都复用现有 runtime/control paths。

## GPU 默认值与证据契约

当 host surface 可用时，产品 `auto` 已经在每个 native Skia 平台选择 GPU。matching-device seven-gate manifests 是声明硬件实证质量的门槛，不是启用默认值的门槛。强清单仍应证明以下所有内容：

- direct window-surface presentation，且没有 full-frame CPU readback、RGBA copy、Bitmap、CGImage、UIImage 或 PixelMap intermediates；
- GPU context、surface 与持久 GPU resources 由 renderer-thread 拥有，UI/runtime state 保持在 runtime thread；
- 容量为二的 latest-wins mailbox，resize、detach、context-loss 和 shutdown controls 永不丢弃；
- warm-up 后 p95 frame time 在 60 Hz 下不超过 16.7 ms、120 Hz 下不超过 8.3 ms，十分钟内 dropped frames 低于 1%，input-to-present p95 不大于两个 VSync intervals；
- GPU memory 有界且无单调增长，100 次 surface recreation 与 foreground/background cycles，以及三次 VSync 内完成 context-loss recovery；
- repeated GPU recovery failure 后自动 raster fallback，并保留现有 `AppRuntime` state。

证据收集的 backend 顺序仍为 iOS Metal、Android Vulkan（带 GLES fallback），再到 HarmonyOS EGL/GLES，随后可选 Vulkan。Worker-owned source 已接通并成为产品默认值；不完整 manifests 只表示 matching-device quality claims 仍待补。

Desktop 和 Web 使用 `docs/gpu-promotion-manifest.example.json` 展示的共享 schema。用以下命令校验 pending 或 diagnostic manifest：

```sh
node scripts/validate-gpu-promotion-manifest.mjs <manifest.json>
```

Release promotion 必须使用 `--require-passed`。通用 validator 覆盖 macOS Metal、Windows D3D12、Linux Wayland Vulkan、Android Vulkan/EGL、iOS Metal、HarmonyOS EGL/GLES 和 WebGPU，包括 60/120 Hz 阈值、600 秒运行、100 次 recreation/lifecycle cycles、provenance、recovery 和 fallback。它不会创建证据；matching-hardware runners 必须提供 manifest。

## Runtime Smoke

`scripts/record-shell-runtime-smoke.mjs` 支持 `android`、`ios` 和 `harmonyos`。它记录 before/after screenshots、比较 changed pixels，并要求 application receipt logs。单独成功执行 input injection command 不能通过。Lifecycle detach 必须来自 app callback，而不是成功 force-stop/terminate command。

Manifest status 有意保持三态：`passed` 表示每个 required observation 都已被证明，`partial` 表示该 run 产生了有用的 matching-host evidence 但仍有 pending/no observations，`failed` 表示该 run 没有产生可用 runtime evidence。`--require-passed` 只接受 `passed`。

Showcase 在移动端直接打开其 Platform workspace 的 `Mobile Service Probe` 页面。该页面具有稳定的 text-field 与 action labels、可见的 edit/action counters、viewport dimensions、deferred PNG 和 scrollable tail content。Recorder 使用这些控件来演练 IME edits、system text-clipboard write/read round trip、activation、rotation/resize、scrolling，以及 async-image second-frame completion。Clipboard 只有在 `write-text` 与 `read-text` completion logs 都出现后才通过。Resize 只有在 app 记录两个不同 physical surface sizes 后才通过，因此重复的初始 surface callback 不足以通过。Portrait layouts 保持 Probe 为默认，同时显示紧凑的 `Browse all components` 入口，可返回正常的可搜索 component index；service probe 不是 navigation dead end。

iOS Simulator input 使用 `idb`/`idb-companion`，因为原生 `simctl` 不提供 tap 或 swipe injection。Recorder 等待 accessibility tree，按 frame 点击 enabled button，将日志过滤到当前 launch PID，并使用 HOME event 验证 background detach。iOS templates 声明 `UILaunchScreen`，防止 legacy `320x480` compatibility scaling。

Passed evidence 还要求 IME state 与 edit logs、clipboard round trip、accessibility tree/focus/action logs，以及 async-image loading 和 ready observations。只有在目标上真实平台 screen reader 已安装并启用时才使用 `--assistive-tech`；普通 coordinate taps 不能算作 accessibility action。
HarmonyOS 使用 `hdc`；HarmonyOS Demo 和 Component Gallery 的 release/manual suites 已注册在 `smoke/gates.json`。

## 兼容性下限

- Android：minSdk 23；Vulkan preference 从 API 24 开始，API 23 使用 GLES。
- iOS：iOS 15。
- HarmonyOS：native accessibility baseline 兼容 SDK API 20。
