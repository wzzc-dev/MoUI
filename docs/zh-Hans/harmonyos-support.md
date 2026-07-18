# HarmonyOS 支持

HarmonyOS 是 **runtime_partial** 的嵌入式 Skia 路由：managed ArkTS/XComponent shell 和 host session **可用于开发和演示**（`backend` 报告 `ready=true`、`status=runtime_partial`），并已有 first-frame 与 partial runtime evidence。在 signed-device full L3 smoke 与 presenter/GPU promotion 补齐剩余缺口之前，它**不是**产品完整状态。

Native XComponent callbacks 是 surface lifecycle、pointer、resize 和 detach 的唯一来源。ArkTS 拥有 `displaySync`、transparent IME proxy、pasteboard、accessibility overlays 和 packaging；MoUI 拥有 runtime session 与 Skia renderer provider contracts。

## 所有权

- `moui/backend/harmonyos` 围绕 `HarmonyOsRuntimeSession` 暴露 platform-neutral embedded-session host contract。
- `moui/backend/harmonyos/skia` 包装 `moui/render/skia`，并将复制的 RGBA frames present 到 HarmonyOS XComponent native-window handle。
- `examples/harmonyos_demo/app` 拥有 platform-neutral TEA demo UI。
- `examples/harmonyos_demo/harmonyos_skia` 拥有 HarmonyOS shell 使用的 MoonBit native exports。
- `moui/mobile/harmonyos` 拥有规范 ArkTS Stage Ability/XComponent managed shell、generated plugin registry、fixed-ABI NAPI bridge，以及随 `wzzc-dev/moui` 包发布的 CMake template。

最低兼容 SDK 是 API 20。低于 native slop 的 touch movement 仍是 pointer input。跨过 slop 会发送一个 pointer Cancel，随后发送 Scroll Begin/Move；Scroll End/Cancel 会抑制 Pointer Up。已移除的 ArkTS `.onTouch` path 不得重新引入。
- `examples/harmonyos_demo/harmonyos_app` 是显式 Release N app-owned project fixture。正常 builds 会在 `artifacts/` 下 stage canonical shell。

## Skia Artifact

第一条 HarmonyOS 路由使用 locked `wzzc-dev/skia` release asset：

```sh
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic
```

pinned release tag 为 `dev-fcb9c18e54`；Release arm64 dynamic package 是 `Skia-dev-fcb9c18e54-harmonyos-Release-arm64-shared.zip`，SHA256 为 `55c050fec9da3468c56022b7188cb133ca476c4c90d9ce1aa67d31f22f374aa1`。

如果 SDK、ohpm 或 Skia release downloads 在受限网络上失败，请为该机器配置合适的 system 或 shell proxy。fetch helper 遵循标准 `https_proxy`、`http_proxy` 和 `all_proxy` 环境变量。不要将机器本地 proxy 地址提交到仓库 docs 或 scripts。

## Toolchain 设置

使用官方 DevEco Studio 发行版安装 HarmonyOS/OpenHarmony 工具。本仓库不会安装或 vend SDK、emulator、Hvigor 或 ohpm。

1. 从 Huawei Developer downloads 安装 DevEco Studio。
2. 打开 DevEco Studio，用 SDK Manager 安装 HarmonyOS/OpenHarmony SDK。安装与目标 emulator 或 device 兼容的 API level。
3. 确保 SDK 包含 native development components。非 fallback build 必须能在 SDK root 下找到 `native/build/cmake/ohos.toolchain.cmake`。
4. 确保已安装 DevEco command-line tools：
   - SDK `toolchains` 目录下的 `hdc`，用于 install、launch、screenshot 和 file transfer。
   - DevEco Studio `tools/hvigor/bin` 目录下的 `hvigorw`，用于真实 HAP packaging。
   - DevEco Studio `tools/ohpm/bin` 目录下的 `ohpm`，用于 project dependency installation。
