# WebGPU Wasm-GC Host Boundary

`render/webgpu_adapter` is the only Web renderer path. It targets MoonBit `wasm-gc` and calls a browser-provided `webgpu` import module.

This package intentionally does not depend on WIT/component today. The public boundary is kept thin so a future WIT/component migration can replace only the port implementation:

```text
WebGpuWasmRenderer
  -> WebGpuHostRendererPort
  -> wasm-gc webgpu imports today
  -> WIT/component resources later
```

The rest of MoUI should depend on `WebGpuWasmRenderer`, `WebGpuHostRendererPort`, and the renderer facade concepts, not on individual import names.

## Current Host Imports

The browser loader must provide a `webgpu` import object with:

```text
capabilities:
  webgpu_available, adapter_ready, can_render

strings:
  begin_create_string, string_append_char, finish_create_string

surface:
  create_surface, surface_is_valid, surface_resize, surface_dispose

renderer:
  create_renderer, renderer_is_valid, renderer_resize, begin_frame,
  clear, fill_rect, stroke_rect, fill_rounded_rect, stroke_rounded_rect,
  draw_text, draw_image, push_clip, pop_clip, push_transform, pop_transform,
  push_opacity, pop_opacity, present, renderer_dispose
```

Opaque browser objects are represented as integer handles. That is deliberate: MoonBit `wasm-gc` host import stubs currently accept this ABI shape reliably, while direct opaque host resource types do not.

## Future WIT Migration

When MoonBit has a stable WIT/component path for `wasm-gc`, map the same conceptual operations to WIT resources:

```text
HostWebGpuSurface handle  -> resource surface
HostWebGpuRenderer handle -> resource renderer
WebGpuHostRendererPort    -> generated WIT adapter implementation
```

The migration should keep `backend/web` and core draw-command conversion unchanged except for swapping `wasm_gc_host_port()` to a generated WIT-backed port.
