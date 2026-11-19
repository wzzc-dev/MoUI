# moui_p5

p5-style creative coding for MoUI. The addon owns the renderer-neutral p5 core
(sketch lifecycle, color, math, paths, images, surfaces) and a MoUI adapter that
replays a sketch as `DrawCommand` streams, so the same sketch runs on every MoUI
renderer.

## Packages

- `wzzc-dev/moui_p5` — core sketch/color/math/path/image/surface API and a
  `Recorder` surface for headless tests.
- `wzzc-dev/moui_p5/moui` — `SketchView` canvas view, input mapping, canvas
  readback, and draw-command adapter.
- `wzzc-dev/moui_p5/http` — native async `https:` image loader
  (`RemoteImageLoader`) for `load_image_async`.

## Host byte I/O

The addon carries no filesystem dependency. Image loading and saving go through
`FilePorts`, a loader/saver closure pair injected by the host:

- install once with `set_default_file_ports`, and sketches created afterwards
  inherit it; or
- pass `file_ports=` to `Sketch::new`, or call `Sketch::set_file_ports`.

`FilePorts::none()` rejects every operation, which keeps wasm hosts on the
previous "cannot read or write files" behavior. Native hosts typically back the
ports with the platform filesystem package; tests use an in-memory byte map.

## Example

The runnable demo lives in `examples/p5_sketch`: a native macOS Skia entrypoint,
a wasm entrypoint, and the interactive demos in `examples/p5_sketch/app`.