5. 安装仓库级前置依赖，并确保在 `PATH` 上可用：`moon`、`node`、`cmake` 和 `zip`。`ninja` 是可选项；build helper 会在可用时使用它。
6. 确保 `MOON_HOME` 指向包含 `lib/runtime.c` 和 `include/moonbit.h` 的 MoonBit 安装。默认值为 `$HOME/.moon`。

使用 `HARMONYOS_SDK_HOME` 作为规范 SDK 环境变量。仅为现有本地设置将 `OHOS_SDK_HOME` 作为 fallback：

```sh
export HARMONYOS_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony"
export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"

# export HARMONYOS_SDK_HOME=/path/to/DevEco/sdk/default/openharmony
# export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"

test -f "$HARMONYOS_SDK_HOME/native/build/cmake/ohos.toolchain.cmake" && echo ok
hdc version
cmake --version
moon version
node --version
```

对于非标准 DevEco layouts，显式传入路径：

```sh
scripts/build-harmonyos-demo-app.sh \
  --sdk-home /path/to/openharmony-sdk \
  --hvigorw /path/to/hvigorw \
  --ohpm /path/to/ohpm
```

脚本会自动检测常见 macOS DevEco Studio 位置，但这些路径只是便利项，不是项目要求。

## 本地命令

普通 package 与 shell validation 使用 fallback checks：

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/harmonyos --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/harmonyos/skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/harmonyos_demo/harmonyos_skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/harmonyos_skia --target native
bash -n scripts/build-harmonyos-demo-app.sh
bash -n scripts/build-showcase-harmonyos-hap.sh
scripts/build-harmonyos-demo-app.sh --fallback-skia
scripts/build-component-gallery-harmonyos-hap.sh --fallback-skia
```

Managed external apps 只保留 `mobile.json` 和 MoonBit entrypoint，然后调用：

```sh
moui/scripts/mobile/build-harmonyos-hap.sh --app <id> \
  --app-config mobile.json
```

仅当 application requirements 超出 managed plugin contract 时，才使用 `moui mobile eject harmonyos --output harmonyos_app`。后续 builds 必须传入 `--ejected-shell --harmonyos-project harmonyos_app`；MoUI 会验证 lock versions，但绝不会覆盖该项目。

非 fallback native builds 使用 HarmonyOS/OpenHarmony SDK。Build helper 优先使用 `HARMONYOS_SDK_HOME`，并将 `OHOS_SDK_HOME` 作为 fallback：

```sh
HARMONYOS_SDK_HOME=/path/to/HarmonyOS/Sdk \
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic \
scripts/build-harmonyos-demo-app.sh
```

用同一路由构建 Showcase：

```sh
HARMONYOS_SDK_HOME=/path/to/HarmonyOS/Sdk \
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic \
scripts/build-component-gallery-harmonyos-hap.sh
```

`--fallback-skia` 只验证 MoonBit C generation、native glue compilation 和 staged HAP layout。它不能证明 renderer 或 platform runtime support。

所有 HarmonyOS mobile build wrappers 也接受 `--renderer auto|skia-gpu|skia-raster`。对真实 Skia 包，`auto` 和 `skia-gpu` 选择 GPU（`gpuPromoted: true`）；fallback-Skia 和显式 `skia-raster` 保持 CPU presenter。

## 模拟器设置与 Smoke

通过 DevEco Studio 安装模拟器，而不是通过本仓库：

1. 打开 DevEco Studio 的 Device Manager。
2. 下载所需 emulator runtime/image，并创建与 build 所用 SDK API level 匹配的 virtual device。
3. 从 Device Manager 启动 emulator。
4. 确认 command-line bridge 可以看到它：

```sh
HDC="$HARMONYOS_SDK_HOME/toolchains/hdc"
"$HDC" list targets
```

如果在 macOS 上直接使用 DevEco emulator CLI，请将 `-path` 传为包含具名 device folder 的父目录，而不是 device folder 本身：

```sh
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
HVD="MateBook Pro"
HVD_ROOT="$HOME/.Huawei/Emulator/deployed"
IMAGE_ROOT="$HOME/Library/Huawei/Sdk"

