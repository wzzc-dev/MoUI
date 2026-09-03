# MoUI Tutorial Skeletons

These skeletons keep new examples aligned with the current package boundaries.
They are intentionally short: copy the shape, then fill in package-local tests
before expanding behavior.

## Create A View

1. Add the public constructor under `views/` and return `@moui.View[Msg]`.
2. Put concrete reusable custom view behavior in `moui/views`, then let `views/`
   expose the app-facing constructor.
   Reuse existing state, style, binding, semantics, and layout types.
3. Add focused tests in the `moui/views` `tests/smoke` package or a focused `*_test.mbt`.
4. Add a Showcase entry when the view is user-facing.
5. Run `moon test moui/views --target native` and `moon info`.

Implement reusable built-in behavior as a concrete `@core.ViewNode` and wrap it
with `@core.View::from_node`. Do not re-export `ViewNode` from app-facing
facades or add `@core.View::primitive_*_view`, `ViewLoweringSink`, or runtime
lowering arms for a new control.

## Create A Custom Layout

1. Use `@views.custom_children_layout` for the first version.
2. Read `CustomLayoutContext.child_sizes`, `child_baselines`,
   `child_alignment_guides`, `child_priorities`, `safe_area`, `viewport`, and
   `layout_direction`.
3. Store reusable measurements in `CustomLayoutContext.cache`.
4. Use `CustomPlacementContext::mirror_x` for RTL-aware x placement.
5. Add tests in `moui/views` (`tests/smoke` or a focused `*_test.mbt`) or core white-box tests when the runtime
   contract changes.

## Create A Platform Service

1. Add the typed request/response to `backend` first.
2. Gate dispatch through `HostServiceCapabilities`.
3. Add platform-local bridge constructors in the relevant backend package.
4. Keep unavailable platforms explicit with `HostServiceBridge::unavailable`.
5. Add host tests plus at least one backend scaffold test.

## Change Text Behavior

1. Read `docs/text-system.md` before changing measurement, shaping, glyph
   rasterization, embedded font registration, or startup text-engine options.
2. Keep `core` limited to the neutral `TextSystem` contract and deterministic
   fallback.
3. Put native provider work under the relevant `moui_wgpu_renderer/*` package and keep
   Web text changes aligned with `backend/web`.
4. Add focused core, renderer, backend, or provider tests for the boundary you
   changed.
5. Update `docs/text-system.md`, `docs/renderer-capability-report.md`, and
   guidance files when the behavior or maintenance rules change.

## Update Renderer Capability

1. Add or update the `@core.DrawCommand` intent.
2. Update renderer fallback planning in `render/capabilities.mbt`.
3. Update native/Web renderer behavior or report the planned fallback.
4. Update `docs/renderer-capability-report.md`.
5. Run `moon test moui/render --target native`,
   `moon test moui_wgpu_renderer --target native`, and
   `moon test moui_web_renderer --target wasm-gc`.

## Add A Showcase Entry

1. Put shared behavior in `examples/showcase/app`.
2. Add category metadata, preview, API notes, semantics notes, test coverage, and
   renderer notes.
3. Prefer list-detail entries that demonstrate real controls over static copy.
4. Run `moon test examples/showcase/app --target native`.

## Update Guidance

1. Check `AGENTS.md` and `skills/` when docs placement, validation commands,
   package layout, example structure, renderer status, platform behavior, or
   text architecture changes.
2. Keep skill instructions short and operational.
3. If guidance files do not need edits, mention that they were checked in the
   handoff.
