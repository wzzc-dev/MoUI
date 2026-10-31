# HarmonyOS window-hosted facts (post ADR 0046)

- Product class is `committed` with `ready=true` and `runtimeL3=passed` (ADR
  0046). All R6 capabilities have matching-device evidence. `ready` still means
  "development/demonstration can rely on the template + session"; see
  `docs/platform-readiness-declaration.md` ("Do Not Conflate the Three Status
  Sets").
- `moonbit_bytes_t`-returning FFI is the convention for HarmonyOS clipboard
  (`harmonyos_clipboard.cpp`), mirroring `moui/backend/macos/macos_service_host.m`.
- The HarmonyOS template globs `${MBW_WORKSPACE_ROOT}/moui/backend/harmonyos/*.cpp`
  instead of naming `harmonyos_present.cpp`, so a new native stub links without a
  template edit. Link deps for the pasteboard bridge: `pasteboard`, `udmf`.
- `ohos.permission.READ_PASTEBOARD` is `availableLevel=system_basic` +
  `grantMode=user_grant`: a normal-level HAP cannot read the pasteboard and
  `OH_Pasteboard_GetData` returns `ERR_PERMISSION_ERROR` (201). Writing plain
  text works without any permission. Do not treat a 201 as a MoUI bug. The
  supported read route is the ArkTS `PasteButton` security control, which grants
  a one-shot authorization; the native bridge reads inside that grant.
- ArkUI accessibility: obtain the provider with
  `OH_NativeXComponent_GetNativeAccessibilityProvider`, register via
  `OH_ArkUI_AccessibilityProviderRegisterCallback`. Callbacks run on the UI
  thread and must NOT re-enter the runtime; queue actions and drain them from the
  host loop. `ArkUI_AccessibleRect` uses `leftTopX/leftTopY/rightBottomX/rightBottomY`,
  and the result enum uses 0 for SUCCESSFUL.
- The template globs `${MBW_WORKSPACE_ROOT}/moui/backend/harmonyos/*.cpp`, so a
  host build also compiles the ArkUI-only bridge. Keep host-build fallbacks in
  `harmonyos_accessibility_fallback.c` marked `__attribute__((weak))` or the
  shared library fails with duplicate symbols.
- MoonBit `println` does not reach hilog on HarmonyOS; device evidence must go
  through a native `OH_LOG_Print` shim.
- An EGL window surface's back buffer is fixed at creation. A live resize must
  destroy and recreate the `EGLSurface` (`moonbit_skia_surface_egl_resize_window`)
  rather than reuse it, or Skia wraps a stale extent and the frame is clipped.
  Leaving the old surface alive while creating a new one for the same native
  window makes present fail and drops the renderer to the CPU presenter, which
  repaints only the frame rect (the resize ghosting symptom).
- XComponent key events are the only keyboard source. The template must call
  `OH_NativeXComponent_RegisterKeyEventCallback` and the ArkTS `XComponent` must
  be `.focusable(true)`, otherwise `mbw_harmonyos_host_on_keyboard_codepoint` has
  no caller and every keystroke is dropped.
- The Showcase probe read `model.window_width`, set only by a never-constructed
  `WindowResized` message. Pages needing the real size should take
  `ViewEnvironment::viewport_size()`; `examples/showcase/app/platform` now accepts
  a `viewport~` argument.
- `MOUI_HARMONYOS_SIGNING_CONFIG`/hvigor require DevEco-encrypted passwords (>=32
  chars ciphertext), not plaintext; signing configs live in gitignored
  `artifacts/harmonyos/`.

## XComponent input coverage (measured 2026-10-30)

- Scroll has **no** dedicated XComponent callback and
  `OH_NativeXComponent_MouseEvent` carries no wheel field. The only source is
  `OH_NativeXComponent_RegisterUIInputEventCallback(...,
  ARKUI_UIINPUTEVENT_TYPE_AXIS)` + `OH_ArkUI_AxisEvent_GetVerticalAxisValue` /
  `GetHorizontalAxisValue`.
- `OH_NativeXComponent_GetKeyEventModifierKeyStates` bitmask, measured on the
  device (NOT in a public header): **bit0 = Ctrl, bit1 = Shift, bit2 = Alt**.
  Guessing 0x3/0xC/0x30 silently breaks Ctrl+A and friends.
- Character keys and named keys need different channels: `Backspace`/`Delete`/
  arrows cannot travel through the codepoint channel, so
  `MBW_HARMONYOS_HOST_KEY` carries `(key_code, modifiers, pressed)` and maps to
  `KeyboardInput`. Letters pressed with Ctrl/Alt must also go through that
  channel and carry a `Character("a")` logical key, or
  `moui/core.is_select_all_shortcut` (which compares `event.key == "a"`) never
  matches.
- `HostedWindowBackend.modifiers` is only updated by `ModifiersChanged`, so a
  key press must push `ModifiersChanged` before `KeyboardInput` or the decode
  runs with stale modifiers.
- The ArkTS paste security control must not be a permanent overlay; drive its
  visibility from native focus state (`setClipboardAffordanceListener`).

## Dev-mode hazard (cost a Cpp Crash)

Template files are read from `window/modules/window/.../template` even in
mooncakes mode, but the MoonBit side resolves the **published** module. Editing
`window/modules/window/harmonyos/*.mbt` without
`sh scripts/window-dev-mode.sh on` therefore produces a template/native ABI
mismatch that crashes on device (the poll call gains parameters the linked
library does not have). Always run `window-dev-mode.sh status` before building
HarmonyOS after touching `window/` MoonBit sources, and switch off again before
committing (R4).

## Clipboard shortcuts: where the chain actually breaks (2026-10-30)

Ctrl+A worked while Ctrl+C/X/V did not, which is the decisive clue: Ctrl+A is
matched in the **views** layer (`is_select_all_shortcut` inside the text
control's key handler), while Ctrl+C/X/V need
`HostRuntimeDriver::keyboard_service_command_intent` -> `dispatch_command_with_services`
-> `dispatch_focused_text_command`. Two separate breaks had to be fixed:

1. `EmbeddedRuntimeBackendCore::dispatch` sent every `Keyboard` event through
   the plain `driver.dispatch`, so the service-aware path was never reached.
2. `EmbeddedHostServices::bridge` only **enqueues** Clipboard requests, and
   `EmbeddedRuntimeHostBridge::sync` immediately moves the queue into `updates`
   for a shell to answer. An embedded template has no shell, so the request was
   dropped and Ctrl+V never received `ClipboardText`. Fixed with a
   `service_handler` injected at `HostedWindowBackend` construction
   (`EmbeddedRuntimeBackendCore::new(service_handler~)`), which answers
   synchronously before the queued path is consulted.

`moui/backend/common/embedded/embedded_runtime_backend_wbtest.mbt` now pins the
whole embedded chain (Ctrl press -> Ctrl+A -> Ctrl+C -> clipboard writer), so a
regression shows up without a device.

## Scroll: position and stutter

- `window-core`'s `MouseWheel` carries **no position**; the decode reads
  `last_pointer`, which only pointer events update. Hover movement over an
  XComponent produces no touch event, so the wheel acted on the last click.
  Fix: `HostedWindowBackend::dispatch_wheel(position, delta)` sets
  `last_pointer` and dispatches in one call.
- Do **not** synthesise `PointerMoved` before the wheel: that dispatches a full
  pointer event (and its hover repaint) per notch and makes scrolling stutter.
  Positions travel beside the event (`scroll_cursors` queue, popped in order).
- Axis action filter: only `AXIS_ACTION_UPDATE` carries a new delta;
  BEGIN/END repeat the previous value and doubling them feels sticky.
- Sign: MoUI computes `offset.y -= delta.y`, so positive delta scrolls content
  up; OHOS axis values are the opposite, so the host bridge negates them.

## Scroll stutter was a missing redraw, not slow layout (2026-10-30)

Symptom: wheel scrolling "felt laggy". The real cause was that the frame a
scroll dirties was never presented.

`HostedWindowBackend::dispatch_host_event` ends with `pump_redraw_requested()`;
the wheel shortcut `dispatch_wheel` called `dispatch_window_event` directly and
skipped it. So the scroll view updated its offset, asked for a repaint, and
nothing presented — the surface only caught up when some unrelated event
happened to pump a frame. Device proof: five notches scrolled a sidebar with
`frames=5` frozen; after adding `pump_redraw_requested()` the counter advanced
per notch (5 -> 13 -> 14).

Diagnostic that found it: log `frames_presented()` next to each wheel event. A
frozen counter with live scroll events means "dirty but not presented", which is
a different bug from "presented but slow".

Do NOT "optimise" the wheel path by downgrading `ViewLayoutDirty` to
`ViewPaintDirty`: scroll offset really does move laid-out geometry
(`runtime.layout().children[0].frame.origin.y` becomes negative), and
`moui/runtime/view_runtime_test.mbt` pins that. Two tests fail immediately if
you try.

## Frame pacing: the macOS-vs-HarmonyOS difference (2026-10-30)

"Why does macOS scroll smoothly and HarmonyOS not?" The loops differ:

- macOS (`macos_app_runtime.mbt`): polls tight (`sleep(1)`) while
  `runtime.needs_redraw()` or a sub-frame timer is live, and sleeps the full
  frame interval only when idle.
- HarmonyOS (`EventLoop::run_app_on_demand`): `sleep_ms(4)` unconditionally, so a
  scroll glide waits out the sleep before presenting — that is the stutter.

`EventLoop::run_app_with_frame_pacing(handler, needs_redraw~, active_frame_ms~,
idle_frame_ms~)` implements the macOS scheme; `HarmonyOSEmbeddedRuntimeBackend`
passes `needs_redraw=fn() { app.needs_redraw() }`
(`HostedWindowBackend::needs_redraw` -> `session.redraw_requested()`).

Pitfall that cost a debugging round: do NOT re-route `run_app_on_demand`
through the new pacing function. Doing so left the loop running but the
application stopped handling input entirely (axis events reached the native
layer, no MoonBit handler ran, no crash). Keep `run_app_on_demand` as its own
simple loop and add `run_app_with_frame_pacing` beside it.

Device proof: eight fast notches advanced `frames_presented` 11 -> 18, one frame
per notch, no drops.

## What native HarmonyOS apps do differently (and what was adopted, 2026-10-30)

Three structural gaps versus a native ArkUI app; two are now closed.

1. **Frame driving — closed.** Native apps drive the loop from `DisplaySync`, so
   frames start on the display refresh boundary. MoUI slept a fixed interval,
   which lands the frame at an arbitrary phase: an otherwise cheap frame still
   waits up to a full period to be shown, read as judder. Adopted
   `native_vsync.h` (`OH_NativeVSync_Create` + `OH_NativeVSync_RequestFrame`,
   linked as `native_vsync`) behind
   `mbw_harmonyos_wait_for_vsync`; the loop waits on vsync while a frame is owed
   and plain-sleeps when idle. `ohos` device reports `vsync init ok=true`.
   Wait on vsync **only when a frame is owed**: waiting while idle spends a
   refresh per idle iteration and stalls input polling if the callback is late.
2. **No scroll interpolation — closed.** `scroll_offset_after_wheel` jumped the
   offset in one frame. `ScrollWheelSettle` + `scroll_wheel_settle_offset` ease
   the painted surface toward the authoritative offset over ~90 ms (ease-out),
   and `animating` keeps frames flowing until it lands. The authoritative offset
   stays exact, so layout and hit testing are unaffected.
3. **Full-surface redraw per frame — still open.** `resolve_effective_damage`
   always returns `FullSurface`, so every frame re-rasterises 2090x1324. Tracked
   in `docs/plans/debt/full-surface-redraw-per-frame.md`; it needs a damage
   capability on the surface contract plus an ADR, not a local edit.

## Why wheel scrolling froze after a few pixels (2026-10-30)

The last and most misleading symptom: "scroll moves a little, stalls, then jumps
the rest". Diagnostic that pinned it: log `frames_presented()` next to every
wheel event. It stayed at **3 for every scroll** while the clock advanced — so
the wheel was decoded and dispatched, but **no frame was ever rendered**.

Two separate holes, both on the wheel shortcut:

1. `dispatch_wheel` called `dispatch_window_event` directly.
   `dispatch_host_event` is what ends with `pump_redraw_requested()`, so the
   wheel path never asked for a frame. And even calling
   `pump_redraw_requested()` is not enough: it only asks when
   `transport.frame_requested()` is already set, which a wheel dispatch never
   sets. The fix asks the window directly (`window.request_redraw`).
2. **No frame clock.** `RedrawRequested` rendered straight away, but paint reads
   `environment.now_ms`, which only advances via `advance_time`. HarmonyOS never
   called it, so every animation stayed latched "in flight": the painted surface
   eased one sample, then froze because the clock never moved again. Fixed by
   injecting `clock_ms` into `HostedWindowBackend` (`mbw_harmonyos_monotonic_ms`)
   and calling `session.advance_time(now)` before `render_frame()`.

Rule of thumb earned here: if a surface "moves a bit then freezes", check
`frames_presented` before touching animation code. A frozen counter with live
input events is a *redraw* bug; a rising counter with bad motion is an
*animation* bug. Conflating the two cost several rounds.

## Scroll interpolation was removed — do not re-add it blindly (2026-10-30)

An eased overlay for wheel steps (`ScrollWheelSettle` + a 90 ms ease-out applied
in `paint`) was implemented and then **reverted**, because it made scrolling
worse: "moves a little, stalls, then jumps the rest".

Why it cannot work as written on this host: the embedded runtime presents one
frame per input event (see below), so the interpolation only ever produced its
first sample. The painted surface then sat at that sample until the next wheel
event — a stall, not an animation. To make an eased overlay real, the host would
first have to produce frames on a clock while an animation is in flight, which is
the "frames per input event" limitation, not a view-layer detail.

Practical baseline: wheel steps move the authoritative offset directly. Verified
working pieces around it are vsync pacing, the frame clock advance before
`render_frame`, and the direct `window.request_redraw` on the wheel path.

## Honest note on this debugging arc

Several rounds were spent guessing (layout cost, vsync, interpolation) before
measuring. The measurements that actually discriminated:

- `frames_presented()` frozen while input events arrive -> **redraw** bug.
- `frames_presented()` rising but motion wrong -> **animation** bug.
- `raw_dy`/`axis x=` logs distinguish "event never arrived" from "event arrived but
  nothing painted".

Add the counter to the log line **before** theorising. Several wrong turns in
this session would have been avoided by one extra number in an existing log.