"$EMU" -hvd "$HVD" -path "$HVD_ROOT" -imageRoot "$IMAGE_ROOT"
```

使用真实 HarmonyOS Skia artifact 构建非 fallback HAP：

```sh
HARMONYOS_SDK_HOME=/path/to/DevEco/sdk/default/openharmony \
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic \
scripts/build-harmonyos-demo-app.sh
```

安装、启动并截屏：

```sh
export HARMONYOS_SDK_HOME=/path/to/DevEco/sdk/default/openharmony
# export HARMONYOS_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony"
export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"

HDC="$HARMONYOS_SDK_HOME/toolchains/hdc"
HAP=artifacts/harmonyos/harmonyos_demo/MoUIHarmonyOSDemo.hap

hdc version
"$HDC" install -r "$HAP"
"$HDC" shell aa start -a EntryAbility -b dev.wzzc.moui.harmonyosdemo -m entry
"$HDC" shell snapshot_display -f /data/local/tmp/moui-harmonyos-demo.jpeg
"$HDC" file recv \
  /data/local/tmp/moui-harmonyos-demo.jpeg \
  artifacts/harmonyos/harmonyos_demo/moui-harmonyos-demo.jpeg
```

收集证据后从 Device Manager 停止 emulator。如果直接使用 DevEco emulator CLI，请使用该机器上配置的 virtual device name 与 deployed/image roots。

## Runtime Evidence Boundary

三层证据保持分离：**product GPU default**（source/`auto`）、**mobile runtime smoke** 与 **seven-gate GPU promotion claim**。

| 层级 | 当前状态（2026-07-15） | 路径 / 说明 |
| --- | --- | --- |
| Product GPU default | `auto` -> `SkiaGpuNative` / `egl-gpu` when available | Source `gpu_promoted=true`；用 `--renderer auto` 重新构建 HAP |
| Packaging (L1) | 带 GPU flags 的非 fallback Showcase HAP | `artifacts/harmonyos/showcase/mobile-build.json` -> `selected=skia-gpu`，`gpuPromoted=true` |
| First-frame pixels | 历史 Component Gallery device + **emulator smoke screenshots** | `resource/screenshots/harmonyos-componentgallery.png`；`artifacts/mobile-runtime/harmonyos/component_gallery/` 下的旧 smoke PNGs 不是 Showcase evidence |
| Mobile runtime smoke (L2) | Showcase managed-shell evidence 待补；commercial hosts 需要 Huawei/DevEco signing material | Service-smoke + attach/resize log paths 已在 tree 中（`Index.ets`、NAPI attach markers、`record-mobile-runtime-smoke.mjs`）。Commercial MateBook-class installs 会拒绝 unsigned / OpenHarmony-community HAPs（`9568320` / `9568257`）。设置 `MOUI_HARMONYOS_SIGNING_CONFIG(_FILE)` 并运行 `scripts/harmonyos-mobile-runtime-evidence.sh` 获取 `--require-passed`。 |
| GPU promotion claim (L3) | 仅 scaffold | `artifacts/gpu-promotion/harmonyos/scaffold-latest/`（`gpuPromoted=false`，不是 claim） |

### GPU feasibility proof（L1 + L2，emulator 2026-07-15）

DevEco **MateBook Pro** HVD（`hdc` target `127.0.0.1:5557`）。重新构建 + smoke：

```sh
export HARMONYOS_SDK_HOME="${HARMONYOS_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony}"
export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"
# Start HVD via Device Manager or:
# Emulator -hvd "MateBook Pro" -path "$HOME/.Huawei/Emulator/deployed" -imageRoot "$HOME/Library/Huawei/Sdk"
hdc list targets

scripts/build-mobile-harmonyos-hap.sh --app showcase --renderer auto
node scripts/record-mobile-runtime-smoke.mjs \
  --platform harmonyos --app showcase --device 127.0.0.1:5557
node scripts/validate-mobile-runtime-manifest.mjs \
  artifacts/mobile-runtime/harmonyos/showcase/mobile-runtime-smoke.json
