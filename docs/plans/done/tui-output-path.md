# TUI Output Path

- Status: done — S0–S7 landed with evidence, and the two owner-gated open items
  were resolved by owner decision on 2026-10-16, carried by
  [tui-hardening](../active/tui-hardening.md): the `[focus-dbg]` println was
  deleted and the API-surface budget ratchet was settled in H1, and the PTY
  interaction gate became content-anchored and joined the nightly
  `moui-runtime-gates.yml` in H3, which is what closes this plan. Option B
  (frame carries semantics) was approved by the owner on 2026-10-14 and landed
  the same day. The two items this plan had left to the owner were resolved in
  the 2026-10-16 owner call: the `[focus-dbg]` `println` in
  `moui/runtime/runtime_events.mbt:431` is approved for deletion (done in
  tui-hardening H1), and `tui.pty-interaction-smoke` gets a CI job after the
  settle protocol is made deterministic (tui-hardening H3).
- Resolved 2026-10-16 (found while re-running `sh scripts/check.sh --profile
  pr` on 2026-10-15, not caused by the S5 addendum): decision B grew
  `tools/moui/validate_api_surface/main.mbt` from 1669 to 1680 lines without
  settling `checks/source-file-policy.json`, so the `pr` profile stopped at
  `validate_source_file_policy` with `logic lines=1680 exceeds registered
  budget 1669`. Owner chose to settle the ratchet (1669 → 1680 with a dated
  reason, the convention that file already uses) rather than move the
  contract-audit entries into a sibling module; the settle and the focus-dbg
  deletion land in tui-hardening H1.
- Human check: the six S5 interactions are asserted by
  `moui_tests/tui_pty_smoke` inside a real POSIX PTY
  (`sh scripts/tui-pty-smoke.sh`, 8/8 — the eighth case carries both owner-reported
  counter defects: the label-row/click-row alignment addendum and the focus-band
  underline addendum below). That is machine evidence, not a person
  typing in Terminal.app; the `moon run examples/tui_split/terminal` session
  itself is still an un-performed manual confirmation.
- Decision: **B**. `@core.DrawFrame` gains a semantics payload so
  `moui_tui_renderer` is a real `RendererProvider`. Approved with the standing
  constraint that this is a *payload* change only: cell quantization, clipping
  and overlap-repair logic must live in `moui_tui_renderer`, never in
  `moui/core` or `moui/runtime`. Pixel renderers must not pay for the field.
- Goal: let an existing `@moui.View[Msg]` app run in a real terminal without pixel
  rendering: split panels, focus traversal, list selection, tree collapse, mouse,
  instant keypress and true resize reflow.
- Compatibility: additive for consumers; `DrawFrame` is a `pub(all)` record, so
  construction sites and `pkg.generated.mbti` need regeneration and the API
  surface validator must be re-run.

## Evidence from the S0 probe (`moui_tests/tui_spike`, 6/6 green native)

The probe installs a monospace cell `TextSystem` and projects the **semantics
tree plus frames** into a character grid. It touches no core or runtime code:
`@runtime.new_program_with_dimensions` + `set_text_system` + `layout()` +
`read_semantics()`, all public.

| Program | Viewport | semantics | layout | DrawCommand | off-viewport | quantization error |
|---|---|---|---|---|---|---|
| counter | 320x200, 8x16 cells | 6 | 12 | 11 | 0 | off_grid_point=6, off_grid_size=4, worst 6px |
| counter | 320x80 | 6 | 12 | 11 | 3 | same |
| showcase | 1200x800 | 124 | 415 | 219 | 64 | off_grid_point=155, off_grid_size=118, worst 8px |

Durable findings:

1. **Semantics, not DrawCommand, is the right input.** Fractional flex layout
   puts 155 of 248 semantics frame edges off the cell lattice; a DrawCommand
   projection can only produce an ANSI *screenshot* of already-quantized pixels
   and keeps none of the role/focus/action identity a TUI needs.
2. **The semantics tree carries laid-out-but-invisible nodes.** 64 of showcase's
   124 nodes are outside the viewport (stacked route bodies). Clamping them
   instead of clipping folds them onto the boundary row and turns it to noise —
   the projection must clip exactly where a pixel renderer would apply
   `clip_rect`.
3. **Overlap repair needs ownership, not paint order alone.** Rule that works
   (`moui_tests/tui_spike/projection.mbt:82-101`): BFS from the root; per-cell
   owner with priorities 1=container chrome, 2=container title, 3=leaf content;
   higher priority wins, equal priority is first-come-first-served; each paint is
   clipped to the node's own quantized box and wraps inside it. Without this,
   adjacent boxes that overlap by one quantized cell interleave letters.
4. **Semantics identity is sparser than layout**: 124 semantics nodes against 415
   layout nodes for showcase, and only 5 of the 40 `SemanticsRole` variants
   appear. A TUI that leans on semantics inherits that gap; controls that carry
   no semantic identity must degrade visibly, never silently.

## What the renderer contract can and cannot carry

Investigated because S2 of the goal asks for a `moui_tui_renderer` whose input is
the semantics tree.

- `RendererSession::new(render_frame= (RenderFrameSubmission) -> RenderFrameResult)`
  and `RenderFrameSubmission` wraps `@core.DrawFrame`
  (`moui/render/renderer_events.mbt:37-48`, `moui/core/damage.mbt:22-31`):
  `commands`, `platform_views`, `overlay_bounds`, `damage`, `clear_color`.
  **There is no semantics field, and "semantics" appears nowhere in
  `moui/render/**`.**
- `HostSurfaceCapability.cpu_present() -> PresentTarget?` and
  `PresentTarget.present : (PixelFrame) -> Bool` with
  `PixelFrame{width,height,row_bytes,scale_factor,pixels : Bytes}` RGBA8
  (`moui/render/surface_context.mbt:3-20,50-61,258-264`). A "terminal renderer"
  bound this way would have to smuggle ANSI through a pixel buffer.
- A live app does **not** need the renderer path at all. `HostRuntimeDriver`
  (`moui/runtime/host_runtime_driver.mbt`, `pub(all)`, no surface required)
  already routes `@backend.Event{Keyboard,Pointer,Scroll,Resized,TextInput,Focus,
  ThemeChanged,Command,RedrawRequested,CloseRequested}` into the runtime, pumps
  effects/subscriptions synchronously through `dispatch_event`, advances the
  animation clock in `begin_redraw`, and exposes `read_semantics()`,
  `set_text_system()`, `size()`, `event_result()`. `moui_agent/host.mbt` and
  `examples/mo_desktop/app/mo_desktop_app_test.mbt:1093-1108,447-459` already
  drive live programs this way with no renderer.
- Two cosmetic gaps: resize goes through `dispatch_event(Resize(size))` (no
  `AppRuntime::resize`), and `AppBuilder::run()` aborts unless at least one
  renderer provider is registered (`moui/runtime/app_builder.mbt:136-150`), so a
  semantics-only host either skips `AppBuilder` or supplies a stub provider
  (`moui/runtime/app_builder_test.mbt:11-25`).

## Decision options (surveyed 2026-10-14)

The goal names `moui_tui_renderer` with semantics input. That combination is not
reachable through the current renderer contract, and the only ways to make it
literal each cost something:

- **Option A — host-owned projection, no core/runtime change (recommended).**
  `moui_tui` (pure MoonBit): cell `TextSystem`, cell buffer with damage/revision
  and CJK double width, semantics→cell projection carrying the S0 mapping table
  and ownership rule, ANSI encoder. `moui_terminal_host`: termios raw mode,
  SIGWINCH, stdin reader, SGR(1006) mouse decode, all emitted as
  `@backend.Event` into `HostRuntimeDriver`. No `RendererProvider`; the
  composition root declares the terminal host explicitly. Cost: the goal's S2
  module name and its "renderer" classification do not exist, so
  `docs/renderer-capability-report.md` and `checks/release-modules.json` gain a
  host/output-path entry instead of a renderer entry, and R1/R7 wording needs a
  note that a TUI is not a renderer.
- **Option B — extend the frame contract with semantics.** Add a semantics
  payload to `@core.DrawFrame` (or a new submission variant) so
  `moui_tui_renderer` can be a real `RendererProvider`. Cost: a `moui/core`
  change on the hot path every renderer constructs per frame, plus P6/P11 render
  budget review, plus every existing renderer and the capability report needs
  re-verification. This is the change the goal says requires sign-off, and it is
  the only option that satisfies S2 verbatim.
- **Option C — `moui_tui_renderer` over DrawCommands only.** Ship a pure-MoonBit
  renderer today with no core change. Cost: it is an ANSI screenshot — no role,
  no focus ring, no actions, no clipping of invisible nodes (finding 2), and it
  silently loses the interaction model the rest of the goal asks for. Not
  recommended beyond a demo.

Outcome: the owner chose **Option B** on 2026-10-14, on the architecture and
long-term-maintainability axis (one composition idiom, homogeneous gates and
capability reporting, and every renderer — including future agent hosts — gains
structured frame input). The cost accepted is the `moui/core` published-type
churn and the re-verification of every existing renderer. A stands as the
fallback if B's payload ever proves to be a per-frame tax.

### Option D — semantics as a surface capability (found while surveying blast radius)

`HostSurface::new` already takes every capability as an optional labelled
argument, and in-repo it is constructed at 7 backend sites plus tests
(`moui/backend/{macos,linux,windows,web,wechat}/…`,
`moui/backend/common/embedded/hosted_window_backend.mbt:72`), while the only
`HostSurfaceCapability` implementor is `ClosureHostSurfaceCapability` inside
`moui/render` itself (`surface_context.mbt:276-311`). So one more optional
member is a contained `moui/render` change, not a core change:

- add `semantics? : SemanticsSource?` to `HostSurface` (a closure returning the
  last committed `Array[@core.SemanticsNode]` — the node type already lives in
  core), alongside a cell/ANSI present target;
- `moui_tui_renderer` binds only when the surface offers a semantics source, so
  it is a real `RendererProvider` and `docs/renderer-capability-report.md` plus
  `smoke/gates.json` stay homogeneous with every other output backend;
- cost: one more `RendererBackendKind` variant, which means every exhaustive
  match on it gains a branch, plus `moon info` / api-surface regeneration.

The hazard to design around: `read_semantics()` self-commits
(`commit_semantics → rebuild_if_possible(); ensure_layout_tree()`), so calling it
from inside `render_frame` would re-enter layout during the paint pass. The
terminal host must commit after dispatch and hand the renderer a cached snapshot.

