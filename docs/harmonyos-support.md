# HarmonyOS Support

HarmonyOS support is currently an experimental embedded Skia scaffold. It is
parallel to the Android and iOS embedded-session routes: the platform shell owns
lifecycle, native surface handle acquisition, input forwarding, and packaging;
MoUI owns the runtime session and Skia renderer provider contracts.

## Ownership

- `moui/backend/harmonyos` exposes the platform-neutral embedded-session host
  contract around `HarmonyOsRuntimeSession`.
- `moui/backend/harmonyos/skia` wraps `moui/render/skia` and presents copied
  RGBA frames to a HarmonyOS XComponent native-window handle.
- `examples/harmonyos_demo/app` owns the platform-neutral TEA demo UI.
- `examples/harmonyos_demo/harmonyos_skia` owns the MoonBit native exports used
  by the HarmonyOS shell.
- `moui/mobile/harmonyos` owns the reusable ArkTS Stage Ability/XComponent
  template plus shared NAPI/CMake native glue published with the `wzzc-dev/moui`
  package.
- `examples/harmonyos_demo/harmonyos_app` owns the app-specific HarmonyOS
  project metadata and shell files for the standalone demo.

## Skia Artifact

The first HarmonyOS route uses the locked `wzzc-dev/skia` release asset:

```sh
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic
```

The pinned release tag is `dev-fcb9c18e54`; the Release arm64 dynamic package is
`Skia-dev-fcb9c18e54-harmonyos-Release-arm64-shared.zip` with SHA256
`55c050fec9da3468c56022b7188cb133ca476c4c90d9ce1aa67d31f22f374aa1`.

If SDK, ohpm, or Skia release downloads fail on a restricted network, configure
an appropriate system or shell proxy for that machine. The fetch helper honors
standard `https_proxy`, `http_proxy`, and `all_proxy` environment variables.
Do not commit machine-local proxy addresses to repository docs or scripts.

## Toolchain Setup

Install the HarmonyOS/OpenHarmony tools with the official DevEco Studio
distribution. This repository does not install or vendor the SDK, emulator,
Hvigor, or ohpm.

1. Install DevEco Studio from Huawei Developer downloads.
2. Open DevEco Studio and install the HarmonyOS/OpenHarmony SDK with SDK
   Manager. Install an API level compatible with the target emulator or device.
3. Ensure the SDK includes the native development components. The non-fallback
   build must be able to find `native/build/cmake/ohos.toolchain.cmake` under
   the SDK root.
4. Ensure DevEco command-line tools are installed:
   - `hdc` under the SDK `toolchains` directory for install, launch, screenshot,
     and file transfer.
   - `hvigorw` under DevEco Studio's `tools/hvigor/bin` directory for real HAP
     packaging.
   - `ohpm` under DevEco Studio's `tools/ohpm/bin` directory for project
     dependency installation.
5. Install repository-level prerequisites available on `PATH`: `moon`, `node`,
   `cmake`, and `zip`. `ninja` is optional; the build helper uses it when
   available.
6. Ensure `MOON_HOME` points at a MoonBit installation containing
   `lib/runtime.c` and `include/moonbit.h`. The default is `$HOME/.moon`.

Use `HARMONYOS_SDK_HOME` as the canonical SDK environment variable. Set
`OHOS_SDK_HOME` only as a fallback for existing local setups:

```sh
export HARMONYOS_SDK_HOME=/path/to/DevEco/sdk/default/openharmony
export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"

test -f "$HARMONYOS_SDK_HOME/native/build/cmake/ohos.toolchain.cmake" && echo ok
hdc version
cmake --version
moon version
node --version
```

For non-standard DevEco layouts, pass paths explicitly:

```sh
scripts/build-harmonyos-demo-app.sh \
  --sdk-home /path/to/openharmony-sdk \
  --hvigorw /path/to/hvigorw \
  --ohpm /path/to/ohpm
```

The script auto-detects common macOS DevEco Studio locations, but those paths
are conveniences only. They are not project requirements.

## Local Commands

Use fallback checks for ordinary package and shell validation:

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/harmonyos --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/harmonyos/skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/harmonyos_demo/harmonyos_skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/component_gallery/harmonyos --target native
bash -n scripts/build-harmonyos-demo-app.sh
bash -n scripts/build-component-gallery-harmonyos-hap.sh
scripts/build-harmonyos-demo-app.sh --fallback-skia
scripts/build-component-gallery-harmonyos-hap.sh --fallback-skia
```

External apps can copy `moui/mobile/harmonyos/template` as `harmonyos_app/` and
invoke:

```sh
moui/scripts/mobile/build-harmonyos-hap.sh --app <id> \
  --harmonyos-project harmonyos_app
```

Use a HarmonyOS/OpenHarmony SDK for non-fallback native builds. The build helper
uses `HARMONYOS_SDK_HOME` first and `OHOS_SDK_HOME` as a fallback:

```sh
HARMONYOS_SDK_HOME=/path/to/HarmonyOS/Sdk \
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic \
scripts/build-harmonyos-demo-app.sh
```

Build Component Gallery with the same route:

```sh
HARMONYOS_SDK_HOME=/path/to/HarmonyOS/Sdk \
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic \
scripts/build-component-gallery-harmonyos-hap.sh
```

`--fallback-skia` validates MoonBit C generation, native glue compilation, and
staged HAP layout only. It does not prove renderer or platform runtime support.

## Emulator Setup And Smoke

Install the emulator through DevEco Studio rather than this repository:

1. Open DevEco Studio's Device Manager.
2. Download the required emulator runtime/image and create a virtual device
   matching the SDK API level used for the build.
3. Start the emulator from Device Manager.
4. Confirm the command-line bridge can see it:

```sh
HDC="$HARMONYOS_SDK_HOME/toolchains/hdc"
"$HDC" list targets
```

If using the DevEco emulator CLI directly on macOS, pass `-path` as the parent
directory containing the named device folder, not the device folder itself:

```sh
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
HVD="MateBook Pro"
HVD_ROOT="$HOME/.Huawei/Emulator/deployed"
IMAGE_ROOT="$HOME/Library/Huawei/Sdk"

"$EMU" -hvd "$HVD" -path "$HVD_ROOT" -imageRoot "$IMAGE_ROOT"
```

Build a non-fallback HAP with the real HarmonyOS Skia artifact:

```sh
HARMONYOS_SDK_HOME=/path/to/DevEco/sdk/default/openharmony \
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic \
scripts/build-harmonyos-demo-app.sh
```

Install, launch, and capture a screenshot:

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

Stop the emulator from Device Manager after collecting evidence. If using the
DevEco emulator CLI directly, use the virtual device name and deployed/image
roots configured on that machine.

## Runtime Evidence Boundary

Do not mark HarmonyOS support as passed until a matching device or emulator run
records all of the following from a non-fallback build:

- Stage Ability and XComponent lifecycle create, resize, render, and dispose the
  `HarmonyOsRuntimeSession`.
- The first Skia frame is visibly nonblank.
- Pointer/tap input reaches the standalone demo and changes UI state.
- Resize and lifecycle events produce a new frame without crashing.
- The real `libskia.so` from the locked HarmonyOS release asset loads.

IME, clipboard, accessibility, async image, native WebView, and deeper platform
services remain pending unless separate implementation and matching-host smoke
evidence are recorded.
