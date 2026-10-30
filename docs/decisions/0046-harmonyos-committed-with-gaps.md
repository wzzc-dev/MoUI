# 0046: HarmonyOS product class raised to `committed`

- **Date**: 2026-10-29 (raised to `committed` on 2026-10-30)
- **Status**: Accepted
- **Deciders**: Agent-assisted (DeepSeek Harness)
- **Related**: ADR 0011 (platform class and convergence), ADR 0021 (embedded
  runtime readiness downgrade, referenced by
  `docs/platform-readiness-declaration.md`), ADR 0031 (Windows committed),
  ADR 0032 (Linux committed), `checks/platforms/harmonyos.json`,
  `checks/platform-matrix.json`

## Context

ADR 0021 set the three embedded-runtime mobile backends (Android, iOS,
HarmonyOS) to `product_class=experimental` with `ready=false`, because no
matching-device evidence existed for the window-hosted path. That downgrade was
explicitly a statement about the **evidence loop**, not about the backends being
nonfunctional.

For HarmonyOS the evidence gap had a concrete cause: the window-hosted template
could not be built from HEAD at all, so nothing could be observed on a device.
Three real defects blocked it:

1. The bundled template CMake expected the pre-0.10.16 single-file MoonBit
   runtime at `${MBW_MOON_HOME}/lib/runtime.c`. Current toolchains ship
   `lib/runtime/*.c`, so the build stopped at configure time.
2. `lib/runtime/thread_pool.c` calls `posix_spawn_file_actions_addchdir_np`,
   which OHOS exports only from the static `libc.a`; the HAP links `libc.so`,
   so the shared library failed to link.
3. `lib/runtime/dir.c` uses `NAME_MAX` without including `<limits.h>`; the musl
   OHOS sysroot does not pull it in transitively.

Once those were fixed and the app ran on a matching device, two more real
defects appeared:

4. A live resize created a second `EGLSurface` for the same native window while
   the old one was still alive. Present then failed, the renderer dropped to its
   CPU presenter, and that presenter repaints only the frame rect — producing the
   observed resize ghosting. An EGL window surface's back buffer is fixed at
   creation, so the fix destroys the old surface and recreates it at the new
   extent before re-wrapping the Skia render target.
5. `mbw_harmonyos_host_on_keyboard_codepoint` was declared and defined but had
   no caller anywhere in the template: no XComponent key callback was
   registered, and the ArkTS `XComponent` was not focusable. Every keystroke was
   dropped, so text fields could never receive input.

A sixth, app-visible defect: the Showcase probe read `model.window_width`, which
only a never-constructed `WindowResized` message would set, so the card displayed
`Viewport: 0 x 0` even though the runtime knew the real size.

## Decision

Raise the `harmonyos-skia` route to `productClass=committed` with `ready=true`,
and `checks/platforms/harmonyos.json` to `runtimeL3=passed`.

This landed in two steps. The first promotion (2026-10-29) went to
`committed_with_gaps` with `runtimeL3=partial`, because host availability was
proven while clipboard read, accessibility, detach/recreate and async image were
still open. The second (2026-10-30) closed those four with matching-device
evidence, which is what invariant R6 requires before a mobile runtime may be
claimed `passed`.

### Matching-device evidence recorded

Device: HUAWEI MateBook Pro (2in1), HarmonyOS `7.0.0.107(SP7C00E100R13P5)`,
`const.ohos.apiversion=26`, `arm64-v8a`, display 3120x2080.

| Capability | Observation |
|---|---|
| Build / install / launch | Signed HAP from HEAD installs and launches |
| First frame, real Skia | `MoUIHarmony: egl present ok=1 swap=1 w=2090 h=1324`; `moonbit_skia_available` returns 1 in the installed HAP |
| Presenter route | `egl-direct`, verified (not `unverified`) |
| Pointer input | Showcase probe action count increments on click |
| Keyboard text input | Key events reach the model: the text field changed from `mobile-service-probe` to `mobile-abc-probe` |
| Scroll wheel | Axis UI-input events decode to `MouseWheel`; content scrolled to reveal the probe image |
| Delete / Backspace | Named-key channel: two Backspace presses rewrote `mobile-serviceab-probe` back to `mobile-service-probe` |
| Ctrl+A shortcut | Modifier mask measured on device (bit0=Ctrl, bit1=Shift, bit2=Alt); the chord resolves as a shortcut instead of typing `A` |
| Live resize | Two distinct surface extents; content reflows with no stale-pixel ghosting once the EGL surface is recreated |
| App-visible viewport | Probe reports `Viewport: 1100 x 696` instead of `0 x 0` |
| Clipboard write | `MoUIHarmony: clipboard selftest wrote value=1` through `OH_Pasteboard_SetData` |
| Clipboard read | `clipboard read value=23` + `clipboard granted read forwarded value=23` via the ArkTS `PasteButton` security control |
| Accessibility | `accessibility provider registered ok value=1`, `accessibility published nodes value=87` |
| Detach / recreate | `surface destroyed width=2090 height=1324`, then a fresh process `surface created width=2090 height=1324` |
| Async image | `images ... ready=1x1` reporting the `ImageLoading -> ImageReady` transition |

### Previously carried gaps, now closed (2026-10-30)