### Comparison on the two axes that matter

| axis | A host-owned | B frame carries semantics | D surface capability |
|---|---|---|---|
| package touched | none | `moui/core` + all renderers re-verified | `moui/render` only |
| composition idiom | two (needs a never-renders stub provider) | one | one |
| gate/report homogeneity | new vocabulary | same as other renderers | same as other renderers |
| spillover value | none | every renderer gains structure (agent hosts, a11y parity, semantic coverage) | opt-in per renderer |
| main risk | long-term drift between two startup paths | per-frame payload + published-type churn, needs RFC | layout re-entrancy if semantics is read during paint |
| rollback radius | smallest | largest | medium |

Maintainability ranks B > D > A; cost and blast radius rank A > D > B. The owner
traded the largest rollback radius (B) for the single composition idiom and the
spillover value to every other renderer.

## Option B implementation evidence (2026-10-14)

Ship-shape constraint set by the approval: this is a **carrier** change only.
Cell quantization, viewport clipping and overlap repair stay in the consuming
renderer; pixel hosts must not pay for the field.

| Change | File | Evidence |
|---|---|---|
| `SemanticsFramePayload` — `pub struct` with `priv` fields, derives `Eq, Debug, ToJson`, accessors return fresh projections | `moui/core/semantics.mbt` | `moon test moui/core` covers "draw frame semantics payload is opt-in and copy-protected": a consumer that pushes onto `payload.nodes()` still sees `node_count() == 1` |
| `DrawFrame` gains `semantics : SemanticsFramePayload?`; `DrawFrame::new` gains an optional `semantics?` arg defaulting to `None` | `moui/core/damage.mbt` | the ~30 existing `DrawFrame::new` call sites (skia / web / sun renderers, backend tests) compile unchanged; no positional record literal of `DrawFrame` exists in the repo |
| `frames_carry_semantics` opt-in flag on the semantics subsystem, default `false`; `RuntimeState::frame_semantics_payload()` reads the **already committed** snapshot (`cached_semantics()`) and runs before command collection | `moui/runtime/runtime_state.mbt` | commit is re-entrancy-guarded and short-circuits when `!dirty.needs_semantics`, so no layout re-entry during paint; payload and commands describe the same settled tree |
| `AppRuntime::set_semantics_frames_enabled(enabled)` | `moui/runtime/runtime.mbt` | contract test "semantics frames are opt-in and carry the committed snapshot": frame is `None` before, carries the committed generation/root/nodes after, and returns to `None` when switched off (`moui/runtime/draw_frame_contract_wbtest.mbt`) |
| `SemanticsFramePayload` added to the runtime `using @core` list | `moui/runtime/core_type.mbt` | — |
| Renderer contract untouched | `moui/render` | `RenderFrameSubmission::frame()` already hands out the `pub(all) DrawFrame`, so `frame.semantics` is reachable; P11 provider/session budgets unchanged (`moon test moui/render moui/render/common moui/backend/common` = 54/54) |

Gates: `moon check` clean; `moon test moui/core moui/runtime --target native` =
259/259; `moon test moui_tests/tui_spike --target native` = 6/6; `moon info`
surface diff reviewed; all six pre-push static validators green, with these
ratchets settled to the measured values and a reason recorded next to each:
`moui/runtime/runtime.mbt` 470→479 lines, core mbti 2760→2766 lines /
1154→1165 pub, runtime mbti 889→890 lines / 595→596 pub,
`advanced_core_protocol` 1166→1177, `runtime_diagnostic` 595→596.

## S1 implementation evidence (2026-10-15)

`wzzc-dev/moui_tui@0.1.0` (`moui_tui/`) is the cell buffer the TUI renderer and
the terminal emulator example share. It has **zero module dependencies** and is
pure MoonBit (`+native+wasm-gc`), so it can be published and consumed without
dragging the MoUI stack along.

Shape decisions, with the alternative that was rejected:

| Decision | Why | Rejected alternative |
|---|---|---|
| One cohesive `TermScreen` (VT ops + damage) rather than a bare `CellBuffer` plus a VT layer | S2's projector needs scrolling, resize-reflow and damage; a second buffer abstraction would duplicate exactly the logic that is hard to get right, and the two would drift | `CellBuffer` (dumb grid) + `TermScreen` on top — two sources of truth for scroll region and resize |
| Fields `priv`, accessors for cross-package reads | the buffer is an invariant holder (row length ≡ `cols`, continuation cell always follows a wide cell); public fields would let a projector break it | `pub(all) struct` as the example had — fine inside one package, wrong once published |
| Catalogued as role `binding` at stage `base-bindings` | `validate_dependency_direction` forbids a `renderers`-stage module depending on a later stage, so `moui_tui_renderer` (S2) can only consume it from the base stage | registering it with the renderers — S2 could not depend on it |
| Damage is **content-only** | cursor moves, SGR changes, scroll-region and title changes do not alter the grid; marking them dirty would repaint whole screens and defeat the point of the revision counter | "anything that touched the model" dirtying |

New surface beyond the moved code:

- `damage.mbt` / `Damage { full, rows }` — `take_damage()` drains: `full=true`
  when the whole grid is suspect (ED 3, `reset`, `clear_all`, size-changing
  `resize`), otherwise ascending dirty row indices. `revision` increments once
  per clean→dirty transition, so a presenter can coalesce frames and skip
  unchanged rows.
- `continuation_cell(attrs)` — `width == 0`, contributes no text but inherits
  the background, which is how a CJK wide cell occupies its right half without
  `runs()` emitting a second fragment (`runs()` also skips `width == 0`).
- `put(y, x, ch, width, attrs) -> Bool` and `erase_cells(y, from, to, attrs)` —
  cell-address writes for a projector that positions by box, not by cursor.
  `put` returns `false` on out-of-bounds and on a wide char at the last column,
  which is the signal S2 records as a drop diagnostic. The three erase ops were
  consolidated onto `erase_cells`.
- `set_auto_wrap` (DECAWM) — the example's `vt_parser.mbt:305` wrote the field
  directly; cross-package it needs a setter. Repo-wide grep confirms it was the
  only remaining direct field write outside the module.
- `unicode_width` moved here from `vt_parser.mbt` (single table now feeds both
  the emulator and the renderer).

Same-size `resize` produces no damage; cursor/attr/title/scroll-region setters
produce none.

