# Plan: Public ViewNode trait and typed adapter refactor

- **Status:** active
- **RFC:** [#3](https://github.com/wzzc-dev/MoUI/issues/3) (accepted 2026-07-26)
- **ADR:** [0015](../../decisions/0015-core-protocols.md)
- **Goal:** Make `ViewNode` the sole public low-level custom-control protocol
  while preserving typed `View[Msg]`, TEA message composition, and private
  runtime lifecycle ownership.
- **Non-goals:** compatibility aliases, a high-level component trait, public
  runtime trees, renderer/backend extension through this trait, or new core
  primitive view variants.

## Public contract

- `pub(open) trait ViewNode`: message-independent, object-safe behavior.
- `View::from_node[Node : ViewNode, Msg]`: typed children, build, event, and
  text-command adapters.
- Remove public `View::node`; do not re-export `ViewNode` from the root facade.
- Keep `View::map`, `Program`, `Effect`, and `Subscription` typed.

## Delivery sequence

1. Add the core trait, typed adapter representation, `View::from_node`, and
   downstream black-box tests.
2. Move transient interaction state to `ElementControlState`; preserve/reset it
   through element identity rather than erased view reconstruction.
3. Replace `ErasedViewNode` with private `RuntimeViewNode` and defer message
   delivery until event-local state and routing are committed.
4. Migrate core modifiers, runtime fixtures, and every `moui/views` behavior
   family to concrete node structs plus typed adapters.
5. Remove the old callback API and closure records, regenerate interfaces, and
   update invariants, validators, docs, skills, and Chinese guidance.
6. Run focused package checks, cross-target checks, daily validation, Web
   presentation, and native Skia smoke.

## Acceptance

- [x] External package tests can implement `ViewNode` and construct a typed
  `View[Msg]`.
- [x] No public `View::node`, private `ViewNode[Msg]`, `ErasedViewNode`, or
  compatibility shim remains.
- [x] Same identity preserves all control/text state; remount resets it.
- [x] Event state commits before FIFO typed message delivery.
- [x] Revision and paint-revision dirty classification remains correct.
- [x] Pointer, focus, keyboard, semantics, text editing, WebView, children, and
  component-build behavior passes focused regression tests.
- [ ] Native, wasm-gc, wasm, generated API, repository validators, daily, Web,
  and macOS Skia checks pass.

## Validation status (2026-07-26)

- Passed: `moui/core` 14/14, `moui/runtime` 58/58, `moui/views` 37/37,
  `moui_skia_renderer` 110/110, `moui_richtext` 174/174, and native
  `moui_webview/views` check.
- Passed: wasm-gc and wasm workspace checks, wasm-gc `moon info`, API surface
  tests 25/25, harness invariant tests 7/7, API guard, website-docs check,
  formatter check, and diff whitespace check.
- Passed: macOS Skia raster renderer smoke with real pixels, async-image second
  frame/deferred completion, and Showcase build.
- Blocked outside this refactor: native workspace check has two
  `WindowHandle`/`UInt64` mismatches in `moui_skia` triangle examples;
  maintenance baseline exceeds budgets only in two concurrently changed render
  capability files; Web presentation reaches a nonblank running Showcase but
  its fixed input probe does not hit a text control, so required IME markers are
  absent.
- Environment limitation: the default macOS GPU smoke requires a missing
  `libskia_ganesh_ext.dylib`; the published `wzzc-dev/window@0.5.4-0.1.7`
  dependency is currently unavailable from the configured registry, so the
  standard (local-window-off) daily profile cannot resolve all dependencies.

## Workspace hygiene

- Preserve the pre-existing `.gitignore` change.
- Remove compiler probe outputs `trait_probe.ast` and
  `trait_probe.typechecked` before completion.
