# Component Gallery HarmonyOS

> Release N legacy fixture: normal Component Gallery builds now stage the
> framework-owned canonical shell from `moui/mobile/harmonyos/template` and do
> not consume this app-owned project. Validate this project only through
> `moui/mobile/harmonyos/tests/build-legacy-fixture.sh`.

This directory contains the app-owned Stage Ability/XComponent shell for the
experimental Component Gallery HarmonyOS route. The shell uses the reusable
ArkTS, NAPI, and CMake support from `moui/mobile/harmonyos`; app metadata and
native export names come from `examples/component_gallery/mobile.json`.

The route currently has non-fallback first-frame evidence: Component Gallery
has launched on a HarmonyOS device with a visibly nonblank Skia frame and the
real `libskia.so` loaded. Full input, resize, lifecycle, and platform-service
smoke evidence is still pending. See
[`docs/harmonyos-support.md`](../../../docs/harmonyos-support.md) for the support
boundary and locked Skia artifact details.

Run all commands below from the repository root.

## 1. Install The Toolchain

Install DevEco Studio and use its SDK Manager and Device Manager to install:

1. A HarmonyOS/OpenHarmony SDK compatible with the target device or emulator.
2. Native development components. The SDK must contain
   `native/build/cmake/ohos.toolchain.cmake`.
3. `hdc` in the SDK `toolchains` directory.
4. DevEco's `hvigorw` and `ohpm` command-line tools.
5. A matching emulator image if no physical device is available.

The repository also expects `moon`, `node`, `cmake`, and `zip` on `PATH`.
`ninja` is optional. `MOON_HOME` must point to a MoonBit installation containing
`lib/runtime.c` and `include/moonbit.h`; it defaults to `$HOME/.moon`.

## 2. Configure And Verify The Environment

Use `HARMONYOS_SDK_HOME` as the canonical SDK variable. Point it at the SDK root
that contains the native toolchain and `toolchains/hdc`:

```sh
export HARMONYOS_SDK_HOME=/path/to/DevEco/sdk/default/openharmony
# Common macOS location:
# export HARMONYOS_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony"
export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"

test -f "$HARMONYOS_SDK_HOME/native/build/cmake/ohos.toolchain.cmake" && echo ok
hdc version
cmake --version
moon version
node --version
```

`OHOS_SDK_HOME` is accepted as a compatibility fallback. The build helper
auto-detects common macOS DevEco Studio locations. For a non-standard layout,
pass the tools explicitly:

```sh
scripts/build-component-gallery-harmonyos-hap.sh \
  --sdk-home /path/to/openharmony-sdk \
  --hvigorw /path/to/hvigorw \
  --ohpm /path/to/ohpm
```

## 3. Run Focused Checks

Check the shared app and HarmonyOS native entrypoint without downloading or
linking the real Skia artifact:

```sh
moon test examples/component_gallery/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  moon check examples/component_gallery/harmonyos --target native
bash -n scripts/build-mobile-harmonyos-hap.sh
bash -n scripts/build-component-gallery-harmonyos-hap.sh
```

## 4. Run A Packaging-Only Build

Use the fallback build for a fast validation of MoonBit C generation, native
glue compilation, native-stub compilation, and staged project layout:

```sh
scripts/build-component-gallery-harmonyos-hap.sh --fallback-skia
```

The default output is:

```text
artifacts/harmonyos/component_gallery/ComponentGallery.hap
```

This fallback file is a staged archive, not renderer or runtime evidence. Do
not use it to claim real Skia support or a successful device installation.

## 5. Build A Real HAP

Build without `--fallback-skia` to resolve the locked arm64 HarmonyOS Skia
artifact and package an installable HAP through `ohpm` and Hvigor:

```sh
MOUI_SKIA_PLATFORM=harmonyos \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=dynamic \
scripts/build-component-gallery-harmonyos-hap.sh
```

The output remains:

```text
artifacts/harmonyos/component_gallery/ComponentGallery.hap
```

If SDK, `ohpm`, or Skia downloads fail on a restricted network, configure the
machine's standard `https_proxy`, `http_proxy`, or `all_proxy` environment
variable and retry. Do not add a machine-local proxy address to repository
files.

## 6. Start A Device Or Emulator

For an emulator, open DevEco Studio's Device Manager, create a virtual device
whose API level matches the installed SDK, and start it. For a physical device,
enable developer access and connect it using the normal DevEco workflow.

Verify that `hdc` can see exactly the target you intend to use:

```sh
HDC="$HARMONYOS_SDK_HOME/toolchains/hdc"
"$HDC" list targets
```

If no target is listed, fix the device/emulator connection before continuing.

## 7. Install And Launch Component Gallery

Install the non-fallback HAP and start its entry ability:

```sh
HDC="$HARMONYOS_SDK_HOME/toolchains/hdc"
HAP=artifacts/harmonyos/component_gallery/ComponentGallery.hap

"$HDC" install -r "$HAP"
"$HDC" shell aa start \
  -a EntryAbility \
  -b dev.wzzc.moui.componentgallery \
  -m entry
```

The expected first screen is the Component Gallery rendered inside the
full-screen XComponent surface.

## 8. Inspect Runtime Logs

In a second terminal, filter the device log by the shell/native bridge tag:

```sh
HDC="$HARMONYOS_SDK_HOME/toolchains/hdc"
"$HDC" shell hilog | rg MoUIHarmony
```

Launch the app, tap controls, rotate or resize the target where supported, and
then close the app. Useful successful markers include:

```text
window stage create
content loaded
XComponent callbacks registered
XComponent surface created ... attach=1 render=1
XComponent touch ... dispatch=1 render=1
XComponent surface changed ... resize=1 render=1
XComponent surface destroyed detach=1
```

Stop the live log command with `Ctrl-C` after collecting the observations.
Absence of a marker must be recorded as pending or investigated; a successful
build alone does not prove that runtime behavior.

## 9. Capture First-Frame Evidence

After confirming the frame is visible, capture and retrieve a screenshot:

```sh
HDC="$HARMONYOS_SDK_HOME/toolchains/hdc"
REMOTE_SCREENSHOT=/data/local/tmp/moui-component-gallery.jpeg
LOCAL_SCREENSHOT=artifacts/harmonyos/component_gallery/moui-component-gallery.jpeg

"$HDC" shell snapshot_display -f "$REMOTE_SCREENSHOT"
"$HDC" file recv "$REMOTE_SCREENSHOT" "$LOCAL_SCREENSHOT"
```

Inspect the retrieved image and retain the matching build and runtime logs when
using it as evidence. Files under `artifacts/` are disposable and must not be
committed.

## Evidence Boundary

A non-fallback HAP plus a nonblank screenshot proves only the named build and
first frame. A complete HarmonyOS runtime claim also needs matching-host
observations for Stage Ability/XComponent lifecycle, pointer and scroll input,
resize/re-render, clean disposal, and real `libskia.so` loading. IME, clipboard,
accessibility, async image, native WebView, and deeper platform services remain
pending unless they have separate implementation and smoke evidence.