```

**必需 GPU log markers**（`hilog -T MoUIHarmony` / `runtime-stream.log`）：

```text
moui-mobile renderer configure requested=auto ok=1 status={
  "platform":"harmonyos","requested":"auto",
  "selected":"skia-gpu-native","surfaceRoute":"egl-gpu",
  "gpuAvailable":true,"gpuPromoted":true,"fallbackReason":null}
egl present ok=1 swap=1 w=… h=…
```

**True GPU direct present** = configure GPU **且**来自 `eglSwapBuffers`（HostGpuPresentTarget）的 `egl present ok=1`。这**不是** CPU path `present flushed native window`（仅 sticky raster recovery）。

**已在 HVD 证明（2026-07-15）：** lifecycle attach、nonblank UI、a11y tree、async-image ready、clean process survival、**EGL GPU selected**，以及 **`egl present ok=1` host-gpu direct present**（成功路径上无 sticky raster / 无 `present flushed`）。  
**full `passed` 仍待补：** 使用 Huawei signing material 在 commercial/device 上 install，然后补齐 detach、resize、representative input/scroll、clipboard round-trip、a11y focus/action、`realDeviceSigning`。Shell-side service-smoke 与 attach/resize log markers 已在 tree 中；当前 commercial-host blocker 是 HAP signature trust（`9568320` unsigned / `9568257` community PKCS7）。

注意：当前 images 上的 `snapshot_display` 需要 **`.jpeg`** remote paths；recorder 会转换为 PNG 供 `decodePng8` 使用。

在 matching device 或 emulator run 也记录以下内容之前，不要将 HarmonyOS support 标记为 fully passed：

- Stage Ability 和 XComponent lifecycle 创建、resize、render 并 dispose `HarmonyOsRuntimeSession`（通过 runtime log verified）。
- Pointer/tap input 到达 standalone demo 并改变 UI state。
- Resize 与 lifecycle events 生成新 frame 且不崩溃。

source route 现在包括 transparent `TextInput` composition/selection、text 和 ArrayBuffer image pasteboard handling、API 20 accessibility virtual overlays，以及 Showcase service-probe smoke。在 commercial hosts 上安装 runtime 仍需要该 bundle 的 Huawei/DevEco signing material。passed manifest 必须记录 IME state/edit、clipboard completion、accessibility tree/focus/action、async image、application detach，以及 before/after pixels：

```sh
# Provide DevEco debug/release material for this bundle (commercial hosts):
# export MOUI_HARMONYOS_SIGNING_CONFIG_FILE=/path/to/signingConfigs.json
export HARMONYOS_SDK_HOME="${HARMONYOS_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony}"
export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"
hdc list targets
scripts/harmonyos-mobile-runtime-evidence.sh
# or the lower-level pair:
scripts/build-mobile-harmonyos-hap.sh --app showcase --renderer auto
node scripts/record-mobile-runtime-smoke.mjs --platform harmonyos --app showcase --device <hdc-target> --require-passed
```

Showcase 直接打开 `platform/mobile-service-probe`。用它验证 transparent TextInput composition、system pasteboard、accessibility focus/activate、portrait-landscape-portrait resize、scrolling 和 async-image loading/ready。Native bridge 会记录 resize width 与 height，让 recorder 能拒绝重复的 initial XComponent callback。运行时传入 `--device <hdc-target>`；当已安装的 `uitest` 工具无法驱动平台 accessibility focus model 时，screen reader interaction 保持手动。

在晋升 image clipboard support 前，physical-device pass 仍必须通过另一个 app round-trip PNG，并且必须完成上述 pending service observations，才能达到 `status=passed`。

产品 GPU path 是通过主线程 `HostGpuPresentTarget`（`eglCreateWindowSurface` + `eglSwapBuffers`）在 `OHNativeWindow`（Ganesh GL）上的 EGL/GLES。Emulator L2 证明了 `surfaceRoute=egl-gpu`、`gpuAvailable=true` 和 **`egl present ok=1` direct present**。Raster presenter 只保留给显式 `skia-raster`，以及 present/surface failures 后的 sticky recovery。
