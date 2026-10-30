# HarmonyOS Support

HarmonyOS uses the **embedded runtime backend** route and is **`committed`**
(`ready=true`, `runtimeL3=passed`, see ADR 0046): `wzzc-dev/window/harmonyos`
owns the Stage Ability, XComponent surface, lifecycle, and input queue;
`moui/backend/harmonyos` adapts those callbacks into the MoUI runtime session.

A signed HAP built from HEAD installs, launches, presents through `egl-direct`
with real Skia, accepts pointer and keyboard text input, resizes without
ghosting, exposes a real app viewport, reads and writes the system clipboard,
publishes an accessibility tree to ArkUI, survives surface detach/recreate, and
observes async image load completion on a matching device.

### Host services on this route

| Service | Implementation | Note |
|---|---|---|
| Clipboard write | `harmonyos_clipboard.cpp` via `OH_Pasteboard_SetData` | No permission needed |
| Clipboard read | Same file, driven from the ArkTS `PasteButton` security control | `ohos.permission.READ_PASTEBOARD` is `system_basic` + `user_grant`, so a direct `OH_Pasteboard_GetData` call returns `ERR_PERMISSION_ERROR` (201) for a normal-level HAP |
| Keyboard text | `OH_NativeXComponent_RegisterKeyEventCallback` + focusable `XComponent`, keycode map in `window_hosted_napi.cpp` | Character keys travel on the codepoint channel as `Ime(Commit)` |
| Named keys | Same callback, `MBW_HARMONYOS_HOST_KEY` host event | Backspace/Delete/arrows/Enter/Tab/Escape/Home/End map to `KeyboardInput`; the codepoint channel cannot express deletion |
| Scroll wheel | `OH_NativeXComponent_RegisterUIInputEventCallback` (axis events) | XComponent has no wheel callback and no wheel field on its mouse event |
| Shortcuts | Key event + `ModifiersChanged` | Modifier mask is bit0=Ctrl, bit1=Shift, bit2=Alt (measured on device, not in a public header) |
| Accessibility | `harmonyos_accessibility.cpp` via `OH_NativeXComponent_GetNativeAccessibilityProvider` | Answers ArkUI provider callbacks from the runtime semantics snapshot |
| Async image | `filesystem_image_source` + renderer image lifecycle | Status transitions are reported to hilog as `images ... ready=<w>x<h>` |

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
moon check examples/showcase/harmonyos_window_hosted --target native
moui build harmonyos showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui run harmonyos showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
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
