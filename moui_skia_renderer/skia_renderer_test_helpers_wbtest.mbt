///|
fn skia_test_temp_env(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let clean = value.trim().to_owned()
      if clean == "" {
        None
      } else {
        Some(clean)
      }
    }
    None => None
  }
}

///|
fn skia_test_temp_dir() -> String {
  let names = ["MOUI_TEST_TMPDIR", "TMPDIR", "TEMP", "TMP"]
  for name in names {
    match skia_test_temp_env(name) {
      Some(value) => return value
      None => ()
    }
  }
  "/tmp"
}

///|
fn skia_test_temp_path(filename : String) -> String {
  let dir = skia_test_temp_dir()
  let chars = dir.to_array()
  if chars.length() == 0 {
    filename
  } else if chars[chars.length() - 1] == '/' ||
    chars[chars.length() - 1] == '\\' {
    dir + filename
  } else {
    dir + "/" + filename
  }
}

///|
fn skia_test_native_text_available() -> Bool {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => skia_test_font_has_visible_text(font, "Slim")
    None => false
  }
}

///|
fn skia_test_font_has_visible_text(
  font : @skia_native.Font,
  text : String,
) -> Bool {
  skia_measure_text_width(font, text) > 0.0 &&
  skia_glyph_run_has_visible_glyphs(
    skia_glyph_run_with_shaper(font, text, use_shaper=true),
  )
}

///|
fn skia_test_region_has_dark_pixel(
  frame : SkiaPixelFrame,
  rect : @core.Rect,
) -> Bool {
  skia_test_region_has_matching_pixel(frame, rect, (r, g, b, a) => {
    a > 0 && r < 210 && g < 210 && b < 210
  })
}

///|
fn skia_test_region_has_matching_pixel(
  frame : SkiaPixelFrame,
  rect : @core.Rect,
  matches : (Int, Int, Int, Int) -> Bool,
) -> Bool {
  let min_x = rect.origin.x.floor().to_int().max(0)
  let min_y = rect.origin.y.floor().to_int().max(0)
  let max_x = (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
  let max_y = (rect.origin.y + rect.size.height)
    .ceil()
    .to_int()
    .min(frame.height)
  for y in min_y..<max_y {
    for x in min_x..<max_x {
      let offset = y * frame.row_bytes + x * 4
      if offset + 3 < frame.pixels.length() {
        let actual_r = frame.pixels[offset].to_int()
        let actual_g = frame.pixels[offset + 1].to_int()
        let actual_b = frame.pixels[offset + 2].to_int()
        let actual_a = frame.pixels[offset + 3].to_int()
        if matches(actual_r, actual_g, actual_b, actual_a) {
          return true
        }
      }
    }
  }
  false
}

///|
fn skia_test_draw_frame(commands : Array[@core.DrawCommand]) -> @core.DrawFrame {
  @core.DrawFrame::new(
    commands~,
    damage=@core.DamageRegion::full("skia renderer test"),
  )
}

///|
fn skia_test_draw_frame_with_damage(
  commands : Array[@core.DrawCommand],
  damage : @core.DamageRegion,
) -> @core.DrawFrame {
  @core.DrawFrame::new(commands~, damage~)
}

///|
fn skia_test_font(font : @core.FontSpec) -> @skia_native.Font? {
  skia_font_with_resolution_for_text(
    font,
    "",
    SkiaFontResolution::SystemFontMgr,
  )
}
