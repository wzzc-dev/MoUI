///|
fn main {
  smoke_mark(b"start")
  if !@native.skia_available() {
    fail_smoke(
      "real Skia backend is unavailable; configure native/moon.pkg with MOUI_SKIA_HAS_SKIA, Skia headers, and linker flags",
    )
  }

  let size = @skia.ISize::new(32, 32)
  guard make_smoke_surface(size) is Some(surface) else {
    fail_smoke("failed to prepare native smoke surface")
  }

  guard surface.canvas() is Some(canvas) else {
    fail_smoke("failed to borrow native canvas")
  }

  draw_canvas_primitive_smoke(canvas)
  guard run_shader_filter_smoke(canvas) is Some(shader_filters) else {
    fail_smoke("failed to run shader/filter native smoke checks")
  }
  run_native_path_smoke(canvas)
  guard run_canvas_readback_smoke(surface, canvas, size) is Some(red_bounds) else {
    fail_smoke("failed to run canvas readback native smoke checks")
  }
  run_non_finite_canvas_guard_smoke()

  run_render_replay_smoke(
    shader_filters.color_shader_descriptor,
    shader_filters.color_filter_descriptor,
    shader_filters.image_filter_descriptor,
    shader_filters.mask_filter_descriptor,
  )

  run_image_codec_smoke(surface, canvas, size, red_bounds)

  guard @native.Font::default(size=10.0) is Some(font) else {
    fail_smoke("failed to create default native font")
  }
  run_text_font_smoke(canvas, font)
  run_paragraph_smoke()

  smoke_mark(b"done")
  println("moui_skia native smoke test passed")
}
