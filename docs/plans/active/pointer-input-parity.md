# Pointer, Gesture and Scroll Input Parity

- Status: active
- Goal: make the input behaviours that `moui` already *declares* actually happen —
  long press / double tap, touch selection, multi-pointer identity, scroll
  rebound, text semantics and right-to-left mirroring — instead of shipping
  public APIs whose effect is silent.
- Compatibility: the public surface delta is confined to `moui/core` (a few
  fields on `PointerEvent`, `TextControlStateContext.reveal`, one word-boundary
  function) and rides the 0.3.0 contraction already in flight. No new validator,
  script or CI gate is added by this plan.

## Problem

A gap analysis against Flutter / SwiftUI / Compose showed the deficit is not
missing features but *declared-but-inert* ones. Each item below was verified in
the code before being listed:

| # | Declared | Actual |
| - | -------- | ------ |
| 1 | `View::on_long_press`, `View::on_double_tap` | never fire: the recogniser state is rebuilt per event (`core/modifier_event.mbt`), and `PointerEvent.time_ms` is only filled by the Linux backend |
| 2 | reach-a-duration triggering | no wake path existed; a hold produced no event to re-evaluate |
| 3 | `PointerSource::Touch(FingerId, Force?)` | `backend/common/input/window_event_decode.mbt` dropped pinch/rotation/pan/double-tap/pressure variants; `PointerEvent` had no `id`/`pressure`; runtime kept one capture slot |
| 4 | `read_only` / `password` semantics | text nodes hardcoded `false`; `password_field` masked by string replacement in app code |
| 5 | touch-era text selection | no click count, no caret drag in `moui/views/text`, no word boundaries in `moui/core`, no ancestor auto-reveal |
| 6 | scrolling | `scroll_offset_after_wheel` / `scroll_clamp_offset` were velocity-free clamps; drags past the edge were hard-truncated |
| 7 | `Environment.layout_direction` | declared with `with_layout_direction` + `View::environment`; re-surveyed 2026-10-23 (pre-§9 state, now superseded by the §9 landing notes): four `moui/views` consumers already mirror through `layout_mirror_x`, 11 more groups do not, `CustomPlacementContext::mirror_x` has zero call sites, and `runtime/layout.mbt` threads a `layout_direction~` parameter that no caller passes and no code reads |
| 8 | text editing | `moui/views/text/text_input_editing.mbt` re-implemented `moui/core/text_editing.mbt` without its grapheme cross-check |
| 9 | docs | `docs/view-catalog.md` referenced test files that do not exist |

## Verified pipeline facts

These constrain every slice and are cheap to re-check, expensive to rediscover:

- The animation latch is **paint-only**: `FrameTick` advances
  `animfocus.now_ms`, and while `active_animations` holds it sets
  `needs_paint` + `needs_redraw`. Layout is cache-guarded and only re-runs on
  `needs_layout`; `ViewLayoutContext` has no clock.
- `RenderEnvironment::matches_default_cache_key()` ends with `self.now_ms == 0.0`,
  so any host that ticks at all bypasses every render/plan cache and re-runs
  `View::paint` each frame. A time-dependent paint plan therefore animates with
  **no runtime change** — this is what makes a paint-only residual legal.
- Consequence: a *paint-only* overshoot (bounded, always landing inside laid-out
  and padded content) animates truthfully; an authoritative-offset **fling** does
  not, because it needs re-layout per frame, `on_scroll` per frame, and a
  windowed `@views.lazy_list` whose rows come from the app's offset.
- `ViewEventResult` is `pub(all)` with ~264 references and `View::map` rebuilds
  its fields, so adding a wake field to it is the *unsafe* option; the runtime
  already carries per-node state through `result.state`.
- Semantics merge has two layers, and an explicit declaration wins in both:
  `ViewSemanticsInfo::overlaying` prefers the modifier over the node
  (`moui/core/modifier_semantics.mbt:332-347`), and `overlay_state` prefers the
  element's merged info over accumulated state (`moui/runtime/semantics.mbt:334,337`).
  So the leaf `read_only=false`/`password=false` literals were overridable all
  along — §6's real defect was that **no** producer ever declared them, not that
  the leaf shadowed a wrapper. Deleting the literals is contract honesty
  (wire-neutral: `None` resolves to the same `false` at
  `moui/runtime/semantics.mbt:220-226`); the wrappers declaring them is the fix.
