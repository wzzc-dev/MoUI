# 0069: macOS frames follow the display refresh, and paint-time editors own their live scroll

- **Date**: 2026-11-12
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted frame-pacing review)
- **Related**: plan `macos-frame-pacing-and-transient-scroll`, ADR 0018
  (host runtime driver), ADR 0051 (content-coordinate scroll), plan
  `architecture-priority-execution` N5

## Context

The macOS async pump (`moui/backend/macos/macos_app_runtime.mbt`) is an external
host loop: it calls `pump_app_events(Some(0))` and then sleeps 1 ms while a
frame is owed, 8 ms otherwise. There is no display link, so animation frames
start on an arbitrary timer phase. The shipped Skia GPU route presents
synchronously on the UI thread (`metal_present_and_acquire_next`), so a frame
that starts just after a refresh can miss the next drawable acquisition.

Separately, MoMark's markdown editor returned `activated=true` and a message for
every wheel tick. Each tick therefore rebuilt the program root even though the
only visible change was the editor's paint-time scroll offset. Showcase N5 had
already proved that an element-owned `ViewStateSlot` can scroll without a root
rebuild; the paint-time windowed editor did not use that shape because its live
glide lived in the app model.

## Decision

1. The `window` macOS backend exposes a display-refresh clock
   (`host_vsync_init`, `host_wait_for_vsync`, `host_vsync_shutdown`,
   `host_vsync_refresh_millihz`) backed by `CVDisplayLink`. The callback only
   signals a semaphore; it never calls MoonBit or touches AppKit.
2. The MoUI macOS async pump opts into that clock, processes input first, waits
   for the next refresh when any open runtime slot owes a frame, then pumps the
   redraw. Idle keeps the timed sleep. `MOUI_MACOS_FRAME_PACING=0` disables the
   wait for hosts where a synchronous Metal present already waits on the
   display.
3. The markdown editor keeps its live glide in a private element
   `ViewStateSlot`. Wheel input writes only that slot (`changed=true`,
   `activated=false`, no message). `FrameTick` emits at most one
   `on_scroll_settled` message per gesture. Programmatic targets use a monotonic
   `ScrollRequest`; keyboard/text input pins the slot at the shown offset.
4. Controlled `scroll_glide` / `on_scroll` callers keep their existing per-tick
   contract. The transient mode is opt-in via `transient_scroll=true`.

## Consequences

- macOS frame starts land on refresh boundaries; animation sampling and
  presentation are no longer tied to the pump's sleep grid.
- A scroll gesture no longer rebuilds the program root or re-lays out the
  window; the app receives one update when the gesture settles.
- The window package must publish a new version and every consumer pin must move
  together before the default (mooncakes) build can see the clock.
- A synchronous Metal present may already block on the drawable; the escape
  hatch and present-to-present metrics decide whether the extra wait is a win on
  a given route.
- The MoMark indicator updates at settle in v1. A live thumb would need the
  offset to move into the editor's paint or a retained-layer prototype; that is
  a separate product decision.
- Generic `scroll_view` settle notifications, completion-wake/two-in-flight
  submission, and retained-layer scrolling remain follow-ups with their own
  evidence gates.
