# MoUI Metal Renderer

Experimental direct-Metal renderer for `wzzc-dev/moui`: no Skia and no wgpu are
linked. The only graphics dependency is Apple's Metal framework, and the host
platform backend keeps owning the window and its `CAMetalLayer` — this module
binds the layer handle the backend hands it and draws into it.

Plan stages L1 and L2 are landed (`docs/plans/active/no-third-party-gpu-route.md`,
ADR 0044/0045): every `PlanOp` variant the shared lowering can emit has a draw
arm, and degradations are counted rather than hidden. L3 (text fidelity) and L4
(capability truth, GPU recovery) are open. The product class is experimental;
nothing here is a usability commitment.

Where to read the code: `renderer.mbt` owns the session and presentation,
`metal_geometry.mbt` walks the plan into the frame's buffers,
`metal_geometry_wire.mbt` is the byte layout and the code values MSL interprets,
`metal_geometry_scopes.mbt` the clip/filter/layer stack and pass slots,
`metal_text.mbt` and `metal_image.mbt` the two caches, and
`metal_renderer.mm` + `metal_shaders.h` the Metal bridge and its embedded shader
source.

The composition root injects the text engine, so this module depends on no text
provider:

```moonbit nocheck
@runtime.run_app("MoUI Showcase", runtime)
  .render(
    @render_metal.metal(
      text_engine=@render_metal.native_platform_text_engine(
        @text_coretext.coretext_text_engine(),
      ),
    ),
  )
  .backend(@macos_backend.entry())
  .run()
```

Evidence commands on macOS:

```sh
moon test moui_metal_renderer --target native
moon run moui_tests/metal_renderer_smoke/macos --target native
MOUI_MACOS_METAL_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/showcase/macos_metal --target native
```

ADR 0045 records what the route claims, what it refuses to approximate, and the
two toolchain link-flag facts it settled.
