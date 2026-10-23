# Pointer stream identity in MoUI

- **Plan**: `docs/plans/active/pointer-input-parity.md` (§4, landed 2026-10-23).

## Standing facts

- `PointerEvent.id == 0` is the **primary stream**: mouse, pen, trackpad, every
  runtime-synthesized event, and the first finger on hosts that report no finger
  identity. Never renumber or offset finger ids: iOS/Android/HarmonyOS
  `host_queue.mbt` hardcode `FingerId::from_raw(0)`, so a secondary-only device
  is the failure mode if the decode layer "helpfully" shifts ids.
- `PointerEvent.pressure == 1.0` means **the host gave no pressure signal**, not
  "pressed at full force". Views must not test `pressure > 0.0`; NaN and
  out-of-range force reports clamp to 1.0.
- Capture and the frame-tick re-sample live in `AnimFocusState`:
  `pointer_captures : Map[Int32, ElementId]` and
  `pointer_presses : Map[Int32, Point]`. Those maps are the only live capture
  mechanism. `ElementNode::has_local_active_pointer_capture` is a `false` stub
  and every entry point passes `capture_lookup=false`, so
  `has_active_pointer_capture`, `active_pointer_capture_id` and the
  "explicit local capture keeps precedence" branch are unreachable — do not
  reason about capture from those names.
- Hover (`Exit` synthesis) and the `Down` focus commit are **primary-stream
  only**, because they are per element, not per pointer.
  `RuntimeInspectorSnapshot::last_event_hit_path` is likewise the last stream to
  deliver, not keyed by id.
- The Web pointer ABI is positional and 10 parameters deep
  (`raw_id, kind, x, y, delta_x, delta_y, button, modifiers, pointer_id,
  pressure`). `browser_runtime.js` is the only caller of the
  `web_dispatch_pointer_input` wasm export; the workspace forwarders
  (10 files: `examples/{counter,new_world,showcase,multi_window,mo_desktop,design_systems,three_d_viewer}/web_wasm`,
  `moui_studio/web_wasm`, `website/web_wasm`, `website/playground/web_wasm`) and
  the playground `compiler-worker.js` inline template all have to move in the
  same change. There is no compatibility shim.
- **The `moui_cli` scaffold template is not one of them.** `web_abi_shim_mbt()`
  is shared by `moui new` and the Studio export bundle, and both land *outside*
  the workspace: the generated project resolves `wzzc-dev/moui@<published>` from
  the registry, and its `web_wasm/index.html` loads
  `.mooncakes/wzzc-dev/moui/backend/web/browser_runtime.js` — the published JS.
  So the template must carry the **published** arity (8 parameters on the 0.2.x
  line) and only moves when the release line moves. Bumping it ahead of the
  release makes `moui_studio/services/compile_native` red at
  `moon build --target wasm-gc` inside the generated bundle.
- Nothing in the `pr` profile compiles the workspace Web entrypoints: an arity
  mismatch in `examples/*/web_wasm/abi.mbt` is invisible until
  `moon check examples/... --target wasm-gc` (or the web smoke) runs. `moon info`
  also cannot refresh those `pkg.generated.mbti` files — it canonicalizes on
  native and prints `Skipping package ...: it does not support target backend
  native`, so the committed wasm-only interfaces are stale by construction (they
  still spell `Int` where the source says `Int32`). Do not hand-edit them.

## Why

Two failure classes are silent. Flattening capture to one slot makes a second
finger steal the control the first finger is dragging — and synthesizing an
`Exit` from that second finger cancels its press tint and its in-flight gesture,
with no error anywhere. On the Web side, a forwarder that keeps the old
parameter list just stops carrying identity, so the app sees every touch as the
primary stream.

## How to apply

When touching pointer transport, decode, or the Web input ABI, check all three
layers at once: `moui/core` contract, `moui/backend` decode plus
`browser_runtime.js`, and `moui/runtime` per-id state. Then compile every Web
entrypoint at its own target — one command for all of them is
`moon check examples/counter/web_wasm examples/new_world/web_wasm
examples/showcase/web_wasm examples/multi_window/web_wasm
examples/mo_desktop/web_wasm examples/design_systems/web_wasm
examples/three_d_viewer/web_wasm moui_studio/web_wasm website/web_wasm
website/playground/web_wasm --target wasm-gc`. Evidence to keep green:
`moui/runtime/multi_pointer_input_wbtest.mbt`,
`moui/backend/common/input/window_event_decode_test.mbt`, and
`scripts/test-browser-runtime-events.mjs` (needs a modern node — PATH node 18
treats the extensionless `.js` ESM as CommonJS, and it also breaks the published
`moui_skia_renderer` prebuild inside a Studio export bundle). Related:
`memories/repo/input-dispatch-geometry.md`,
`memories/repo/mooncakes-release-playbook.md`.
