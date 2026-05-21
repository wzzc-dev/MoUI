# MoUI Tutorial Skeletons

These skeletons keep new examples aligned with the current package boundaries.
They are intentionally short: copy the shape, then fill in package-local tests
before expanding behavior.

## Create A View

1. Add the public constructor under `views/` and return `@core.ViewSpec`.
2. Reuse existing `@core` state, style, binding, semantics, and layout types.
3. Add focused tests in `views/views_test.mbt`.
4. Add a Showcase entry when the view is user-facing.
5. Run `moon test views --target native` and `moon info`.

## Create A Custom Layout

1. Use `ViewSpec::custom_layout` for the first version.
2. Read `CustomLayoutContext.child_sizes`, `child_baselines`,
   `child_alignment_guides`, `child_priorities`, `safe_area`, `viewport`, and
   `layout_direction`.
3. Store reusable measurements in `CustomLayoutContext.cache`.
4. Use `CustomPlacementContext::mirror_x` for RTL-aware x placement.
5. Add tests in `core/advanced_layout_test.mbt`.

## Create A Platform Service

1. Add the typed request/response to `backend/host` first.
2. Gate dispatch through `HostServiceCapabilities`.
3. Add platform-local bridge constructors in the relevant backend package.
4. Keep unavailable platforms explicit with `HostServiceBridge::unavailable`.
5. Add host tests plus at least one backend scaffold test.

## Update Renderer Capability

1. Add or update the `@core.DrawCommand` intent.
2. Update renderer fallback planning in `render/capabilities.mbt`.
3. Update native/Web renderer behavior or report the planned fallback.
4. Update `docs/renderer-capability-report.md`.
5. Run `moon test render --target native`, `moon test render/wgpu --target native`,
   and `moon test render/webgpu_adapter --target wasm-gc`.

## Add A Showcase Entry

1. Put shared behavior in `examples/showcase/app`.
2. Add category metadata, preview, API notes, semantics notes, test coverage, and
   renderer notes.
3. Prefer list-detail entries that demonstrate real controls over static copy.
4. Run `moon test examples/showcase/app --target native`.
