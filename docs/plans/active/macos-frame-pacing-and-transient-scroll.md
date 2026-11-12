# Plan: macOS frame pacing and transient scroll

- **Status**: active
- **Goal**: Make macOS frames land on the display refresh boundary and remove
  per-wheel-tick root rebuilds from paint-time windowed editors (MoMark), then
  add the diagnostics needed to keep the result measurable.
- **Supersedes**: none. Extends the N5 transient-scroll direction recorded in
  `docs/plans/done/architecture-priority-execution.md` and the HarmonyOS frame
  pacing precedent in `docs/plans/active/harmonyos-scroll-frame-pacing.md`.
- **Non-goals**: renderer rewrite; GPU partial present (Metal drawables stay
  full-surface); changing the controlled `on_scroll` per-tick contract; enabling
  multi-frame in-flight for any shipped renderer.

## Progress 2026-11-12

Landed:

- `window/modules/window/macos`: `native_frame_clock.m` +
  `frame_clock.mbt` (`host_vsync_init` / `host_wait_for_vsync` /
  `host_vsync_shutdown` / `host_vsync_refresh_millihz`), registered in
  `moon.pkg` and the FFI export allowlist. The callback only signals a
  semaphore and never enters MoonBit. Window macOS tests: 113/113.
- `moui/backend/macos`: the async pump pumps input first, waits for the next
  refresh when a frame is owed, then pumps the redraw; idle keeps the timed
  sleep. Frame-owed aggregates all open runtime slots. The display clock is
  bound to the primary window's screen in `can_create_surfaces`, with
  `MOUI_MACOS_FRAME_PACING=0` as the escape hatch. A pure
  `macos_frame_wait_action` helper is covered by white-box tests.
  `MOUI_FRAME_LOG=1` prints present-to-present p50/p95/max and slow frames
  every five seconds.
- `moui_richtext`: `MarkdownSessionScrollState` slot, transient wheel/settle
  handling, `scroll_request` / `on_scroll_settled` / `transient_scroll` on
  `controlled_markdown_session_editor`, keyboard/text-input pinning, and a
  painted-offset diagnostic. Controlled `scroll_glide` / `on_scroll` behavior
  is unchanged.
- MoMark: live glide removed from the app model; `EditorScrollSettled` is the
  only per-gesture update; document switches issue a reset request; the
  indicator follows the editor's paint snapshot while animating (live thumb,
  no app state). MoMark tests: 2593/2593.

Verification so far:

- `moon test moui_richtext moui/backend/macos --target native`: 383/383.
- `moon test moui/views moui/runtime --target native`: 277/277.
- `moon test examples/showcase/app --target native`: 17/17.
- MoMark macOS first-frame smoke: `macOS renderer presented first frame`.
- Validators: API surface, generated interfaces, maintenance baseline,
  guidance, doc references pass. `validate-window-dependency` still reports the
  pre-existing `examples/momark` pin mismatch (`0.5.4-0.2.5` vs `0.5.4-0.2.8`).

Follow-up landed: `controlled_markdown_session_editor` now takes one
`MarkdownEditorScrollMode` (`Element` or `App`) instead of the independent
`scroll_glide` / `on_scroll` / `transient_scroll` knobs, so invalid ownership
combinations are no longer expressible.

Deferred with rationale:

- Generic `scroll_view` settle notification (P1.1): no production consumer;
  Showcase already uses uncontrolled scrolling and MoMark uses the richtext
  slot. Adding the API now would enlarge the public surface without a caller.
- Completion wake seam / two frames in flight (P2.1): no shipped renderer
  returns `queued=true`; the Skia GPU route presents synchronously on the UI
  thread. Changing `WindowFrameState` now would be speculative and would churn
  the tests that pin the current one-in-flight contract.
- Strict present-trace script (P2.3): the md_editor harness already owns the
  `xctrace` Animation Hitches path; a second parser in MoUI would duplicate it.
  `MOUI_FRAME_LOG` is the in-process diagnostic; a strict trace remains a
  follow-up once the app-level harness is wired to the new versions.
- Retained-layer scroll (P2.4): gate on a post-P1 measurement showing >1 ms/frame
  of block conversion/measure work. No such measurement exists yet; the
  current MoMark GPU work is ~2 ms/frame including all phases.

Release gate: the window source is consumed through dev mode until
`0.5.4-0.2.9` is published and the three pins are bumped; MoMark uses a local
`moon.work` override until `moui`/`moui_richtext` are republished. Both are
explicit publish steps, not part of the code change.

## Context