Gates: `moon test moui_tui --target native` = 22/22 (13 VT tests moved from the
example plus 9 damage/width/continuation tests),
`moon test examples/terminal/app` = 34/34, `moon test moui_tui examples/terminal/app moui_tests/tui_spike`
= 62/62. `examples/terminal/app/{screen.mbt,screen_test.mbt}` deleted; the
example imports `"wzzc-dev/moui_tui" @tui` and `examples/terminal/moon.mod`
pins `wzzc-dev/moui_tui@0.1.0`. `moon info` regenerated both mbti files (the
example's now cites `@moui_tui.TermScreen`). All six pre-push validators green;
`node scripts/generate-repo-docs.mjs --write` records `./moui_tui` as a
workspace member.

## S2 implementation evidence (2026-10-15)

`wzzc-dev/moui_tui_renderer@0.1.0` (`moui_tui_renderer/`) is a real
`RendererProvider` over `frame.semantics`. Pure MoonBit: no `link`, no C stub, no
GPU — `moon.pkg` is native-only and the module imports only
`wzzc-dev/moui` (core/render/render-common) and `wzzc-dev/moui_tui`.

| File | Responsibility |
|---|---|
| `renderer.mbt` | `TuiRenderer` (frame → grid → ANSI) and `TuiSink` (byte outlet); zero-damage frames return `presented=false` and emit nothing |
| `canvas.mbt` | ownership layer above `TermScreen`: paint sequence + priority per paint, stale-cell sweep at frame end, **final-grid damage diff**, focus/selection overlay (band over every cell, line decoration only over claimed ones — see the S5 addendum 2 below) |
| `project.mbt` | `quantize` (keep only cells whose centre the frame covers, clamp to viewport; see the S5 addendum below), BFS paint order with stray tail, per-paint clip, off-screen node count |
| `cell.mbt` | `CellBox` 8x16, `cell_text_system` measuring in cells so layout and projection agree on units |
| `roles.mbt` | the S0 `SemanticsRole` → cell mapping table, `node_text` precedence (label → value → description), `attrs_for` focus/selection styling |
| `degrade.mbt` | `DegradeLog` + `note_dropped_commands`: pixel-only commands are named, never swallowed |
| `capabilities.mbt` | 17 `RendererFeature` cells for provider `tui-ansi` / `TerminalAnsiNative` |
| `ansi.mbt` | SGR encoder, `runs()` → text segments, `frame_update` (row locate + `ESC[2K`, or `ESC[2J ESC[H` on full damage) |
| `binding_factory.mbt` | `ansi()` provider + `TuiRenderer::to_renderer_session()` |

### Decisions and the alternatives they reject

1. **Semantics in, pixel commands out — visibly.** Every `DrawCommand` and
   `PlatformViewPlacement` becomes a named degrade record and the node still
   occupies a cell (`[image]`, `[web-view]`). Rejected: drawing nothing, which is
   how S0 finding 4 (semantics identity is sparser than layout) would turn into
   silently invisible controls.
2. **Two new render-protocol enum members** (`RendererBackendKind::TerminalAnsiNative`,
   `RendererFamily::Terminal`). The goal's ban is on new `@core` *view* variants;
   the backend enum is the designed open-extension point (ADR 0007), and the
   cost is exactly what Option D predicted: every exhaustive match gains a
   branch and `moui/render/pkg.generated.mbti` grew 604→606 lines (budget ratchet
   updated with the reason next to it).
3. **`TuiSink` instead of `cpu_present()`.** `PresentTarget` is bound to
   `PixelFrame{width,row_bytes,scale_factor,pixels}`; pushing an ANSI byte stream
   through it would force the protocol to invent a fake pixel frame. The
   deviation is one struct at one seam, and `host_surface_metrics_error` stays
   the shared bind gate, so a zero-sized surface is rejected identically for
   every renderer (`moui_tui_renderer/renderer_test.mbt` asserts both sides).
4. **Damage is decided by the final grid, not by write-time dirtiness.** This was
   found by the evidence suite, not by review: the projector writes the same cell
   several times per frame (border → content steal → frame-end sweep), so the
   buffer's per-write `mark_row` dirtied rows whose final content was identical.
   The first captured delta proved it — an unchanged tree still emitted
   `ESC[1;1H ESC[2K ╭Files…`. The fix lives in `Canvas`: `present_update` drains
   `take_damage()` as a *candidate row set*, compares each candidate row against
   the grid last written to the terminal (`sent`), and encodes only rows that
   actually differ; a size change forces one full rebuild so shrink-window residue
   is cleared. Rejected: coarsening `@moui_tui`'s damage granularity — write-time
   dirtying is correct for a VT-isomorphic buffer (and the terminal-emulator
   example depends on it), and the owner's constraint puts projection policy in
   the renderer.
5. **`begin_frame` does not clear the screen.** It swaps owner/width masks and
   keeps the retained buffer, so unchanged cells stay byte-identical;
   `sweep_stale` erases only cells this frame did not claim. Without this, every
   frame would repaint every row that ever had content and decision 4 would have
   nothing to diff against.
6. **`recover` always reports success.** There are no GPU resources to lose and
   no CPU fallback to take — the cell projection *is* the final output. A fake
   `FallbackToCpu` would be a lie the session contract then rewards.

### Measured behaviour

- `moon test moui_tui moui_tui_renderer --target native` = 43/43 (21 in the
  renderer: 10 projection/z-order, 11 output/provider),
  `moon test moui_tests/tui_spike --target native` = 6/6 still green.
- Unchanged frame: 0 bytes, `present_count` stays 1 while `frame_count` = 2.
  First paint of a 20x6 grid = 378 bytes. Dropping one node or relabelling one
  line emits exactly one row locate; resize to 30x6 emits `ESC[2J` + 6 locates.
- Degrade sources named for a frame full of pixel commands: `draw-image,
  draw-path, draw-shader-effect, draw-shadow, push-filter, gradient-brush,
  platform-view` (plus `role-image`, `role-web-view`, `offscreen-nodes`,
  `missing-semantics`); a solid brush and a plain `draw-text` are *not* reported,
  so the log cannot degenerate into noise.
- Capability table is total (17 features, distinct, all `tui-ansi`) and honest
  about the lattice: Text/Rect `Supported`, Opacity `Partial`,
  Image/Shadow/Transform `Gap`. Since S6 the column is machine-checked, not
  prose: `validate-renderer-capability-consistency` reports 68 cells (17 features
  × 4 self-reporting renderers) matching the code.

Gates: `moon fmt` + `moon info` clean; the six pre-push validators green;
`validate-renderer-provider-open-extension` check 2 (catalog-derived, so the new
renderer is covered automatically) initially missed the factory because its
signature regex could not parse labelled defaults — the regex was made
paren-tolerant instead of reshaping the public API; `checks/release-modules.json`
gains `moui_tui_renderer` (role `renderer`, stage `renderers`);
`node scripts/generate-repo-docs.mjs --write` records both new directories and
the new render-protocol line count.

## S3 design (2026-10-15) — the routing gate does not need opening

S3's last clause ("键位路由要策略化（capture/bubble + 认领结果），方向键等编辑键
不再被单一控件独占，上层 widget 可优先认领") is the only part of the plan that
could have forced a `moui/runtime` change, so it was surveyed before any code was
written. It does not. **Keyboard policy is already a typed, ordered, app-facing
mechanism**, and an app can claim an editing key ahead of the focused control
with public API:

| pass | code | who gets the key first |
|---|---|---|
| 1 top-most dismissal | `runtime_events.mbt:109` (`dispatch_dismissal_layers`) | overlay hosts, `KeyboardPolicy::TopMostDismissal` |
| 2 tree shortcut scope | `runtime_events.mbt:113` → `input_keyboard.mbt:54-133` | a `ShortcutScope` ancestor, *before* its children; `changed`/`activated` is the claim result and short-circuits passes 3-5 |
| 3 **program bindings** | `runtime_events.mbt:128` (`action_commands.dispatch_shortcut`) | the `Program`'s own `ActionCommand` keymap |
| 4 Tab | `runtime_events.mbt:131-165` | focus traversal, unless `accepts_tab_input(target)` |
| 5 focused element | `runtime_events.mbt:166-189` → `input_keyboard.mbt:2-51` | only the focused node, only if nothing claimed the key |

The app-facing entry is pass 3: `Program::with_commands(commands=model =>
[ProgramCommand::new(command=ActionCommand::new(intent=…, shortcut=Some(
KeyboardShortcut::new(key="ArrowUp"))), message=…)])` (`moui/core/program_command_test.mbt:13-29`),
synced into the runtime's `ActionCommandMap` on every model update
(`runtime.mbt:108-124`), with `ActionCommand`/`ActionCommandMap`/`CommandBinding`/
`KeyboardShortcut` re-exported through `@moui/views`
(`moui/views/views.mbt:367-374`). Because the bindings are *derived from the
model each update*, a two-panel TUI expresses per-panel routing by returning only
the active panel's bindings — the model already knows which panel has focus.
`KeyboardShortcut::matches` (`moui/core/view_style.mbt:241-246`) demands
`pressed && key == … && modifiers == …`, so a bare-`ArrowUp` binding against
`KeyModifiers::none()` claims it while a `TextInput` holds focus, and a
`Shift-ArrowUp` binding still falls through to pass 5 for selection editing. That
is capture/bubble with a claim result, using existing vocabulary.

Two consequences recorded so nobody re-litigates them:

- A `Composer`-style text control is **not** a monopoly on arrows by design; it
  only ever sees the key at pass 5. The earlier "Composer 独占方向键" symptom is
  therefore an *absent binding set*, not a routing defect. No `moui/core` or
  `moui/runtime` edit is planned, and the standing constraint to stop for
  approval before touching them is **not triggered by S3**.
- Pass 2's `keyboard_shortcut` modifier claims but carries no payload
  (`modifier_event.mbt:526-539` returns `captured`/`activated` with no message),
  so it is a blocker, not a binder. Apps bind keys at pass 3; pass 2 is for
  suppression. Worth knowing before someone tries to route through it.

### Module shape

`moui_terminal_host` (working name), catalogued `role: addon`,
`releaseStage: addons` — the same stage/role as `moui_agent`, the other host that
owns no window. `addons` is after `renderers`, so `validate_dependency_direction`
permits it to consume `moui_tui_renderer` (a `renderers`-stage module);
`base-bindings` would not. `supported_targets = "native"`, `native-stub` links one
C file, following `examples/terminal/pty_host/moon.pkg:10-15`.

| file | responsibility | target |
|---|---|---|
| `tty_stub.c` | `isatty`, `tcgetattr`/`tcsetattr` raw-mode save/restore, `TIOCGWINSZ`, blocking `read`, `write(1)`, `poll` timeout, `signal(SIGWINCH)`→volatile flag | C |
| `tty_fd.mbt` | `extern` declarations + a `Tty` value: fd, saved termios handle, size, `enter_raw`/`leave_raw`, `poll`/`read`/`write` | native |
| `key_decode.mbt` | byte stream → `@core.KeyboardEvent` list; **pure MoonBit** | all |
| `mouse_decode.mbt` | SGR(1006) → `@core.PointerEvent` / wheel, cell→logical px | all |
| `input_channel.mbt` | the three channels assembled through `@backend_common.InputState` (`input_state.mbt:70-112`) | all |
| `terminal_host.mbt` | `TerminalHost`: alt-screen + mouse-mode set/restore, `HostRuntimeDriver` pump, present via the bound TUI session, resize reflow, quit | native |

The decode layer is deliberately native-free: it is the part with the most
surfaces to get wrong (escape-sequence ambiguity, modifier bits, drag vs. motion)
and the part that can be gated without a TTY.

### Key-name table

`examples/terminal/addon/input_encoding.mbt:41-91` already fixes the runtime's
canonical key names — the terminal emulator side encodes `@core.KeyboardEvent` →
bytes with it, so the host decoder must be its exact inverse or the same key names
would exist in two vocabularies: `Enter` `\r`, `Backspace` 0x7F, `Tab` `\t`,
`Escape` 0x1B, `ArrowUp/Down/Right/Left` `ESC[A/B/C/D`, `Home`/`End` `ESC[H/F`,
`PageUp`/`PageDown` `ESC[5~/6~`, `Delete`/`Insert` `ESC[3~/2~`, `F1`–`F4` `ESC[OP…OS`,
`F5`–`F12` `ESC[15~…24~`, control letters 1–26, printable → `text`.

### Decisions, with the alternative that was rejected

| Decision | Why | Rejected alternative |
|---|---|---|
| Keyboard routing stays as-is; the TUI app declares `with_commands` bindings | the five-pass chain already gives the app a claim point that runs before the focused control | a `moui/runtime` "TUI key router" — a second routing vocabulary on the hot path every app pays for, and the change the hard constraint says to stop and ask about |
| Host is a published `addons`-stage module, not `examples/terminal/native/main.mbt` only | S4's split demo and S5's counter must share one TTY owner; duplicating raw-mode/restore logic across two entrypoints is how a terminal app leaves a user's shell in raw mode | per-example entrypoints with copied stubs — `moui_agent` is the precedent for a reusable host |
| Drive `HostRuntimeDriver::dispatch` from a synchronous loop | dispatch is already synchronous (`host_runtime_driver.mbt:30-89`) and the loop owns the frame cadence, so "keypress → update → present" fits one iteration; instant keys need no scheduler | `HostEventSource::publish` + `Subscription::host_event` (`subscription_adapters.mbt:138-154`) — designed for async host streams, adds a hop and a wake channel the TTY loop already is |
| Present by binding the `tui_renderer.ansi(sink~)` provider and calling `session.render_frame(RenderFrameSubmission::new(…))` | keeps Option B's single composition idiom (the renderer is a real `RendererProvider`) without inventing a second entry point; `RenderFrameSubmission::new` is public (`renderer_events.mbt:43-48`) | `TuiRenderer::new(...)` called directly — bypasses the provider contract S2 exists to satisfy |
| SIGWINCH sets a volatile flag the `poll` timeout reads | signal handlers can only do async-signal-safe work, and a MoonBit closure cannot be one; the flag+poll tick is the standard portable answer | self-pipe / `signalfd` — correct but Linux-and-macOS-specific plumbing for an effect that is already bounded by the poll timeout |
| Raw-mode exit is idempotent and also wired to `SIGINT`/`SIGTERM` | `moon run` under Ctrl-C must not strand the terminal without echo; one restore function guarded by the saved-termios handle | restoring only on the normal return path |

### Three channels, none swallowed

- **Keyboard**: each decoded byte group emits `Keyboard(KeyboardEvent::new(key,
  text, pressed=true, repeat))`; `repeat` comes from the DECCKM/cursor-key `1;`
  marker when present, so a held key and a discrete press are distinguishable.
  Dispatch is per-key, not per-line — no commit gate exists in this path.
- **Mouse**: `ESC[<btn;col;rowM/m>` → `Pointer(PointerEvent::new(position=
  Point(col-1)*cell_w, (row-1)*cell_h, phase=Down/Moved/Up, button))`; wheel →
  `Scroll(HostScrollEvent::new(delta=Lines(0, ±1)))`. Button bit 3 distinguishes
  wheel from press; `m`/`M` distinguishes press from release. Modes `?1000;1003`
  are written at enter and reverted at leave.
- **Size**: the flag tick re-reads `TIOCGWINSZ`; a changed cell count becomes
  `Resized(SurfaceMetrics::from_logical(size=cols*cell_w, rows*cell_h))`, which
  the driver turns into `Resize` + `request_redraw` (`host_runtime_driver.mbt:35-38`)
  and the session's `resize` sets the S2 `rebuild` flag, so the next frame is a
  full-grid rebuild — stale columns from a wider terminal cannot survive.

### Gates planned

`moon test moui_tui moui_tui_renderer moui_terminal_host --target native` plus the
existing combined set; decode tests are table-driven against the key-name table
above and must cover: split escape sequence across two reads, `ESC[1;5A`-style
modifier+repeat, SGR mouse press/move/release/wheel, a wide-cell click landing in
the right logical box. Real-terminal behaviour is *not* provable by `moon test` —
S5 is where the six interactions get human verification, and until then this
section's claims are "compiles and decodes", not "runs in Terminal.app".

## S3 implementation evidence (2026-10-15)

`wzzc-dev/moui_terminal_host@0.1.0` (`moui_terminal_host/`) is the TTY owner:
probe → bind renderer → enter modes → pump → restore. 2532 lines total
(`decode.mbt` 790, `terminal_host.mbt` 449, `input_channel_test.mbt` 340,
`decode_test.mbt` 336, `tty_stub.c` 248, `input_channel.mbt` 199, `tty.mbt` 170).
Native-only; the C bridge describes fd facts and nothing else.

| File | Shipped vs. the design above |
|---|---|
| `tty_stub.c` | as planned: `isatty`, save-and-enter raw (keeping `ISIG`), `TIOCGWINSZ`, `poll` with `EINTR`→winch handling, `read`, full-write loop, `sigaction` for WINCH/INT/TERM/HUP. Non-Unix branch returns failures so the degrade path is compiled, not assumed |
| `tty.mbt` | planned `tty_fd.mbt`, renamed: one value type over `(in_fd, out_fd)` plus `enter_raw`/`restore`/`grid`/`wait`/`take_input`/`write_text`/`take_resize_signal`, all failure-returning |
| `decode.mbt` | **the design's two decode files became one.** A split keyboard/mouse decoder would need two byte buffers and two partial-sequence state machines for prefixes (`ESC [ <`) that both halves must see; the ambiguity is in the shared prefix, so the buffer is shared. Output is a `TerminalEvent{Key,Text,Mouse,Wheel}` sum, key names inverted from `examples/terminal/addon/input_encoding.mbt` as planned |
| `input_channel.mbt` | as planned: `TerminalEvent` → `@backend.Event` through `@backend_common.InputState`/`SurfaceState` with a `HostInputContract` (`pointer/scroll/keyboard/text_input` on, `focus` off) |
| `terminal_host.mbt` | as planned: `run_program` / `run_view` generic entry points, `TerminalState` singleton, `attach`/`open_session`/`pump`/`reflow`/`render_frame`/`shutdown`, `TerminalExit` for every failure cell |

### Decisions taken while building, with what they reject

| Decision | Why | Rejected alternative |
|---|---|---|
| FFI failures return `String?`, not `raise` | MoonBit's error type is **erased** at the catch site — a host that `try/catch`es gets `Error`, not the message, and `TerminalExit` needs raw-mode, signal-install and write failures as three different cells. Return values also keep the `TuiSink::write` outlet pure (it must be a pure function) | `-> Unit raise(String)`, which is not even valid syntax here (parse error 3002); `fail(String)` + `try/catch` would have thrown away the reason the user needs |
| `attach` (renderer bind) runs **before** `enter_raw` | if the bind is rejected the terminal was never touched, so the restore path is a no-op rather than a guess about what mode is live | raw-then-bind, which needs a "was I ever in raw mode?" flag on the failure path anyway |
| `modes_active` set only after a successful `write_text(ENTER_MODES)` | shutdown must not emit `EXIT_MODES` (mouse-off, kitty-pop, leave-alt-screen) at a terminal that never received the enter sequence | unconditional teardown: it writes escape bytes into a main-screen shell |
| Bind one explicit provider (`tui_renderer.ansi(sink~)`) instead of `resolve_renderer` | the composition root must *declare* its renderer (goal S3), and a multi-provider negotiation failure would replace the renderer's own rejection string with a generic "no provider" — the reason a user sees when a 0-sized grid is rejected is worth more than the abstraction | `moui/render/common` selection, which is for hosts that genuinely have several candidates |
| `ESC[>3u` (kitty flags 1+2) requested at entry, `ESC[<u` popped at exit | flag 2 is what makes **repeat and release** observable; without it a held key and a discrete press are the same byte stream, which goal S3 explicitly forbids. Legacy terminals ignore the push and keep sending press-only sequences, so the decoder stays correct for both | CSI-u-only decoding, or not asking at all: the "repeat 与 release 可区分" clause becomes unimplementable |
| Enter/exit protocol bytes are one bundled write each | every write is a syscall, and a split sequence leaves a gap between "alt screen on" and "mouse on" where a click is delivered to the shell as text | per-mode writes |
| Idle `poll` timeout is also the bare-`ESC` disambiguation window (50 ms) | `flush()` settles exactly one pending `ESC` into `Escape`; anything else in the buffer is a prefix that can no longer complete and is dropped, so a stray `ESC [` cannot corrupt the next keypress | a timer thread, or dispatching `Escape` eagerly (which splits `ESC [ A` into Escape + garbage) |
| Keyboard channel carries **no** text; insertion is a separate `TextInput` event | the text input view reads `event.text` (`moui/views/text/text_input_event_handlers.mbt:234`), so carrying it in both channels inserts every character twice | the `examples/terminal` habit of one event with both halves |
| Wheel becomes `Pointer(wheel_delta=±cell_height)`, not `HostScrollEvent` | the `Scroll` path hardcodes a 40-px line height and drops modifiers (`moui/backend/input_host_state.mbt:150`); a terminal's line height is the cell, and Ctrl+wheel must survive to the app | reusing the shared scroll wrapper, i.e. losing both facts |
| SGR button numbers are transposed to core numbering (1↔2) | terminal is 0-left/1-middle/2-right, core is 0-left/1-right/2-middle (`moui/backend/common/input/window_event_decode.mbt:127`); passing through swaps middle and right clicks silently | passthrough |
| `Drag` with `button=3` (1003 hover) emits `Move`; `Press`/`Release` with `button=3` are dropped | hover is the only source for hover highlighting, while "no button pressed" plus press is a contradiction that would leave a widget stuck in the pressed state | dropping hover too (found by the channel test, which initially asserted the wrong thing) |
| Resize dispatch re-lays-out **and** forces a full repaint | `Resized(metrics)` is a viewport fact the runtime turns into update→layout→present, and `session.resize` sets the S2 rebuild flag so the next frame carries `damage.full` → `ESC[2J ESC[H`; an incremental write never touches cells that are now off-viewport, which is exactly the residue goal S3 names | re-reading the grid and re-drawing only dirty rows |
| Host prints **nothing** between frames; every exit message is deferred to `TerminalExit::describe` | the renderer addresses rows absolutely (`ESC[{row};1H`) inside the alt screen, so any host text interleaved with a frame is invisible corruption; the reason is shown after `EXIT_MODES` restores the main screen | writing the error to stdout before teardown |

### Three channels, verified without a TTY

`moon test moui_terminal_host --target native` = 20/20 (12 decode + 8 channel).
The channel suite pins, per the goal's clause list: `pressed`/`repeat`/`released`
arrive as three distinguishable events with their modifiers and no text payload;
SGR press/release/drag/hover land in `@core.PointerEvent` at the **cell centre**
(`col 11, row 3` → `92,56` at 8x16), with the button table and the last-column
click inside the viewport; `resize(40,10)` emits `Resized(320x160 @1.0)` and the
channel keeps using the new metrics for later clicks. Decode covers a sequence
split across two reads, `ESC[1;5A` modifier codes, Shift-Tab, kitty
`1:1/1:2/1:3` event types, a CJK character split across reads, and DA1/CPR
reports consumed rather than turned into fake keypresses.

### What "lifecycle through `moui/backend/common`" does and does not mean here

The shared layer used is the input/surface protocol: `InputState` gates every
channel through `HostInputCapabilities` and the focus gate, `SurfaceState` owns
the metrics and produces the `Resized` fact. `transform_cross_platform_event` and
`PlatformSurfaceLifecycle` were checked and are **not** applicable: both are
shaped around `@window_core.WindowEvent` attach/detach callbacks, and a controlling
TTY has no such events — it is attached for the process's whole life, and the
terminal's "detach" is `Unavailable` from `poll`, which ends the pump. Recording
this so the next reader does not treat the omission as a gap.

### Still unproven after S3

Everything above is "compiles, decodes, dispatches". Raw mode, alt screen, SGR
mouse, kitty push and SIGWINCH are only observable against a real TTY, and
`moon test` runs with pipes, so `TerminalState::pump` has no unit coverage by
design. Goal S5 is where the six interactions get human verification, plus a
scripted-PTY smoke (modelled on `examples/terminal/pty_host`) registered in
`smoke/gates.json`. Until then no claim in this section says "runs in
Terminal.app".

## S4 implementation evidence (2026-10-15) — the split-layout proof app

`examples/tui_split/app` is the capability proof, built only from existing
composition: `column` / `row` / `expanded` / `text` / `container(border=…)` /
`scroll_view` / `selectable_list` / `tree_view` / `button`. No `@core.ViewNode`
implementation and no enum variant were added. 15 tests green under
`moon test examples/tui_split/app --target native`, plus a projection test in
`moui_tests/tui_spike` (8/8 green) that runs the same program through the cell
grid.

### Measured frames at 960x480

| What | Numbers |
| --- | --- |
| list `ScrollView` box | x=70 y=54.5 w=336 h=364.75 |
| `List` content box | x=70 y=54.5 w=336 h=572 — overflows its viewport by 207px |
| tree `ScrollView` box | x=542.4 y=98.875 w=359.2 h=276 |
| `Tree` content box | h=276 — fits at 480px height, overflows at 280px |
| `PushClip` rects in the draw stream | exactly 2, each equal to its own `ScrollView` frame, x-spans disjoint |
| pane border command | `StrokeRoundedRectBrush(rect, brush, 1.0)` — **zero** `StrokeRect`/`StrokeRoundedRect` |
| resize 960→1600 | left box x 70→230, right box x 542.4→1022.4; both clips follow |
| cell projection @120x30 | 97 semantics / 377 layout / 142 DrawCommand, roles `List=1 Tree=1 ScrollView=2 ListItem=16 TreeItem=7`, `off_grid_point=162`, worst 8px, `offscreen=14`, list text at column 10 vs tree text at column 78 |

### Decisions taken while building, with what they reject

- **Row counts are a test precondition, not a taste choice.** 16 entries and a
  fully expanded tree, with `content_overflows` asserted *before* each wheel
  test. Rejected: the natural 8-row demo, where the tree fits its viewport and
  "the tree stayed put" passes even if scrolling were broken.
- **Borders must be read as `StrokeRoundedRectBrush`.** The first border
  assertion failed because the draw stream contains no `StrokeRect` at all;
  `layout_views.container_box` strokes every `border=…` as a rounded-rect brush
  even at radius 0.0. A TUI renderer that maps only `StrokeRect` to box-drawing
  would render every pane frameless. Rejected: teaching the demo to draw its own
  rect strokes — that would hide the real contract from S2 instead of recording
  it.
- **Identity comes from keys, not positions.** Rows are `key("list-" + id)` /
  `key("tree-" + id)`, so head inserts keep selection (`sel=Entry 3` after `n`)
  and keyboard focus (`program.mbt` after `a`) on the same item. Rejected:
  re-deriving the selection by index after mutation, which silently follows the
  slot rather than the item.
- **Keyboard routing still needs no core change.** `runtime_events.mbt:105-191`
  gives the app's `Program::with_commands` claim *before* built-in Tab traversal
  and before target-only keyboard dispatch, so the demo legitimately owns Tab,
  Shift-Tab and the arrows. Rejected: the goal's "capture/bubble routing policy"
  inside `moui/runtime` — it would need plan approval, widen the routing
  protocol, and buys nothing the demo cannot already do.
- **Deleting a folder prunes its expansion ids** (`keep_live_ids`). Rejected:
  leaving stale ids, where re-creating `src/core` would make it start open by
  itself.
- **Proof helpers live in the test package.** `*_test.mbt` is its own package, so
  helpers qualify `@app.` and assert structure (`join(",")`, `length()`,
  per-role counts) instead of Debug reprs. Rejected: widening the app package's
  public surface just to reach package-private predicates.

### What S4 exposes for S2, and where the fix belongs

The projected grid shows list rows bleeding across the status line: the spike
paints every in-window node and clips only at the window edge, never at a pane's
own box. That is the renderer's job, and the data is already in the renderer's
input — `SemanticsNode.children` makes the snapshot a tree, so a leaf's box can
be intersected with each ancestor `ScrollView` frame before writing cells.
Rejected alternatives: adding a clip field to `SemanticsNode` (a `moui/core`
change for one output path) and reading `PushClip` from the draw stream (it is a
save/restore stack protocol, so a semantics-only projection would have to
re-simulate it). Per the approved Option B, quantization and clipping stay in
the consuming renderer; `moui/core` and `moui/runtime` are unchanged by S4.

### One `moui/runtime` defect that blocks S5, awaiting approval

`moui/runtime/runtime_events.mbt:431` prints
`[focus-dbg] constrained_ok=…` through `println` inside `RuntimeState::focus_key`.
Any TUI app that focuses programmatically writes that line straight into the ANSI
stream, corrupting the frame. `git blame` puts it on `8e26cde20a` (2026-10-06):
pre-existing on `main`, not introduced by this work, and
`moui/runtime/runtime_events.mbt` has no uncommitted changes. Fixing it is a
one-line deletion in `moui/runtime`, which the goal's hard constraint says needs
explicit approval first.

Rejected alternatives: filtering `[focus-dbg]` in the terminal backend (a
renderer would then depend on an unrelated runtime log format, and non-TUI output
still gets the noise); silencing stdout globally during focus changes (would hide
real app output, and the backend does not own the process's stdout). Workaround
in use until approval: `moui_tests/tui_spike` and `examples/tui_split` call only
`focus_next` and event dispatch, never `focus_key`, so no proof in this plan
depends on the broken path.

## S5 implementation evidence (2026-10-15) — the six interactions in a real PTY

`moui_tests/tui_pty_smoke` (white-box, `+native`) spawns
`examples/tui_split/terminal` on a real PTY through `examples/terminal/pty_host`,
writes raw input bytes, and replays the *whole* byte stream into a fixed
100x30 cell grid — `CSI r;cH` locate, `ESC[2K`, `ESC[2J`, SGR, and the DEC 1049
mode set/reset. Every assertion reads the reconstructed screen, never a byte
count: "how much did the renderer write" cannot show what a terminal displayed,
and this gate exists precisely to test the terminal-visible path.

`sh scripts/tui-pty-smoke.sh` builds both entrypoints and exports their absolute
paths (`MOUI_TUI_SMOKE_BIN` for the split app, `MOUI_TUI_COUNTER_BIN` for the
counter), pins `TERM=xterm-256color`, and runs the suite: **8 tests, 8 passed**.
Without those variables every test skips, so plain `moon test` never depends on a
build product. One command covers the goal's six items:

| Test | Proves |
|---|---|
| `startup projects the split grid with borders and clipped rows` | two panes, own borders, 16-row list clipped to the viewport, first frame is exactly one rebuild (30 row locates) |
| `Tab and Shift-Tab move focus across panes with a visible state` | focus crosses panel boundaries and the screen shows which pane holds it, both directions |
| `arrow keys move the selection inside the bordered list` | `sel=` follows Up/Down inside the bordered list; arrows are not owned by one editing widget |
| `a bare keypress acts without submission` | one byte (`n`, `a`) mutates the model and repaints — no CR/LF, no commit key |
| `space folds and unfolds the focused tree node` | tree node collapse/expand visible in the projected grid |
| `mouse click selects and wheel scrolls one pane only` | SGR(1006) click lands on the clicked row; wheel scrolls the hovered pane and leaves the sibling's `tree=` counter alone |
| `the row a button label is drawn on is the row that fires` | added by the S5 addendum below: in a 54x11 PTY the drawn `[-]` cell responds to a click and the row above it does not |
| `resize reflows with a full rebuild and leaves no ghosts` | shrink and grow both reflow through update→layout→present, selection survives, and no cell from the old layout survives |

Verified together: `moon test moui_tests/tui_spike moui_tui moui_tui_renderer
moui_terminal_host moui_tests/tui_pty_smoke --target native` → 85 passed, 0
failed.

### Decisions taken while building, with what they reject

**`resize` must blank the projection grid.** The first PTY run of the resize gate
failed, and it failed on a real defect visible in the raw stream: a 100-column
frame whose row 1 carried the 60-column header and row 16 read
`│ E│tEntry 1` — two layouts superposed. Two independent causes, both in
`moui_tui_renderer/canvas.mbt::Canvas::resize`:
`@moui_tui.TermScreen::resize` implements *terminal* semantics (keep content,
push the dropped top rows into scrollback), while the projection reads
`line_at(y)` as "visible row `y`" — after any shrink the encoder was publishing
scrollback snapshots; and leftover cells from the old layout survive into the
full-damage rebuild because `prev_owners` is reset at size change, so
`sweep_stale` has nothing to erase. The fix is renderer-local: on size change
`Canvas::resize` clears the screen (`clear_all`, which also drops scrollback) and
rebuilds `sent` at the new dimensions, keeping `rebuild=true` so the frame is
encoded as one `ESC[2J` rebuild. Rejected: relying on `ESC[2J` plus
`sweep_stale` (the terminal clears the display, the grid still holds the residue,
and `runs()` re-emits it — clearing the screen buys nothing); rejected: changing
`TermScreen::resize` to discard content (the buffer must stay VT-isomorphic for
the streaming app in `examples/terminal`, which is the reason it preserves
content in the first place). Regression is now caught in the fast suite, not only
in the PTY: `moui_tui_renderer` test `a shrink repaints the new grid, not the old
one` fails (`omega` missing from the emitted frame) when the `clear_all()` call
is removed — verified by removing it.

**DEC 1049 decodes as a blank slate.** The startup gate counts rebuilds, and the
first frame counted zero: the decoder treated the alt-screen switch as a no-op
while the renderer deliberately omits `ESC[2J` (the alt screen is already empty).
Teaching the decoder that `ESC[?1049h` leaves no dependable cells is the honest
fix. Rejected: emitting `ESC[2J` on the first frame to satisfy the decoder —
bytes paid by every real terminal, forever, to match a test harness.

**Sessions are serialized with one mutex.** The async test driver runs up to ten
tests concurrently, and the settle rule is a time fact ("250 ms with no new
bytes"): seven processes under test contending for one event loop starved each
other, so a frame arrived inside the quiet window and was read as partial.
Rejected: raising `QUIET_MS` to 1 s — that only moves the threshold (red
stays random) and makes every gate seven times slower.

**Status needles carry `=`.** `int_after("list")` matched the pane header
`focus: list` above the status row and read a number that does not exist; the
assertions now look for `list=` / `tree=`. Recorded because the failure looked
like a broken scroll, not like a ambiguous needle.

### Gate placement

`smoke/gates.json` registers `tui.pty-interaction-smoke` (nightly tier,
`kind: real-terminal-interaction-smoke`, command `mode: manual`,
`defaultDevCheck: false`). It is deliberately not wired into an automated CI
job: the harness decides frame completeness by timing and needs a POSIX PTY, so
the first honest home is the script run on demand. The entry also carries a
`ci` block (`workflow: .github/workflows/moui-runtime-gates.yml`,
`gate: manual-dispatch`); that is declared intent, not coverage — no workflow
file references this suite today (verified by grep). Adding a job there is
recorded as debt rather than claimed as coverage.

## S5 addendum (2026-10-15) — the label row was not the click row

Reported by the owner from a real terminal: `examples/counter` at 54x11 drew the
`[-] [Reset] [+]` labels one row *above* the area that responded, so a pointer had
to press below the label to hit the button.

Two independent measurements before any code moved:

- Headless geometry table over heights 11..30. `quantize` used the expanding rule
  (origin `floor`, extent `ceil - 1`) while
  [moui_terminal_host/input_channel.mbt:113](/Volumes/Data/Code/moon/MoUI/moui_terminal_host/input_channel.mbt#L113)
  turns a click into the cell **centre** (`y = (row + 0.5) * cell.height`). The two
  disagree exactly when a frame's top edge lands in the lower half of a cell
  (`frame_top mod 16 >= 8`): at 54x11 the button frame is y=110..146, the old rule
  painted its label on row 6 — whose centre, y=104, is above the frame — and only
  rows 7..8 fired. MISALIGNED at 54x11/13/15, aligned at 54x12/14/16/20/24/30,
  which is why the 100x30 PTY suite never saw it.
- Real PTY sweep (`Session::open` + one SGR click per row) reproduced the symptom
  end to end: label row 6, fired rows 7..8.

Fix, renderer-side, no `moui/core` or `moui/runtime` change: `quantize` keeps only
the cells whose centre lies inside the frame, so the drawn box *is* the hit box.
A frame narrower than half a cell (a separator) can contain no centre at all; it
falls back to the cell holding the frame origin — a row that cannot be clicked is
still drawn, nothing silently disappears.

Alternatives rejected:

- **Map clicks to the cell's top-left in the host.** The arithmetic does not fix it:
  the contested edge just moves to the bottom, and every non-clickable label sharing
  the row inherits the same ambiguity. In a cell grid the pointer *is* the centre.
- **Two rules in one grid** (centre for clickable roles, expanding for text). It
  re-splits rows that layout expects to share — a ListItem and its own text, or the
  two pane titles — so labels land on different rows than the boxes they name.
  Evidence: the split-demo pane-title assertion had to stop pinning a row number.
- **Let the border win the contested cell.** Restoring the root box's `╰` at 100x30
  meant writing `╰ab/arrow-lr pane`: the key-help line corrupted at its first
  character. S0's priority order (content 3 > chrome 1) already decided this — the
  corner is decoration, the line is information.
- **Changing hit-testing in `moui/runtime`** — owner-gated, and unnecessary once the
  projection picks cells by the same point the host clicks on.

Consequence worth naming: a cell-grid border costs a whole row, while MoUI's pixel
padding here is 4px — smaller than half a cell (8px). Where a Region's border row is
also a content row, the border loses and the frame stays visibly open on that side.
Box closure is therefore guarded where geometry leaves room (the fixture corners in
`moui_tui_renderer/projection_test.mbt`), plus one real-app assertion that *some*
row shows a closed bottom edge — not by pinning the root frame's last row.

Evidence:

- `moui_tui_renderer/projection_test.mbt` +3: the quantization contract itself, the
  general form ("every drawn row is hittable and every hittable row is drawn", swept
  over all 16 top-edge phases), and "a button label is drawn on a row the click can
  hit" using the counter's real 54x11 frame. All three were verified red against the
  old rule (rebuild with `floor`/`ceil` restored: `0 != 1`, `9 != 8`, then `false` is
  not true).
- `moui_tests/tui_pty_smoke` +1 interaction case: counter at 54x11 in a real PTY —
  clicking the drawn `[-]` cell decrements `Count`, and the row above it does not
  fire. Verified red against the old rule (`click: the drawn label row fires`).
  `scripts/tui-pty-smoke.sh` now also builds `examples/counter/terminal` and exports
  `MOUI_TUI_COUNTER_BIN`, because the case needs a widget whose label *is* the
  control; the split demo nests labels inside item nodes, which absorbs the phase
  error and cannot show this bug.
- Green after the fix: 28/28 renderer, 78/78 across
  `moon test moui_tui moui_tui_renderer moui_terminal_host moui_tests/tui_spike
  --target native`, 8/8 PTY interaction assertions (85 in total across the five TUI
  packages), `moon fmt --check`, `moon info`,
  and the six static validators.

## S5 addendum 2 (2026-10-15) — the focus band underlined cells nobody claimed

Same app, same terminal, reported by the owner: after clicking a counter button,
two yellow horizontal rules appeared under the button row.

A style probe in the real PTY (`Session::open` at 60x20, one SGR click on `[+]`,
then read every cell's parsed attributes back from the anti-encoder) put both
rules on exact cells:

- the focused button quantizes to a 3-row x 13-col box while its label `[-]`
  occupies 1 row x 3 cols;
- `Canvas::style_range` copies the node's attributes over the whole box and
  deliberately ignores ownership — that is what lets a list row highlight cells
  its *children* wrote;
- `attrs_for` gives a focused node `underline`, so the two fully blank rows below
  the label were written as *space + underline*: a rule with nothing under it.
  A third, shorter one trailed to the right of `[+]` (cols 40..49, also blank).

Fix, still renderer-side and still no `moui/core` / `moui/runtime` change:
`style_range` keeps the background/reverse band over unclaimed cells — that band
*is* the row highlight — but drops line decoration where `owners[y][x] == 0`.
A decoration belongs to a glyph; a line over a cell no node claimed this frame is
an artefact of the quantization box, not of the control.

Alternatives rejected:

- **Skip unclaimed cells in the overlay entirely.** The `Item` role writes no
  glyphs at all (S0: an item's text belongs to its children), so a selected list
  row would highlight only the few cells its label happens to cover, and the
  full-row bar — the whole reason the overlay is a second pass — would vanish.
- **Shrink the band to the node's painted run.** The projection does not keep a
  per-node drawn extent, and it would still underline the inter-word gap
  inconsistently.
- **Remove `underline` from the focus style.** Symptom removal: it is the one
  attribute that separates focus from selection at a glance.

Evidence:

- `moui_tui_renderer/canvas_wbtest.mbt` (new white-box file, +1 test): claim one
  cell, sweep attributes over a 4x12 box — the claimed cell keeps the underline,
  the other 47 get none, and `reverse` still covers all 48. Verified red with the
  guard removed (`Total tests: 29, passed: 28, failed: 1`).
- The counter PTY case gained two assertions in the same session: the underline
  must contain the clicked label cell and span at most 4 cells, and no glyph-free
  row may carry an underline anywhere on screen. Both are read *before* the
  second click — that click lands outside the hit box and takes the focus band
  off the whole screen (measured: no underlined cell in any row), so afterwards
  there is nothing left to assert. Verified red with the guard removed
  (`focus: the underline hugs the label`).
- Green after the fix: 29/29 renderer, 8/8 PTY interaction assertions, 87/87
  across `moon test moui_tui moui_tui_renderer moui_terminal_host
  moui_tests/tui_spike moui_tests/tui_pty_smoke --target native`,
  `moon fmt --check`, `moon info` and the six static validators.

## S6 consistency evidence (2026-10-15)

S6 is the stage where the TUI path has to survive other people's gates, so the
work is mostly *making existing checks cover it* rather than writing prose about
it.

### Surfaces touched

- `checks/release-modules.json`: `wzzc-dev/moui_tui` (role `binding`, stage
  `base-bindings`), `wzzc-dev/moui_tui_renderer` (role `renderer`, stage
  `renderers`), `wzzc-dev/moui_terminal_host` (role `addon`, stage `addons`) —
  the same directory/stage pattern `moui_sun` and `moui_sun_renderer` already
  use. The file carries only name, directory, publication, role and release
  stage; it has **no** readiness booleans, so `ready=false` is declared where
  readiness actually lives (see below).
- `docs/renderer-capability-report.md` + `docs/zh-Hans/…`: a fifth column
  `Terminal cell ANSI`, all 17 features, filled from
  `moui_tui_renderer/capabilities.mbt`; new `TerminalAnsiNative` descriptor
  bullet, an experimental-scope paragraph, and
  `## Current Terminal Cell ANSI Notes` (semantics-only input, named degrade log,
  claim-rule priorities, zero-byte unchanged frames, row-level repaint, resize
  from a blank grid, `moui_tui` underneath, no shaper).
- `tools_product/moui/validate_renderer_capability_consistency`: the validator
  now self-reports a fourth column (`provider_id: "tui-ansi"`, column label
  `Terminal cell ANSI`), `ReportRow` gained `tui`, and the table-row gate is
  `cells.length() >= 6`. Green at **68 cells**. This required adding
  `wzzc-dev/moui_tui_renderer` to `tools_product/moon.mod` as well as the
  validator's `moon.pkg` — the package-level dep alone fails to solve.
- `docs/architecture-map.md`: five-branch renderer fan-out, the semantics-only
  input exception (P6/ADR 0019), two new ownership rows (`moui_tui`,
  `moui_terminal_host`), and an **Experimental (`ready=false`)** product row that
  states the claim is interaction fidelity, not pixel fidelity.
- `docs/view-catalog.md`: `## Terminal Output Coverage` — the five `RoleKind`
  classes, what projects, what degrades to `[image]`/`[web-view]`, what is
  dropped-but-named (`canvas`/`custom_layout`/richtext/3d), and the evidence
  boundary that only `examples/tui_split` and the counter TUI are PTY-proven.
- `docs/testing.md`: `### Terminal PTY interaction smoke` (gate id, how to run,
  the `MOUI_TUI_SMOKE_BIN` false-pass hazard the script refuses, mutex
  serialization, artifacts path, and the explicit "not wired into CI" statement).
  Edit is outside the `GENERATED PLATFORM TIER MATRIX` markers, which
  `tools/moui/validate_platform_matrix` regenerates.
- `docs/release-readiness.md` and `docs/platform-readiness-declaration.md`: the
  `ready=false` declaration. The readiness document gets
  `### Terminal Output Route (non-windowed, experimental)`, modeled on the
  adjacent Linux RISC-V64 precedent — *a variant recorded outside the canonical
  matrix* — with a claim/status table (proven list, not-claimed list, and
  "never selected by `auto`").
- `docs/examples.md`: the Counter row names `examples/counter/terminal` as an
  entrypoint, and the TUI Split row describes the runnable
  `examples/tui_split/terminal` acceptance app plus its PTY gate instead of
  "no entrypoint yet". `docs/repository-facts.md` and
  `checks/api-surface-report.json` were then regenerated with
  `node scripts/generate-repo-docs.mjs --write`, which is exactly what
  `--check` compares against. The new example keeps `featured: no` because the
  path is experimental.

### Rejected alternatives

**Prose-only capability column.** A `supported/partial/gap` table that nothing
checks is a documentation claim that rots the first time the projection changes.
The validator already parses the report and compares it against each renderer's
self-report; wiring `tui-ansi` in costs one dep and one `ReportRow` field, and an
`Image` row that says `supported` then fails the build instead of lying about a
placeholder. Rejected because it is the difference between a gate and a rumour.

**A 15th route in `checks/platform-matrix.json`.** `tools/moui/validate_platform_matrix`
asserts "the canonical 14-route platform matrix", and every route there carries
pixel-oriented fields (`showcasePackage`, `evidenceFile`, a renderer/target pair)
plus generated doc blocks. The terminal path has no window, no pixel evidence,
and is not a platform — it is an output path on an existing host. Forcing it in
means relaxing a governance contract, which is an RFC, not a documentation
update. Recorded as the reason the matrix is untouched.

**CI wiring of the PTY gate.** Deferred, and stated as debt in
`docs/testing.md`: the harness decides frame completeness by timing and needs a
POSIX PTY. Adding it to `.github/workflows/*` would also be a shared-infrastructure
change, so it needs explicit approval rather than being bundled into a
documentation stage.

## S7 design (2026-10-15) — `examples/tui_layers`: one app carrying all eight requirements

The owner restated the acceptance list as eight items (split panes with a layer
list on the left and a file tree on the right, Tab focus cycling, bordered list,
tree fold/unfold, cursor selection with arrow movement, wheel + click, instant
keypress without submit, resize reflow) and asked for **one** example that shows
all of them at once. `examples/tui_split` already proves six, but its left pane is
a generic `Entry 0..15` list, so the eight items do not each land on a distinct,
named interaction.

Decision: add `examples/tui_layers` rather than reshape `tui_split`. The latter is
the carrier of the S5 gate — eight PTY assertions locate their needles in
`tui_split`'s status line (`sel=`, `list=`, `Files 7`) and in its pane titles;
moving those goalposts to make room for a demo feature would weaken the gate that
just caught two real defects. Cost: a third example package in the workspace and a
third binary in `scripts/tui-pty-smoke.sh`.

Layout, 5 model fields, and the eight-item mapping are in
`examples/tui_layers/app`. Every interaction is expressed with existing
`@views` / `@moui` API — no new control, no `moui/core`, no `moui/runtime`:

| # | Requirement | Carrier | Visible proof |
|---|---|---|---|
| 1 | split panes | `row([expanded(layers), expanded(files)])` + filter row | two bordered panes side by side, re-columned on resize |
| 2 | Tab across panes | `CyclePane` over `Pane = Layers \| Files \| Filter` | the active pane's title gets `[ … ]` and its border takes the primary colour |
| 3 | bordered list | `container(border=BorderStyle(width=1.0))` | `╭╮╰╯│─` actually present in the cell grid |
| 4 | tree fold/unfold | `tree_view(expanded=, on_toggle=, on_secondary_tap=)` | `Layers`/`Files n` counts change, right-click folds too |
| 5 | selection + arrows | `selectable_list(selected=)` + `Move(±1)` | the focus band steps row by row, `sel=` follows |
| 6 | wheel + click | `scroll_view(on_scroll=)`, row click, checkbox click | `row=n` changes; clicking the small `[x]` target flips exactly that layer |
| 7 | instant keypress | `text_field(on_input=…, on_submit=None)` live filter | the visible row count drops on every keystroke, no Enter |
| 8 | resize reflow | host `SIGWINCH` → `Canvas::resize` | three sizes swept in the PTY gate, names wrap per cell |

### Deliberate key-routing choices, with what they reject

- **Structural commands are `Ctrl` chords (`Ctrl-N`/`Ctrl-B`/`Ctrl-X`/`Ctrl-A`), and
  no plain letter is claimed.** `moui_terminal_host/decode.mbt::emit_text_key`
  emits *both* a `Keyboard` and a `TextInput` event for every printable byte, so a
  program-level claim on `n` would both fire a command and eat the character the
  filter is waiting for. `tui_split` can bind `n`/`a`/`d` precisely because it has
  no text field. Rejected: keeping letter bindings and filtering only on Enter —
  that is submit-based and voids requirement 7.
- **Arrows stay program-claimed, so the caret does not move inside the field.**
  The routing rule is "the pane owns the arrows" (S3 finding); the cost is that
  editing longer filters means backspace or re-click. Naming it here instead of
  adding a second arrow policy per role, which is the two-rules-in-one-grid
  mistake the S5 addendum already rejected.
- **`Filter` is a focus pane in the model, but the field is reached by clicking
  it.** There is no app-facing programmatic focus API —
  `@core.FocusRequest` has no consumer outside `moui/core` (verified by grep), so
  "Tab moves the app's routing pane" and "runtime focus lands on the text field"
  are two separate chains, exactly as in `tui_split` (its own test walks
  `runtime.focus_next()` for 200 hops to land focus on a tree row). The PTY case
  therefore clicks the field, then types. If click-to-focus does not work, that is
  a host or runtime finding and gets reported rather than patched in `runtime`.

### Gate plan

`scripts/tui-pty-smoke.sh` builds a third binary and exports
`MOUI_TUI_LAYERS_BIN`; one new white-box PTY case asserts items 6–8 in order:
click the `[x]` cell of a layer and read the marker back, click the filter box and
type `gro` (row count drops per keystroke, no Enter sent), wheel-scroll the layer
pane, then resize through 43x11 / 72x14 / 100x30 and assert both panes survive.
`smoke/gates.json` gains the case; the missing-binary skip guard extends to the new
variable so a stale build cannot pass silently.

Two substitutions against that wording, both decided by what the shipped demo
actually contains: the keystroke walk is `s` → `st` → `stro` (the eight layer names
are Strokes/Streamlines/Fills/Guides/Labels/Shadows/…, so `gro` would match nothing
and a passing `rows=` walk would prove nothing), and the resize sweep runs
72x14 → 43x11 → 100x30 so each shrink is followed by its own rebuild count.

### S7 gate evidence (measured 2026-10-15, macOS, 100x30 PTY)

`sh scripts/tui-pty-smoke.sh` builds the three binaries and reports **9 tests, 9
passed**, including
`moui_tests/tui_pty_smoke/pty_smoke_wbtest.mbt`'s
"S7 mouse, per-keystroke filter, wheel and resize drive the layers demo".

- Startup reads `sel=Background node=src filter=- rows=8 hide=2 only=0` and
  `row=0 file=0`.
- Clicking the `[` of `[x] Labels` (row 22, col 16) gives `sel=Labels`; Space then
  gives `hide=3` and the row's own marker reads back as `[ ] Labels`. The click
  landed on the cell the row's own text was drawn in, which is the
  centre-containment rule doing its job.
- Clicking the `n` of the placeholder (row 1, col 15) puts runtime focus in the
  field (`focus: filter` in the header). `s` → `filter=s rows=6`, `t` →
  `filter=st rows=2`, `r`+`o` → `filter=stro rows=1`. Not one CR/LF was sent.
- **Space in the typing state is a character, not a command**: `hide=` stays 3 and
  `rows=` drops 1 → 0, because the field text becomes `stro `. The same press in
  the headless app test is a no-op (`rows=1`), because `press()` dispatches a
  `Keyboard` event only while the terminal decoder emits `Keyboard` *and*
  `TextInput` for one printable byte. Recorded because it means the release rule is
  only provable in the PTY gate, never in `app_test.mbt`.
- Backspace (`0x7f`) edits the field: five presses clear `stro ` → `filter=- rows=8`.
- ArrowDown with runtime focus still in the field moves the *list*
  (`sel=Labels` → `sel=Shadows`) and leaves the caret alone — the cost the
  key-routing note above accepts, now measured instead of argued.
- The wheel is hover-routed, not focus-routed: with focus in the text field,
  wheel-down over `[x] Streamlines` (row 14) gave `row=1 file=0` and wheel-up
  returned `row=0`. One cell is all the 30-row viewport allows here (content
  overflows by one row pitch), so the gate asserts +1 and back rather than +2.
- Resize: 72x14 rebuilds once and keeps `Layers 8/8`, `Files 10`, both panes' first
  rows (`[x] Background`, `[src]`) and the whole status line, with rows 14..29
  untouched. 43x11 keeps both pane titles and both content rows, but
  `Canvas::write_boxed` word-wraps the 560px status text into 43 columns and drops
  the tail, so `only=` is gone and the gate asserts the `sel=` head only. Growing
  back to 100x30 gives `rebuilds=4`, `painted_count()=30` and
  `hide=3 only=0` readable again.

### Two defects this gate produced

1. **Clicking a text field killed the terminal app.** `moui_tui_renderer/cell.mbt`
   reported `caret_positions: []` (its box-only measurement had no per-character
   insertion points to report), and `moui/views/text` indexed that array after
   `clamp_int(_, 0, length - 1)` — for an empty array that clamp *produces* the
   legal index 0, so the following subscript panicked. Fixed on both sides: the cell
   text system now reports one column per character (double-width glyphs count two,
   offsets clamp to `max_width`, and the empty string still has the box origin), and
   the six index sites in `text_input_paint.mbt` / `text_input_editing.mbt` go
   through `caret_offset`, which falls back to the box origin when there is no
   geometry to read. Covered by one `moui_tui_renderer` case and two new
   `moui/views/text` white-box cases.
2. **No routing defect existed.** The "clicked the field, typed, nothing happened"
   reading that preceded (1) was the crash: the process had already died, so the
   last frame on screen never changed again. After the fix, click-to-focus and
   per-keystroke filtering work over a real PTY with **no `moui/core` or
   `moui/runtime` change**, which is what the S3 "routing needs no change" finding
   predicted.

## S7 addendum (2026-10-15) — rows and selection bands were painted on the pane ring

Reported from a real terminal at ~190x12: a list row appeared *on* the pane's border
(the top border row read `⌐[x] Layer 0 ───`), and clicking a row produced a wide
blue/cyan block that swallowed the frame. Both are one defect with two faces: **the
projector gave chrome and content the same cells.**

### The mechanism, measured

A terminal line is a whole 8x16 cell, while the layout's border is a few pixels
(the demo's padding is 4px < half a cell). `paint_node` intersected every node with
one inherited rect, so a `ScrollView`'s ring row was simultaneously its own first
content row, and the centre-containment quantizer's sub-cell fallback
(`floor(edge/cell)`, kept for hairline separators) promoted a 4px sliver of the last
partially-scrolled row onto the bottom border. The same rect was the selection band's
span, so `style_range` reversed the top border row, the bottom border row and both
border columns.

Reverting the rule reproduces it exactly at 190x12 (captured from the PTY decoder):

```
5| │   ╭───────────────────╮        [▾] ─[src] ───────────╮  │   <- tree row on the top border, ╭ eaten
6| │   │[x] Background     │        │                     │  │
7| │   ╰───────────────────╯        ╰─[▾] ─[core] ────────╯  │   <- `core` row on the bottom border
```

and the band span at 100x30 was `ListItem b=5,14,7,34` — rows 5..7 (border, interior,
border) x cols 14..34 (border..border).

### The rule that fixes it

`moui_tui_renderer/project.mbt` now carries **two inherited rects** (`Clip`):

- `chrome` — what a `Region` may draw its ring on. Unchanged from the old single rect,
  so a `List`/`Tree` ring stays exactly coincident with the `ScrollView` that owns it.
- `content` — the *inside* of that ring (`inside_ring`), used for every glyph and for
  the focus/selection band.

`child_clip` narrows only on `ScrollView`, and when a ring has no inside (43x11: the
pane quantizes to two adjacent rows) `content` falls back to the whole ring, so a
cramped pane still shows rows instead of going blank — that is what keeps the S7 gate's
"both panes still have rows" criterion true. The band pass additionally uses
`quantize_box`, which has **no** sub-cell fallback: a rect that owns no cell centre gets
no band, because a reversed cell with no glyph in it is a colour blob, not a selection.

Post-fix at the same 190x12: rows 5 and 7 are pure strokes, both `╭` corners survive,
the interior row reads `│[x] Background     │`, and the band is cols 38..56 / 132..152
with the ring's own `│` at 37/57 and 131/153 never reversed.

### Rejected alternatives

1. **Let chrome win the contested cell** (flip `draw_box` above content priority, or
   freeze `chrome` so content cannot be drawn on ring rows). Measured consequence: the
   outer `Group` ring occupies row 0 and row 11 of a 12-row window, and those are the
   title bar and the key legend — the app would lose both to win one border. It also
   chops a label into fragments wherever the ring lands on top of it
   (`╰ab/arrow-lr pane`).
2. **Inset everything** (one interior clip for both tracks). Every nested `Region`
   insets again, so a `ScrollView` + `List` pair draws two rings a cell apart, and at
   43x11 both panes quantize to nothing — the S7 resize gate went red on
   "both panes still have rows".
3. **Fix it in `moui/core` / `moui/runtime`** (clip rects, scroll semantics). Rejected
   because the layout already clips correctly in pixels; the deviation is created by
   quantization, which only the projector knows about. This keeps the owner gate closed.

### Gates added

- `moui_tui_renderer/clip_wbtest.mbt` (white-box, 2 cases): `quantize_box` returns
  `None` for a rect that owns no cell centre while `quantize_axis` still gives it one
  cell, and `inside_ring` insets by exactly one cell but returns the whole ring when
  there is no inside.
- `moui_tests/tui_pty_smoke/pty_smoke_wbtest.mbt`: "S7 a short pane keeps its ring free
  of rows and bands" opens `examples/tui_layers` at 190x12, finds each pane's
  `╭`…`╮` span, and asserts ring rows carry only box-drawing codepoints, that a
  selection band actually reached the terminal, and that no ring cell of either pane is
  reversed — before and after a wheel notch and a tap. Both mutations were checked to
  bind: dropping the content track fails on "both panes drew a ring", dropping only the
  horizontal inset fails on "the band never covers the ring".

`moon test moui_tui_renderer` 33/33, `sh scripts/tui-pty-smoke.sh` 10/10 (three
binaries), six pre-push static validators green.

## S7 follow-up (2026-10-15) — the vacated selection band kept a permanent color block

- User report, layers demo: "点过的区域有这个青色的原因是什么" — rows that had ever been
  selected kept a textless cyan block that no later click removed. Measured with a
  throwaway PTY probe (reverse/bold/underline fingerprint per row across three
  selections, probe shell deleted, assertions kept): the highlight band writes attrs
  without claiming cells, `sweep_stale` only resets cells owned last frame, so a 40px
  row's band tail (a full line of empty cells under the title) keeps `reverse`
  forever after the selection moves. Title cells recover (their painters repaint
  plain); tail cells belong to nobody. Also measured: a clicked row immediately loses
  its band because its ghost button's focus band rewrites the same box in paint
  order — keyboard-selected rows keep the bar, clicked rows show only the yellow
  focus; recorded, not silently re-layered.
- Fix in `moui_tui_renderer/canvas.mbt` only: `bands`/`prev_bands` mask pair marked
  in `style_range`; frame-end `sweep_stale_bands` resets attrs to default on cells
  band-touched last frame, not band-touched this frame, and claimed by neither frame
  (glyph cells stay with the owners/sweep; wide-char right halves stay tied to their
  left half).
- Rejected: making the overlay own its cells (the no-claim rule is what keeps the
  band from erasing sibling glyphs), and routing the cleanup through the
  presentation diff (stale cells never differ again — that is the defect).
- Gates, first verified red against the pre-fix renderer: `renderer_test.mbt`
  "a band that moves away rewrites the cells it vacated" (glyph-free `Item` band;
  vacated row re-sent once, then identical frames back to zero bytes), PTY
  "S7 a moved selection sweeps the band off the vacated row", white-box
  `canvas_wbtest.mbt` "a band that moves away resets the attrs of cells nobody
  claimed". `moui_tui_renderer` 42/42 (x3 runs), `sh scripts/tui-pty-smoke.sh`
  12/12, the session validation set 132/132, six pre-push static validators green.

## S7 follow-up 2 (2026-10-15) — the band flickered with focus, and the tree band kept only a front sliver

- User report after the sweep fix: 左栏点击后在上一次点击的位置**闪一下**青色;
  右栏点击后**被点选项前面**出现青色. Measured with a press/release-separated PTY
  probe: focus lands on the embedded button at pointer-down while
  `SelectLayer`/`SelectNode` dispatch on release, and the single band pass ran in
  paint order — so the clicked row's own focus band ate its row band (left list:
  button spans the whole row → clicked row showed no band; the previous row, focus
  gone but not yet de-selected, regained its reverse band for one press frame =
  the flash; a dead-zone click blurred focus and popped the band back), and the
  tree row's label button box starts after indent + toggle, leaving the front
  marker columns as the only reverse that survived the overwrite.
- Fix in `moui_tui_renderer/project.mbt` only: the band pass is split —
  **focused bands first, selected bands second** — so the selected row owns its
  whole box regardless of which inner button holds focus: the band lands on the
  clicked row immediately, stays through dead-zone clicks (focus loss), and the
  tree band covers the row from its front instead of a sliver. A node carrying
  both states composes them in `attrs_for` already; the second pass re-applies the
  same attrs there.
- Rejected: sticky-reverse attr merging (produces a yellow band — a visual
  change nobody asked for) and overlay ownership (that rule is what keeps bands
  from erasing sibling glyphs).
- Gates: new PTY case "S7 a clicked row keeps the selection band on itself"
  (red before the reorder on "the band lands on the clicked row"; also pins
  dead-zone stability, tree front + label coverage, and the vacated-row sweep).
  Band-count assertions must scope columns per pane (`reversed_in_cols`, list
  `[10,40]`, tree `[50,95]`): one terminal row belongs to both panes, so an
  unscoped whole-row "no reversed cell" is red forever against the other pane's
  legitimate band. `moui_tui_renderer` 42/42, `sh scripts/tui-pty-smoke.sh` 13/13,
  session validation set 132/132, six pre-push static validators green.

## Phasing under the approved Option B

- S1 `moui_tui` cell buffer: **done** (evidence above).
- S2 `moui_tui_renderer`: **done** (evidence above) — ported the S0 probe into a
  real `RendererProvider` that reads `frame.semantics`, projects roles onto cells
  with the S0 ownership rule, encodes ANSI deltas, and degrades non-projectable
  controls (`image`/`icon`/`canvas`/`custom_layout`/`web_view`/richtext/3d) to
  explicit placeholders recorded as diagnostics.
- S3 terminal backend: **done** (evidence above) — termios raw mode, SIGWINCH,
  stdin decode, SGR(1006) mouse set/restore, keyboard/mouse/size channels,
  lifecycle through `moui/backend/common`'s input/surface protocol; the
  composition root declares the `tui-ansi` provider explicitly. Includes the
  finding that keyboard routing needs **no** `moui/core` / `moui/runtime` change.
- S4 split-layout proof app: **done** (evidence above) — left list + right file
  tree using existing `View` composition only, proven head-to-end against the
  cell projection.
- S5 acceptance app: **done** (evidence above) — `examples/tui_split/terminal`
  runs under `moon run`, and the six interactions plus the shared-counter
  startup gate are asserted in a real POSIX PTY by
  `moui_tests/tui_pty_smoke` (8 tests, 8 passed) through
  `sh scripts/tui-pty-smoke.sh`. The resize gate that blocked this stage was a
  projector defect, fixed in `Canvas::resize` with a renderer-level regression
  test.
- S6 consistency: **done** (evidence above) — the three TUI modules are in
  `checks/release-modules.json`, `smoke/gates.json` registers
  `tui.pty-interaction-smoke`, the capability report has a
  validator-checked `Terminal cell ANSI` column (68 cells), and architecture map,
  view catalog, testing policy, release readiness and the platform-readiness
  declaration each carry the terminal path with its `ready=false` boundary. The
  canonical platform matrix is deliberately unchanged.
- S7 eight-item demo + gate: **done** (evidence above) —
  `examples/tui_layers` puts all eight requirements in one `@moui.View[Msg]` app,
  and `tui.pty-interaction-smoke` now drives three binaries (12 PTY cases, all
  passing, after the pane-ring gate and the vacated-band gate above). It produced the empty-`caret_positions`
  crash fix in `moui/views/text` + `moui_tui_renderer` and re-confirmed that terminal
  click-to-focus needs no runtime change.

Native C stubs follow `examples/terminal/pty_host/pty.c` (`termios.h:20`,
`TIOCSWINSZ:131-136`); raw-mode entry/exit and mouse-mode restore are new.