- `dispatch_keyboard` and `dispatch_text_input` used to hand the target view
  `RenderNode::empty()`. Only the pointer path resolved a hit-test frame, so any
  geometry-dependent key or IME handling — a vertical caret move in a multiline
  field, the field's own viewport follow, a reveal request — computed against a
  zero rect. Both now take the placed subtree
  (`PlacedNode::event_render_node_for`) the way the pointer path does.
- Placement caches are keyed by frame, and `ElementNode::place_with_text_system`
  re-descends only when the node itself reports layout dirtiness
  (`needs_layout || descendant_layout`). The pointer path sets `descendant_layout`
  on every ancestor as it unwinds (`input_pointer.mbt:303-311`);
  `dispatch_event_to_target` did not, so an offset changed by a *targeted*
  dispatch — a `scroll_to_key` request or a text reveal — never re-placed the
  tree above the scroll view: the control's state said it scrolled and the paint
  said otherwise. The targeted path now unwinds the same way, pinned by
  `moui/runtime/view_runtime_test.mbt` ("runtime re-places the ancestors of a
  scroll view driven by a targeted event"), which fails with the unwinding
  removed while all 154 prior runtime tests stayed green.

## Stages

| Slice | Scope | Status |
| ----- | ----- | ------ |
| §0 doc references | `docs/view-catalog.md`, `docs/zh-Hans/view-catalog.md` | done |
| §1 gesture state persistence | `moui/core` private slots + codecs, `ctx.now_ms` as the single clock | done |
| §2 timed wake on hold | runtime paint latch + synthetic `Move` from `FrameTick`, zero new public API | done |
| §3 scroll rebound | `moui/views/controls`: bounded rubber band, animated rebound, derived indicator geometry (band/motion code split into `scroll_view_motion.mbt`); horizontal axis gated on a real scroll range 2026-10-24 | done; inertia approved 2026-10-23, pending |
| §8 single edit engine | delete the duplicated caret/selection helpers in `moui/views/text` | done |
| §5 touch-era selection | click count, `text_word_range_at` (bounded subset), caret drag, goal column, `reveal`, Showcase evidence | done |
| §4 multi-pointer | `PointerEvent.id`/`pressure`, decode `FingerId`/`Force`, per-id capture, Web ABI | done |
| §6 honest text semantics | stop hardcoding `read_only`/`password`, use `View::semantics_state` | done |
| §9 RTL mirroring | 11 groups across `moui/views` + `moui/core` alignment/guide math, delete the inert `moui/runtime` direction parameter, wire `mirror_x`, mirrored-frame property tests | done 2026-10-23 (widened beyond views, approved) |
| §7 pinch / rotation | end-to-end gesture variants | approved 2026-10-23 in full, pending |

Owner approvals recorded on 2026-10-23, all riding the 0.3.0 migration that the
API contraction already started:

- `moui/core` public lines may be added for §4 and §5; `moui/core` and
  `moui/runtime` caps in `tools/moui/validate_api_surface/main.mbt` may be
  raised to match measured `pkg.generated.mbti`, and
  `checks/api-surface-report.json` regenerated. Generated data only — no script,
  gate or CI change.
- `moui/runtime` may pump frames per-tick for the §3 fling, without new public
  API.
- §7 is approved end-to-end (decode + recogniser + modifier + Showcase
  evidence), including the `AppEvent::Gesture` variant.

Measured after §4 (`moon info` + `node scripts/generate-repo-docs.mjs --write`):
`moui/core` is 2515 lines / 1111 pub — 2511 / 1110 at HEAD, +2 for
`text_word_range_at` and `TextControlStateContext.reveal` net of the
`PointerEvent.time_ms` removal, +2 for `PointerEvent.id`/`pressure`, and
`checks/api-surface-report.json` regenerated. `moui/runtime` (890) and the
`moui/views` facade (688) did not move at all: §4 added no public runtime API,
only the `ViewEventResult`-shaped internals behind it, so §7 is the next slice
that can change a measured cap.

Measured after §9 (`moon info` + `node scripts/generate-repo-docs.mjs --write`):
`moui/core` is 2518 lines / 1113 pub, +3 / +2 for `Rect::mirrored_x` and
`Insets::mirrored`; widened-existing surfaces (`OverlayPlacementContext.layout_direction`,
the `direction` labels) added no counted line beyond that. The `moui/views` facade
did not move at all: neither `layout_mirror_x` (deleted from `moui/views/layout`)
nor `PresentationPlacement::resolve` (which now takes a required `direction~`) is
re-exported through it, so the source-breaking line for apps is the subpackage
path, and that is §9's entry in the 0.3.0 migration.

Ratchet data moved with §5 and §4, each entry carrying its own reason string: the
core budget comment in `tools/moui/validate_api_surface/main.mbt` (1685 -> 1700,
of which 8 lines were drift already past 1685 before this change, then 1700 ->
1704 for the §4 note), three
`checks/source-file-policy.json` entries
(`tools/moui/validate_api_surface/main.mbt`, `moui/runtime/view_runtime_test.mbt`
1366 -> 1441, `examples/mo_workbench/app/workbench_wbtest.mbt` 1514 -> 1515 for
the `reveal` field in its fixture), and six
`tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt` entries — two
text-view raises plus `text_input_editing.mbt` 500 -> 307, which hands the §8
deletion back to the ratchet, then `window_event_decode_test.mbt` 304 -> 412 and
`diagnostics_inspector_accessors.mbt` 1113 -> 1116 for §4. §9 moved one:
`tools/moui/validate_api_surface/main.mbt` 1704 -> 1710 in
`checks/source-file-policy.json`, purely for the §9 note added to that file's own
budget comment — the `pr` profile's `validate_source_file_policy` step counts
those lines, so it is the step that catches this, not the maintenance-baseline
guard.

## §9 scope and design (approved 2026-10-23, landed)

Owner approved the widened scope: views **and** the `moui/core` alignment/guide
math **and** deleting the inert `moui/runtime` parameter, and `mirror_x` is to be
wired into the mirroring path instead of deleted. No new public API is in scope;
the only public surface that can move is one `pub fn` in `moui/views/common`
(see 9.0), which the API-budget table does not cap because it only caps the
`moui/views` facade.

### 9.0 One mirror formula

> Superseded by the landing notes: the canonical home ended up in `moui/core`
> (`Rect::mirrored_x`, `Insets::mirrored`) and both views-side helpers were
> deleted rather than kept as delegating names.

`moui/views/layout/layout_metrics.mbt:19` `layout_mirror_x(frame, local_x,
width, direction)` is the working formula and has the four live call sites.
`moui/views/common` cannot import `moui/views/layout` (layout depends on
common), so the canonical home is `moui/views/common` as `view_mirror_x`,
following the existing `view_max_double` cross-subpackage pattern;
`layout_mirror_x` stays as the public name the four call sites already use and
delegates to it. `moui/core/custom_layout.mbt:122`
`CustomPlacementContext::mirror_x` re-expresses the same formula for the
`CustomPlacementContext` receiver so custom-layout delegates have one way to
mirror; it becomes load-bearing through the built-in custom placement path plus
a test that calls it.

### 9.1 Sites

| # | Site | What changes |
| --- | --- | --- |
| 1 | `common/flex_layout.mbt:166` `flex_child_frames` | take `direction~`; build frames in LTR semantics then mirror every frame's x in RTL, so `MainEnd`/`SpaceBetween`/`SpaceEvenly` leading and the vertical cross-axis `CrossStart`/`CrossEnd` follow without duplicating the alignment math |
| 2 | `layout/layout_views.mbt:48` (padding) | in RTL the leading inset is `insets.right`: swap the pair for the child x |
| 3 | `layout/layout_views.mbt:367` (grid) | `column -> x` through `view_mirror_x` |
| 4 | `core/modifier_layout.mbt:189` `mod_aligned_rect` | mirror `a.x` (`(1.0 - a.x) / 2.0` in RTL); private fn, fed from `ctx.environment.layout_direction` at `:209` |
| 5 | `core/custom_layout.mbt:106` `AlignmentGuideSet` | leading/trailing are reading-order words: in RTL they are `size.width`/`0.0` |
| 6 | `controls/scroll_view_layout.mbt:870` `scroll_child_frame` | keep `offset.x` as *leading-edge* distance; in RTL place at `origin.x - (max_x - d)` so `d = 0` is flush right |
| 7 | `controls/scroll_view_layout.mbt:912` `scroll_clamp_offset` | unchanged by design (it clamps the leading distance, which is direction-free) |
| 8 | `controls/scroll_view_layout.mbt:640` wheel | ~~unchanged by design: a trackpad/wheel `delta.x` is a physical vector, not a reading direction; recording this keeps a later "flip the sign" change from being mistaken for RTL work~~ **amended while implementing**: `offset.x` is a *leading-edge* distance, so a physical vector cannot be added to it directly; see the landing notes for where the sign flips and why the event boundary stays physical |
| 9 | `presentation/presentation.mbt:278` | `viewport_insets.left`/`right` swap for the available rect origin in RTL, and the `Left`/`RightStart` anchors at `:329` resolve as leading/trailing |
| 10 | ~~`views/text/` (`text.mbt:20` default align, `text_input_paint.mbt:52,102,119,312`, `text_area_layout.mbt:99,136`)~~ | **out of scope, found while reading**: the view-facing contract `@core.TextLayoutInput` (`moui/core/text_layout.mbt:2`) carries no direction, so `TextSystem` measurement always returns LTR-ordered glyph and caret offsets (`moui_sun/text/shaper.mbt` has a `TextDirection`, unreachable from the port). Mirroring the block x while the offsets stay LTR puts the caret and the selection highlight on the wrong side of the glyphs. Rows already place the text child through group 1, so run-internal RTL is left for a direction-carrying `TextSystem` slice |
| 11 | `runtime/layout.mbt:98,146,232` | delete the `layout_direction~` parameter that no caller passes and no code reads; `environment.layout_direction` is the single source and is already in `cached_place_environment`/`cached_measure_environment`, so no cache-key work is needed |

Direction-neutral and deliberately untouched: `container.mbt:169`,
`layout_views.mbt:148,241-249,426`, `stack_layout.mbt:44`.

### 9.2 Evidence

`moui/views/layout` has **no test files at all** today and the facade tests
assert identity rather than geometry, so the mirrored-frame properties are new
coverage, not a regression net: white-box cases in `moui/views/common`
(`flex_child_frames` LTR/RTL pair — same extents, reversed order), plus
`moui/views/layout`, `moui/views/controls` and `moui/views/presentation` cases
where the code lives, and a `moui/core` case for `mod_aligned_rect` +
`AlignmentGuideSet` + `CustomPlacementContext::mirror_x`. `moui/runtime`'s
existing `flex_weight_test.mbt`/`flex_tight_fit_test.mbt` must stay green, which
is what proves the deleted parameter carried no behaviour. Because `moui/views`
is a facade, every subpackage has to be named explicitly in the test run.

## §9 landing notes (2026-10-23)

- **The mirror formula landed in `moui/core`, not `moui/views/common`.** 9.0
  picked `view_mirror_x` because `moui/views/common` cannot import
  `moui/views/layout`; it missed that `moui/core` needs the *same* formula for
  group 4 (`mod_aligned_rect`) and group 5 (`AlignmentGuideSet`), and core can
  import nothing, so a views-side canonical home would have left a second copy
  anyway. `Rect::mirrored_x` and `Insets::mirrored` are now the one place the
  reflection is written, and every site calls them: `layout_mirror_x` was
  deleted (net public change for the whole slice is +2 core methods, −1 views
  method), and the `view_mirror_x`/`view_mirror_insets` helpers drafted during
  9.0 were deleted before they reached a commit.
- **`CustomPlacementContext::mirror_x` is load-bearing.** It is the
  delegate-facing spelling of `Rect::mirrored_x` — the only way a
  `custom_children_layout` delegate can mirror, because the delegate never sees
  a `ViewLayoutContext`. The framework's own two delegates
  (`layout_baseline_form.mbt`, `layout_responsive_grid.mbt`) now place through
  it, which is what makes it "used by the framework itself" instead of an API
  kept for hypothetical apps. Both helpers lost their `frame`/`direction`
  parameters, since the context carries them.
- **Scroll offsets are leading-edge distances, so wheel and drag do flip.** Row
  8's "unchanged by design" was wrong in a way worth spelling out: with
  `offset.x` measured from the reading edge, adding a physical `delta.x` to it
  would scroll RTL content the wrong way. `scroll_leading_x_delta` is the single
  conversion point, called by the wheel branch and the container-drag path; the
  events themselves stay physical (a swipe right always moves content right),
  `scroll_clamp_offset` stays direction-free, and `moui/runtime/scroll_to_key.mbt`
  needed no change precisely because it dispatches physical wheel deltas.
- **Two source-breaking lines, both inside the approved 0.3.0 migration:**
  `PresentationPlacement::resolve` gained a **required** `direction~` label — it
  was deliberately not defaulted to `LeftToRight`, because a silent default is
  how an RTL popup keeps landing on the wrong side while still compiling — and
  `OverlayPlacementContext` gained a `layout_direction` field, filled by the one
  constructor in `moui/runtime/runtime_render_pipeline.mbt`. In-repo call sites
  updated: the overlay host, `picker_control.mbt`, `date_picker_control.mbt`.
- **`Alignment.x` and the guide set are different kinds of names and stay that
  way.** `Alignment.x` is a visual −1..1 axis, so RTL negates it;
  `AlignmentGuideSet.leading`/`trailing` are reading-order words, so RTL swaps
  which end of the size they report (`size.width`/`0.0`). Unifying them would
  have made one of the two wrong.
- **The deleted `moui/runtime` parameter carried nothing.** `layout_direction~`
  on `place_with_text_system`/`place_measured_with_text_system` had no caller and
  no reader; `moui/runtime` stays at 159/159 green with it gone, and
  `environment.layout_direction` remains the single source, already inside the
  `cached_place_environment` cache key.
- **Flex mirrors inside the push loop**, not in a second pass: each frame's x is
  reflected as it is built, so no extra array and no alignment-specific math was
  added for `MainEnd`/`Space*` or the column cross axis.
- Evidence: 5 new `moui/core` cases (`layout_direction_wbtest.mbt`), 4 in
  `moui/views/common`, 4 in `moui/views/layout` — the first test files that
  directory has had — 5 in `moui/views/controls`, 4 in
  `moui/views/presentation`. `moui/core` + the touched views subpackages +
  `moui/runtime` = 341/341 green on native. Every case is an LTR/RTL pair, which
  is what makes them more than a formula restatement: the same extents must
  survive, the order must reverse, and the untouched axis must not move.
- Measured after §9: `moui/core` is 2518 lines / 1113 pub (from 2515 / 1111), the
  cap comment in `tools/moui/validate_api_surface/main.mbt` carries the reason,
  and `checks/api-surface-report.json` + `docs/repository-facts.md` were
  regenerated with `node scripts/generate-repo-docs.mjs --write`. Two ratchets
  moved: that budget comment's own file budget in
  `checks/source-file-policy.json` (1704 -> 1710, for the note text —
  `validate_source_file_policy` counts it and the `pr` profile is what surfaced
  it), while `layout_metrics.mbt` went the other way and shrank to 65 lines of its
  90 budget. The new test files sit in the untracked band, and `sh
  scripts/check.sh --profile pr` is green end to end.

## §5 landing notes (2026-10-23)

- Triple-click selects the **hard** line (up to the next `\n`), not the wrapped
  visual row: a wrapped paragraph reads as one selectable unit, which matches
  what the passage's own line breaks mean to the app. `docs/text-system.md`
  states the word-boundary subset the same way — ASCII fast path plus
  Han/Hiragana/Katakana/Hangul per-character words, no UAX #29 word-break table,
  so no claim of Hebrew/Arabic joining or ZWJ-internal splitting.
- Up/Down caret movement keeps a goal column, and the column is now anchored on
  the *visual* row. That required the key-path frame fix above: a field that
  measured lines against `RenderNode::empty()` reported the logical line index
  instead, so a two-grid move could skip rows.
- Evidence lives in the Interaction Lab: `text_selection_card` hosts a
  `text_area` inside a `scroll_view`, and
  `examples/showcase/app/diagnostics/interaction_lab_section_wbtest.mbt` drives
  a real `AppRuntime` through double-click word, triple-click line, caret drag,
  and a caret pushed past the viewport edge by `ArrowDown` (asserting both that
  the ancestor offset moved and that the caret ends inside the viewport).
- The auto-reveal deliberately does **not** scroll the mouse-wheel path: wheel
  deltas stay hard-clamped (desktop convention), so only a caret or selection
  change asks an ancestor to follow.
- The wheel **offset** path now mirrors through `scroll_leading_x_delta` (see
  the §9 landing notes). What this note excludes is the *reveal* dispatch:
  `scroll_target_into_view` measures the gap in already-placed absolute frames
  and dispatches a physical wheel delta, so the §9 sign flip at the wheel branch
  converts it for free. Auto-reveal needs no direction knowledge of its own and
  was verified unchanged.

## §4 landing notes (2026-10-23)

- `id` and `pressure` are added as defaulted fields on `PointerEvent::new`, so
  every existing labelled call site compiles unchanged. `0` is the primary
  stream and `1.0` means "no pressure signal". Finger ids are **not** offset or
  re-numbered: iOS/Android/HarmonyOS `host_queue.mbt` emit `FingerId::from_raw(0)`,
  so the first finger has to stay the primary stream or those hosts would report
  a secondary-only device.
- `AnimFocusState` now holds `pointer_captures : Map[Int32, ElementId]` and
  `pointer_presses : Map[Int32, Point]` instead of one capture slot plus one
  press point. The presses map is what the §2 frame-tick re-sample iterates, so
  a two-finger hold now re-samples both streams instead of whichever one landed
  last.
- Three things stay owned by the primary stream, because they are per element
  rather than per pointer: the synthetic `Exit` that clears stale hover, the
  `find_focusable_at` focus commit on `Down`, and
  `RuntimeInspectorSnapshot::last_event_hit_path` (documented as the last stream
  to deliver, not keyed by id). Letting a second finger take them is the defect
  class this slice targets — it cancels the press tint and the in-flight gesture
  of the control the first finger is dragging.
- `common/input` maps `PointerSource`/`ButtonSource` through one identity helper
  each: `Touch(FingerId, Force?)` keeps the raw finger id and normalizes force
  (NaN and out-of-range clamp to `1.0`), `Mouse`/`Unknown` are `(0, 1.0)`, and a
  `TabletTool` keeps id 0 with its own force/angle. `PointerEntered`/`PointerLeft`
  stay dropped on purpose — hover is resolved from `Move` plus the synthetic
  `Exit`. `PinchGesture`, `RotationGesture`, `PanGesture`, `DoubleTapGesture` and
  `TouchpadPressure` still fall into `_ => None` until §7.
- The Web input ABI is 10 parameters end to end (`browser_runtime.js` →
  `web_dispatch_pointer_input` → app forwarder). `browser_runtime.js` ships
  inside the published module and is the only caller of the export, so the 10
  workspace forwarders (`examples/{counter,new_world,showcase,multi_window,
  mo_desktop,design_systems,three_d_viewer}/web_wasm`, `moui_studio/web_wasm`,
  `website/web_wasm`, `website/playground/web_wasm`) were rewritten in lockstep
  instead of keeping a compatibility shim. The router reports `pointerId` only
  for `pointerType === "touch"` and pressure only for touch/pen, which keeps
  mouse streams on the documented `(0, 1.0)`.
- **The `moui new` / Studio export template deliberately stays at 8.**
  `web_abi_shim_mbt()` generates code for a project that lives outside the
  workspace and resolves `wzzc-dev/moui@<published>` from the registry — its
  `web_wasm/index.html` loads the *published* `browser_runtime.js` out of
  `.mooncakes`, so the shim must match the release line, not mainline. Bumping
  it with the workspace made `moui_studio/services/compile_native` fail inside
  the generated bundle at `moon build --target wasm-gc` ("requires 8 arguments,
  but is given 10"); it moves when the pinned release line does.
- Two pre-existing field-loss defects surfaced while threading the ABI and are
  fixed here: the Linux client-decoration rebaser dropped `modifiers` from every
  pointer event inside a CSD window (it now forwards modifiers, id and
  pressure), and the two synthetic `Cancel` events in the captured-target unwind
  silently reset pointer identity.
- **Not consumed yet.** No view or recognizer reads `id`/`pressure`; §7 is the
  planned consumer. Until then these fields are transport-only, which is the
  honest state rather than a claim of a shipped pinch API.
- WeChat stays a single-stream host on purpose: `wechat_dispatch_pointer_input`
  takes 8 parameters and the upstream template runtime
  (`window/modules/window/wechat/runtime.js`) only sends `x, y, kind`. Touch
  identity there needs an upstream `wzzc-dev/window` change, not a MoUI one, so
  the WeChat path keeps the documented `id = 0` and was left alone.
- The decode-layer obligation is stated in `docs/platform-host-contract.md`
  (preserve stream identity when rebasing, replaying or synthesizing), and the
  field semantics live on `PointerEvent` itself rather than in a second table.
- **Dead scaffolding left in place.** `ElementNode::has_local_active_pointer_capture`
  is a `false` stub, and every entry point passes `capture_lookup=false`, so
  `has_active_pointer_capture`, `active_pointer_capture_id`, the `capture_lookup`
  parameter, and the "explicit local capture keeps precedence" branch are
  unreachable. Per-id capture in `AnimFocusState` is the only live mechanism.
  Removing them is a separate contraction: it edits the hit-test loop that §4
  does not otherwise touch, and doing it here would hide a behaviour change
  inside a transport slice.

## §3 landing note: a rangeless axis pulls no band (2026-10-24)

`scroll_container` pans on both axes, and the overscroll band was computed per
axis from the viewport size alone — so a horizontal drag moved the painted
surface even when the content never overflowed horizontally. The visible
symptom was `examples/new_world`'s onboarding card sliding sideways under the
pointer. `scroll_axis_has_range` now gates both the pointer's horizontal delta
and the horizontal band on `child.width > viewport.width`, which is UIKit's
`alwaysBounceHorizontal = NO` and Qt's `AutoFlickDirection`.

The vertical axis stays ungated on purpose: a `scroll_view` is always declared
as a vertical scroller, so its rebound is intended even while a short list
happens to have no range. The slop test still reads the physical pointer, so a
drag that starts on the surface cancels a child control exactly as before.

## Debt and known gaps

- **Run-internal text direction is still LTR.** §9 mirrors where a text block
  *sits*, not how its runs are ordered inside it: `@core.TextLayoutInput` carries
  no direction, so measurement always returns LTR-ordered glyph and caret
  offsets, and `moui_sun`'s `TextDirection` is unreachable from the port. A
  direction-carrying `TextSystem` slice is the prerequisite; until then no view
  may claim RTL text support, and `Environment.layout_direction` must not be
  forwarded into `moui/views/text` placement by itself (that would put the caret
  and the selection highlight on the wrong side of the glyphs).
- **Scroll inertia is not delivered yet.** A truthful fling needs the runtime to
  pump frames into the view tree while a subtree holds the latch, which is a
  `moui/runtime` production change. Approved 2026-10-23 and tracked as the
  remaining half of §3; shipping exponential velocity decay inside `moui/views`
  alone would have been another declared-but-inert API, so it was held back.
- **Upstream mobile pointers.** `window/modules/window/{ios,android,harmonyos}/host_queue.mbt`
  hardcode finger id 0, so two-finger touch is out of reach from this repository
  even after §4. macOS trackpad/touch-bar-input and Web (two `touch` points) are
  the evidence sources.
- **`.on_long_press()` + `.on_tap()` on one view fire both** for the first tap:
  suppressing the click would need a new cross-modifier public signal.
- `SemanticsTextValue::new(editable=true)` still describes the control class
  rather than writability; Windows stores `text_flags` it never reads and Web
  never consumes `editable`.
- **A third copy of the selection normalizer remains** in
  `moui_richtext/rich_text_editor_helpers.mbt` (`rich_text_input_grapheme_selection`).
  §8 only unified `moui/views/text`; the richtext copy is private to that module
  and needs its own test baseline before it can be deleted.
- **The `pr` profile never compiles a Web entrypoint**, so §4 initially shipped
  with four workspace forwarders still calling the 10-parameter export with 8
  arguments (`multi_window`, `mo_desktop`, `design_systems`, `three_d_viewer`);
  `moon check <pkg> --target wasm-gc` is what catches it and `moon test …
  --target native` cannot. Related and also pre-existing: `moon info`
  canonicalizes on native and prints `Skipping package …: it does not support
  target backend native` for those wasm-only packages, so their committed
  `pkg.generated.mbti` cannot be refreshed by the documented command and still
  spell `Int` where the source says `Int32`. Neither is worth a new gate; the
  command to run by hand is in `memories/repo/pointer-stream-identity.md`.
