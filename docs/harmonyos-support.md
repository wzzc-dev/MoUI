# HarmonyOS Support

HarmonyOS uses the **embedded runtime backend** route and is currently
**experimental** (product_class `experimental`, `ready=false`): the code paths
compile and host-sim tests pass, but no development/demonstration usability or
product commitment is made without signed-device evidence. `wzzc-dev/window/harmonyos` owns the Stage Ability,
XComponent surface, lifecycle, and input queue; `moui/backend/harmonyos`
adapts those callbacks into the MoUI runtime session.

## Entry Points

| Piece | Location |
|---|---|
| App logic | `examples/<app>/app` |
| Mobile metadata | `examples/<app>/moui.mobile.json` |
| MoonBit entrypoint | `examples/<app>/harmonyos_window_hosted` |
| HarmonyOS host template | `wzzc-dev/window/harmonyos/template` |
| MoUI embedded runtime backend | `moui/backend/harmonyos/window_hosted.mbt` |

XComponent callbacks are the sole source for surface, pointer, resize, and
detach events. The hosted event loop forwards them to
`HarmonyOSEmbeddedRuntimeBackend`; do not inject a second surface or input route.

## Toolchain

- `HARMONYOS_SDK_HOME` points to the DevEco/OpenHarmony SDK
- Compatible API 20, target API 21, and model `6.0.1`
- `hvigorw` and `ohpm` available from the SDK/toolchain setup

## DevEco, SDK, And Device Setup

Install DevEco Studio and use its SDK Manager to add an API 20-compatible
OpenHarmony/HarmonyOS SDK with native development components. The build needs
`native/build/cmake/ohos.toolchain.cmake`, `hdc`, `hvigorw`, and `ohpm`.

```sh
export HARMONYOS_SDK_HOME="${HARMONYOS_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony}"
export HARMONYOS_HVIGOR_BIN=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin
export HARMONYOS_OHPM_BIN=/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin
export PATH="$HARMONYOS_SDK_HOME/toolchains:$HARMONYOS_HVIGOR_BIN:$HARMONYOS_OHPM_BIN:$PATH"

test -f "$HARMONYOS_SDK_HOME/native/build/cmake/ohos.toolchain.cmake" && echo ok
hdc version
hvigorw --version
ohpm --version
```

Create and start an HVD through DevEco Studio Device Manager, or connect a
signed physical device. Confirm that `hdc` can see it before invoking `moui`:

```sh
hdc list targets
```


```sh
EMU="/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator"
HVD="MateBook Pro"
HVD_ROOT="$HOME/.Huawei/Emulator/deployed"
IMAGE_ROOT="$HOME/Library/Huawei/Sdk"

"$EMU" -hvd "$HVD" -path "$HVD_ROOT" -imageRoot "$IMAGE_ROOT"
```
Run `moui doctor --platform harmonyos` before a native build.

## Build And Run

```sh
moon check examples/harmonyos_demo/harmonyos_window_hosted --target native
moui build harmonyos harmonyos_demo \
  --mobile-config "$PWD/examples/harmonyos_demo/moui.mobile.json"
moui run harmonyos harmonyos_demo \
  --mobile-config "$PWD/examples/harmonyos_demo/moui.mobile.json"
```

`--prepare-only` stops before hvigor. `--fallback-skia` is packaging-only
diagnostic coverage and cannot promote runtime readiness.

## Validation And Evidence

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/harmonyos --target native
```

A device or HVD claim requires first frame, input, surface detach/recreate,
IME, clipboard, accessibility, and async-image observations. Signed-device
evidence is required before treating `checks/platforms/harmonyos.json` as more
than `partial`.

## Status

The source path and host-sim route are available, while actual presentation and
full service evidence are pending. See `docs/platform-readiness-declaration.md`
and `docs/window-hosted-moui.md` for the readiness boundary.
