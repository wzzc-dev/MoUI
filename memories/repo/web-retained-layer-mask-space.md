# Web renderer: retained-layer masks must be transformed to screen space

## Rule

`ViewPaintLayer` commands and frames are node-local (see `ViewPaintContext.frame`
doc: "the runtime applies the accumulated parent/child transform around them").
The runtime's transform-based frame walk (`collect_frame_commands_with_overlays`)
emits paint-layer content raw inside the enclosing `PushTransform` scopes, and
`BeginRetainedLayer(spec)` carries `spec.frame = paint_bounds` in that same
node-local space. The webgpu JS host therefore must apply the active state
transform to `push_layer` masks — exactly like `push_clip` does — before
storing/compositing them. `compositeScope` intersects the mask with the
screen-space `layer.clip`; an untransformed mask from a nested view (e.g. the
playground editor's rich-text blocks) intersects to empty and silently culls
the whole layer, which showed as "playground editor renders no code text"
(root-level views masked the bug because node-local == screen space there).

Same contract on the canvas2d fallback: masks scale by DPR via `scx`/`scy` and
rely on the main-context transform being identity at push time; its full-app
path was verified healthy once the layer-mask fix landed in runtime.js.

## Debugging playbook that cracked it

1. MoonBit `AppRuntime::draw_frame()` in a wbtest proved the frame commands were
   complete (DrawText inside Begin/EndRetainedLayer with sane local frames) —
   moved the hunt to the renderer.
2. A page-side probe driving `createWebGpuImportsAsync` directly reproduced the
   blank with `push_transform + push_clip + push_layer(local mask) + draw_text`
   and passed with a root-level layer, isolating the mask/clip space mismatch.
3. The IAB webview shares HTTP cache across 127.0.0.1 ports; serve patched
   builds on `localhost` or a fresh port+path when iterating on runtime.js.

Also note: `three_d_update_resources` had been merge-spliced into the middle of
the `push_layer` object literal in runtime.js (parsed OK, worked by accident);
restored next to the other `three_d_*` imports.