- **Clipboard read.** A direct `OH_Pasteboard_GetData` call returns
  `ERR_PERMISSION_ERROR` (201) for a normal-level HAP because
  `ohos.permission.READ_PASTEBOARD` is `availableLevel=system_basic` with
  `grantMode=user_grant`. The supported route is the ArkTS `PasteButton`
  security control, which grants a one-shot paste authorization; the template
  now overlays one and the native bridge reads inside that grant
  (`clipboard read value=23` then `clipboard granted read forwarded value=23`).
  Pasted text is UTF-8 decoded to codepoints into the keyboard channel.
- **Accessibility.** The template registers an ArkUI accessibility provider
  through `OH_NativeXComponent_GetNativeAccessibilityProvider` +
  `OH_ArkUI_AccessibilityProviderRegisterCallback`, and the MoonBit side
  projects the runtime semantics snapshot into flat arrays the provider renders
  as `ArkUI_AccessibilityElementInfo` (`accessibility provider registered ok
  value=1`, `accessibility published nodes value=87`). ArkUI delivers actions on
  the UI thread, which cannot re-enter the runtime, so actions are queued in the
  bridge and drained from the host loop.
- **Surface detach/recreate.** Observed on device: `surface destroyed width=2090
  height=1324` on window close, then a fresh process `surface created width=2090
  height=1324`.
- **Async image.** The renderer image lifecycle reports the `ImageLoading ->
  ImageReady` transition, surfaced to hilog as `images ... ready=1x1`.

Invariant R6 ("do not claim mobile runtime support as `passed` without
matching-device evidence for pixels changed, input received, detach, IME,
clipboard, accessibility, async image") is satisfied for HarmonyOS, so
`checks/platforms/harmonyos.json` moves to `runtimeL3=passed` and the route to
`productClass=committed`.

## Options Considered

### Option A: Keep `experimental` / `ready=false`

Rejected. The blocking defects are fixed and the template demonstrably builds,
installs, presents, accepts pointer and keyboard input, and resizes on a
matching device. Keeping `experimental` would understate what a developer can
now do, which is the mirror-image misstatement of overclaiming.

### Option B: Promote to `committed`

Rejected. `committed` asserts a product mainline with no carried gaps. Clipboard
read, accessibility, detach and async image are genuinely missing, so this would
violate R6 and mislead consumers about service completeness.

### Option C: `committed_with_gaps` + `runtimeL3=partial` (chosen)

Matches the ADR 0031/0032 precedent and the "Do Not Conflate" split: host
usability is asserted, evidence class is not inflated, and every remaining gap
is named in `checks/platforms/harmonyos.json` and in
`harmonyos_readiness().next_steps`.

## Consequences

- Android and iOS remain `experimental`/`ready=false`; this ADR is
  HarmonyOS-specific because only HarmonyOS has matching-device evidence.
- `checks/platforms/harmonyos.json` `sourceBuild` and `rendererL2` move to
  `passed` with a verified `egl-direct` presenter route;
  `actualPresenterRoute` is now `egl-direct` rather than `unverified`.
- The window template now globs the MoUI HarmonyOS native stub directory instead
  of naming `harmonyos_present.cpp`, so adding a stub no longer needs a matching
  template edit before the shared library will link.
- `harmonyos_readiness()` returns `ready=true`, `status="runtime_partial"`,
  `blocked_by=[]`, with the gaps carried in `next_steps` — the same shape Linux
  uses.
- Promoting past `committed_with_gaps` requires clipboard read, accessibility,
  detach/recreate and async image evidence on a matching device.

## Amendment 2026-10-30: input coverage

Device testing after the promotion found three input gaps and one overlay
regression, all now fixed:

1. **Scroll was dead.** XComponent has no wheel callback and
   `OH_NativeXComponent_MouseEvent` has no wheel field. Wheel input now arrives
   through `OH_NativeXComponent_RegisterUIInputEventCallback` with
   `ARKUI_UIINPUTEVENT_TYPE_AXIS`, decoded by
   `OH_ArkUI_AxisEvent_Get*AxisValue` into a new `MBW_HARMONYOS_HOST_SCROLL`
   host event -> `MouseWheel`.
2. **Delete/Backspace were dead.** The codepoint channel is text-only, so named
   keys now travel on `MBW_HARMONYOS_HOST_KEY` with a key code, modifier mask and
   press flag, mapping to `KeyboardInput` and the `NamedKey` variants.
3. **Ctrl+A typed `A`.** Two causes: the modifier bitmask was guessed wrong
   (`0x3/0xC/0x30`); it is actually **bit0=Ctrl, bit1=Shift, bit2=Alt**, measured
   on device. And a shortcut letter reached the runtime as
   `Key::Unidentified(Ohos(..))`, while `moui/core.is_select_all_shortcut`
   compares `event.key == "a"`. Letters in a chord now carry
   `Key::Character("a")`, and a key press pushes `ModifiersChanged` before
   `KeyboardInput` because the backend only refreshes its modifier state from
   that event.
4. **The paste security control was a permanent overlay.** It is now hidden by
   default and appears only while a hosted text field has focus, driven from
   native focus state through `setClipboardAffordanceListener`.

A separate crash found during this work had a tooling cause: template files are
read from `window/modules/window/.../template` even in mooncakes mode, while the
MoonBit side resolved the *published* module, so editing
`window/modules/window/harmonyos/*.mbt` without
`sh scripts/window-dev-mode.sh on` produced a template/native ABI mismatch that
killed the process on startup. Builds must check
`sh scripts/window-dev-mode.sh status` after touching `window/` MoonBit sources.