Winc feels smoother than MoMark because it produces one frame per display
refresh (`CADisplayLink`, 120 Hz requested, paused when idle), writes CPU pixels
into one of three `IOSurface`s without waiting for the compositor, and scrolls a
retained editor state instead of rebuilding a view tree. MoUI's macOS host has
none of those properties today:

- `moui/backend/macos/macos_app_runtime.mbt` pumps with `@async.sleep(1)` /
  `sleep(8)` and `pump_app_events(Some(0))`; there is no display link, so frame
  starts sit on an ~8 ms timer grid rather than 8.33/16.67 ms refresh
  boundaries.
- Shipped Skia GPU presentation is synchronous on the UI thread
  (`skia_gpu_present_and_acquire_next` → `metal_present_and_acquire_next`), so
  the 8 ms sleep plus frame work can miss the next drawable acquisition.
- MoMark's editor returns `activated=true` and a message for every wheel tick
  (`moui_richtext/rich_text_markdown_session_editor.mbt`), so each tick runs a
  root rebuild; Showcase N5 already proved the transient `ViewStateSlot` shape
  (`changed=true, activated=false, messages=[]`).
- Allocation-driven GC pauses remain visible on scroll frames (MoUI's own
  HarmonyOS capture recorded ~27 ms pauses).

## Ordered work

### P0 — display-refresh pacing

1. `window/modules/window/macos`: add a `CVDisplayLink`-backed frame clock
   (`native_frame_clock.m` + `frame_clock.mbt`: `host_vsync_init`,
   `host_wait_for_vsync`, `host_vsync_shutdown`). Mirror the HarmonyOS
   `host_wait_for_vsync` contract; the callback only signals a semaphore and
   never enters MoonBit. Register the native stub and FFI export allowlist.
2. `moui/backend/macos`: initialize the clock after the window exists, pump
   input first, wait for the next refresh when a frame is owed, then pump the
   redraw; idle keeps the timed sleep. Aggregate frame-owed across all open
   runtime slots. Add `MOUI_MACOS_FRAME_PACING=0` as the escape hatch.
3. Add a pure frame-policy helper and white-box tests so the wait/sleep decision
   is testable without a GUI.

### P1 — transient scroll

1. `moui/views`: optional `on_scroll_settled` on `scroll_container` /
   `scroll_view`; uncontrolled wheel/fling becomes `activated=false,
   messages=[]` and emits one settle message. Controlled `on_scroll` unchanged.
2. `moui_richtext`: private `ViewStateSlot` for the live glide, plus optional
   `scroll_request`, `on_scroll_settled`, and `transient_scroll` on
   `controlled_markdown_session_editor`. Wheel writes the slot; `FrameTick`
   emits one settle message; keyboard/text input pins the slot at the shown
   offset; paint/text-input sample the slot.
3. MoMark: drop `EditorScrolled`/app glide, own only `ScrollRequest` and the
   settled offset; indicator updates at settle in v1; document switches issue
   explicit reset requests.

### P2 — pipeline seam and evidence

1. `RendererCompletionWake` seam and removal of the pending self-poll in
   `WindowFrameState`; `max_in_flight` stays 1 for every shipped provider.
2. `MOUI_FRAME_LOG` present-to-present diagnostics (p50/p95/max, slow frames).
3. Generic macOS strict present trace script (Animation Hitches /
   `displayed-surfaces-interval`).
4. Retained-layer scroll spike only if P1 leaves >1 ms/frame of block
   conversion/measure work; otherwise record non-adoption.

## Validation

- `moon test moui/backend/macos --target native`
- `moon test moui/views moui/runtime moui_richtext --target native`
- window: `moon check/test --target native`, `check_ffi_surface.sh`,
  `scripts/run-window-package-smoke.sh macos --run`
- `scripts/run-macos-gpu-performance-smoke.mjs --duration-ms 10000
  --skip-scaffold` before/after (p95 frame, dropped percent)
- MoMark: app tests, `run_ui_benchmark.sh --fixture large`, manual 60/120 Hz
  scroll, reversal, edge, document switch, typing during glide
- pre-push validators: window dependency, API surface, generated interfaces,
  maintenance baseline, guidance, doc references

## Risks

- `CVDisplayLink` is deprecated; keep the pragma and fall back to the timed
  sleep when init fails. A later switch to macOS 14+ `NSView.displayLink` is
  possible.
- Waiting for vsync on top of Metal `nextDrawable` can double the interval; the
  escape hatch disables the wait, and present-to-present metrics decide.
- Input latency: pump input before the wait, bound the wait at 20 ms, and skip
  the wait while a modal session owns the run loop.
- `window` changes require dev mode, a version bump, three pin updates, and an
  explicit publish confirmation.
