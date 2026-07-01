///|
fn fail_smoke(message : String) -> Unit {
  println(message)
  abort("MoUI Skia renderer smoke failed")
}

///|
fn smoke_temp_env(name : String) -> String? {
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
fn smoke_env_flag_enabled(name : String) -> Bool {
  match smoke_temp_env(name) {
    Some(value) =>
      value == "1" ||
      value == "true" ||
      value == "TRUE" ||
      value == "yes" ||
      value == "YES" ||
      value == "on" ||
      value == "ON"
    None => false
  }
}

///|
fn smoke_temp_dir() -> String {
  let names = ["MOUI_TEST_TMPDIR", "TMPDIR", "TEMP", "TMP"]
  for name in names {
    match smoke_temp_env(name) {
      Some(value) => return value
      None => ()
    }
  }
  "/tmp"
}

///|
fn smoke_temp_path(filename : String) -> String {
  let dir = smoke_temp_dir()
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
fn assert_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  x : Int,
  y : Int,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit {
  if x < 0 || y < 0 || x >= frame.width || y >= frame.height {
    fail_smoke("pixel sample is outside the Skia frame")
  }
  let offset = y * frame.row_bytes + x * 4
  if offset + 3 >= frame.pixels.length() {
    fail_smoke("pixel sample exceeds the Skia frame payload")
  }
  let actual_r = frame.pixels[offset].to_int()
  let actual_g = frame.pixels[offset + 1].to_int()
  let actual_b = frame.pixels[offset + 2].to_int()
  let actual_a = frame.pixels[offset + 3].to_int()
  if actual_r != r || actual_g != g || actual_b != b || actual_a != a {
    println("unexpected Skia renderer pixel at \{x},\{y}")
    println("expected rgba=\{r},\{g},\{b},\{a}")
    println("actual rgba=\{actual_r},\{actual_g},\{actual_b},\{actual_a}")
    fail_smoke("MoUI Skia renderer smoke pixel mismatch")
  }
}

///|
fn assert_pixel_near(
  frame : @skia_renderer.SkiaPixelFrame,
  x : Int,
  y : Int,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
  tolerance : Int,
) -> Unit {
  if x < 0 || y < 0 || x >= frame.width || y >= frame.height {
    fail_smoke("pixel sample is outside the Skia frame")
  }
  let offset = y * frame.row_bytes + x * 4
  if offset + 3 >= frame.pixels.length() {
    fail_smoke("pixel sample exceeds the Skia frame payload")
  }
  let actual_r = frame.pixels[offset].to_int()
  let actual_g = frame.pixels[offset + 1].to_int()
  let actual_b = frame.pixels[offset + 2].to_int()
  let actual_a = frame.pixels[offset + 3].to_int()
  if !component_near(actual_r, r, tolerance) ||
    !component_near(actual_g, g, tolerance) ||
    !component_near(actual_b, b, tolerance) ||
    !component_near(actual_a, a, tolerance) {
    println("unexpected Skia renderer pixel at \{x},\{y}")
    println("expected rgba near=\{r},\{g},\{b},\{a} tolerance=\{tolerance}")
    println("actual rgba=\{actual_r},\{actual_g},\{actual_b},\{actual_a}")
    fail_smoke("MoUI Skia renderer smoke pixel mismatch")
  }
}

///|
/// Like assert_pixel_near, but accepts an alternative (unfiltered) expected
/// color when ColorFilter is unavailable. Release Skia binaries may omit
/// SkColorFilter.h, making PushFilter(Brightness/Saturate/Contrast/ColorMatrix)
/// a no-op. In that case the source color is drawn unchanged.
fn assert_pixel_near_filter_aware(
  frame : @skia_renderer.SkiaPixelFrame,
  x : Int,
  y : Int,
  filtered_r : Int,
  filtered_g : Int,
  filtered_b : Int,
  filtered_a : Int,
  unfiltered_r : Int,
  unfiltered_g : Int,
  unfiltered_b : Int,
  unfiltered_a : Int,
  tolerance : Int,
) -> Unit {
  let (er, eg, eb, ea) = if color_filters_available() {
    (filtered_r, filtered_g, filtered_b, filtered_a)
  } else {
    (unfiltered_r, unfiltered_g, unfiltered_b, unfiltered_a)
  }
  assert_pixel_near(frame, x, y, er, eg, eb, ea, tolerance)
}

///|
fn assert_pixel_luma_between(
  frame : @skia_renderer.SkiaPixelFrame,
  x : Int,
  y : Int,
  min_luma : Int,
  max_luma : Int,
  a : Int,
) -> Unit {
  if x < 0 || y < 0 || x >= frame.width || y >= frame.height {
    fail_smoke("pixel sample is outside the Skia frame")
  }
  let offset = y * frame.row_bytes + x * 4
  if offset + 3 >= frame.pixels.length() {
    fail_smoke("pixel sample exceeds the Skia frame payload")
  }
  let actual_r = frame.pixels[offset].to_int()
  let actual_g = frame.pixels[offset + 1].to_int()
  let actual_b = frame.pixels[offset + 2].to_int()
  let actual_a = frame.pixels[offset + 3].to_int()
  let actual_luma = (actual_r + actual_g + actual_b) / 3
  if actual_luma < min_luma || actual_luma > max_luma || actual_a != a {
    println("unexpected Skia renderer luma at \{x},\{y}")
    println("expected luma between \{min_luma} and \{max_luma} alpha=\{a}")
    println(
      "actual rgba=\{actual_r},\{actual_g},\{actual_b},\{actual_a} luma=\{actual_luma}",
    )
    fail_smoke("MoUI Skia renderer smoke pixel mismatch")
  }
}

///|
fn assert_region_has_pixel_near(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
  tolerance : Int,
) -> Unit {
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
        if component_near(actual_r, r, tolerance) &&
          component_near(actual_g, g, tolerance) &&
          component_near(actual_b, b, tolerance) &&
          component_near(actual_a, a, tolerance) {
          return ()
        }
      }
    }
  }
  println(
    "no Skia renderer pixel near rgba=\{r},\{g},\{b},\{a} tolerance=\{tolerance} in region",
  )
  fail_smoke("MoUI Skia renderer smoke missing expected region color")
}

///|
fn component_near(actual : Int, expected : Int, tolerance : Int) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
fn assert_region_has_dark_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Unit {
  if region_has_dark_pixel(frame, rect) {
    return ()
  }
  fail_smoke("MoUI Skia smoke text region did not contain rendered dark pixels")
}

///|
fn assert_region_has_redish_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Unit {
  if region_has_pixel_matching(frame, rect, (r, g, b, a) => {
      a > 0 && r > 170 && g < 120 && b < 130
    }) {
    return ()
  }
  fail_smoke("MoUI Skia smoke region did not contain a red marker pixel")
}

///|
fn assert_region_has_blueish_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Unit {
  if region_has_pixel_matching(frame, rect, (r, g, b, a) => {
      a > 0 && b > 150 && r < 140 && g < 150
    }) {
    return ()
  }
  fail_smoke("MoUI Skia smoke region did not contain a blue marker pixel")
}

///|
fn assert_region_has_purpleish_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Unit {
  if region_has_pixel_matching(frame, rect, (r, g, b, a) => {
      a > 0 && r > 70 && r < 210 && b > 70 && b < 230 && g < 150
    }) {
    return ()
  }
  fail_smoke("MoUI Skia smoke region did not contain a radial mid marker pixel")
}

///|
/// Checks the magenta rect that is expected to be darkened by a Brightness
/// filter. When ColorFilter is unavailable (release Skia binaries may omit
/// SkColorFilter.h), the filter is a no-op and the rect stays at full
/// magenta (255, 0, 255), so we widen the predicate accordingly.
fn assert_region_has_brightness_filtered_magenta_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Unit {
  let predicate = if color_filters_available() {
    (r, g, b, a) => a > 0 && r > 70 && r < 210 && b > 70 && b < 230 && g < 150
  } else {
    (r, g, b, a) => a > 0 && r > 200 && b > 200 && g < 100
  }
  if region_has_pixel_matching(frame, rect, predicate) {
    return ()
  }
  fail_smoke(
    "MoUI Skia smoke region did not contain a brightness-filtered magenta pixel",
  )
}

///|
fn assert_region_has_no_dark_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Unit {
  if region_has_dark_pixel(frame, rect) {
    fail_smoke("MoUI Skia smoke text leaked dark pixels outside its frame")
  }
}

///|
fn region_has_pixel_matching(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
  predicate : (Int, Int, Int, Int) -> Bool,
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
        if predicate(actual_r, actual_g, actual_b, actual_a) {
          return true
        }
      }
    }
  }
  false
}

///|
fn region_has_dark_pixel(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
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
        if actual_a > 0 && actual_r < 210 && actual_g < 210 && actual_b < 210 {
          return true
        }
      }
    }
  }
  false
}

///|
fn red() -> @core.Color {
  @core.Color::rgba(r=1.0, g=0.0, b=0.0)
}

///|
fn green() -> @core.Color {
  @core.Color::rgba(r=0.0, g=1.0, b=0.0)
}

///|
fn blue() -> @core.Color {
  @core.Color::rgba(r=0.0, g=0.0, b=1.0)
}

///|
fn magenta() -> @core.Color {
  @core.Color::rgba(r=1.0, g=0.0, b=1.0)
}

///|
fn cyan() -> @core.Color {
  @core.Color::rgba(r=0.0, g=1.0, b=1.0)
}

///|
fn yellow() -> @core.Color {
  @core.Color::rgba(r=1.0, g=1.0, b=0.0)
}

///|
fn gray(value : Double) -> @core.Color {
  @core.Color::rgba(r=value, g=value, b=value)
}

///|
fn one_pixel_red_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
fn one_pixel_red_png_bytes() -> Bytes {
  @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==",
    ignore_whitespace=true,
  ) catch {
    _ => abort("failed to decode embedded Skia smoke PNG")
  }
}

///|
fn write_local_smoke_png(path : String) -> Unit {
  @fs.write_bytes_to_file(path, one_pixel_red_png_bytes()) catch {
    _ => fail_smoke("failed to write local Skia smoke PNG")
  }
}

///|
fn remove_local_smoke_file(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
fn missing_image_source() -> String {
  smoke_temp_path("moui-skia-renderer-smoke-missing-image.png")
}

///|
fn renderer_smoke_commands(local_png_path : String) -> Array[@core.DrawCommand] {
  [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=4.0, y=4.0, width=10.0, height=10.0),
      red(),
    ),
    @core.DrawCommand::StrokeRect(
      @core.Rect::new(x=18.0, y=4.0, width=12.0, height=12.0),
      green(),
      2.0,
    ),
    @core.DrawCommand::FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=36.0, y=4.0, width=12.0, height=12.0),
        radius=3.0,
      ),
      blue(),
    ),
    @core.DrawCommand::StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=52.0, y=4.0, width=12.0, height=12.0),
        radius=3.0,
      ),
      magenta(),
      2.0,
    ),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=68.0, y=4.0, width=20.0, height=12.0),
        radius=2.0,
      ),
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=68.0, y=4.0),
        end=@core.Point::new(x=88.0, y=4.0),
        start_color=red(),
        end_color=blue(),
      ),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=4.0, y=22.0, width=8.0, height=12.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=4.0, y=22.0, width=16.0, height=12.0),
      cyan(),
    ),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=24.0, y=22.0, width=14.0, height=14.0),
        radius=5.0,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=24.0, y=22.0, width=14.0, height=14.0),
      magenta(),
    ),
    @core.DrawCommand::PopRoundedClip,
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=40.0, dy=20.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=4.0, y=4.0, width=10.0, height=10.0),
      yellow(),
    ),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=64.0, y=24.0, width=12.0, height=12.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=56.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=20.0, y=56.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=40.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(green())),
      ),
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=30.0, y=56.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=46.0, y=56.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=38.0, y=40.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(
          @core.Brush::linear_gradient(
            start=@core.Point::new(x=30.0, y=40.0),
            end=@core.Point::new(x=46.0, y=40.0),
            start_color=red(),
            end_color=blue(),
          ),
        ),
        stroke=Some(@core.Brush::solid(@core.Color::black())),
        stroke_width=1.0,
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=@core.Rect::new(x=54.0, y=42.0, width=16.0, height=16.0),
        uniforms=[4.0],
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=54.0, y=42.0),
          end=@core.Point::new(x=70.0, y=42.0),
          start_color=blue(),
          end_color=yellow(),
        ),
      ),
    ),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: one_pixel_red_png_data_uri(),
      frame: @core.Rect::new(x=76.0, y=42.0, width=12.0, height=12.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: local_png_path,
      frame: @core.Rect::new(x=90.0, y=42.0, width=5.0, height=5.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::StrokeRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=96.0, y=42.0, width=24.0, height=14.0),
        radius=3.0,
      ),
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=96.0, y=42.0),
        end=@core.Point::new(x=120.0, y=42.0),
        start_color=red(),
        end_color=blue(),
      ),
      4.0,
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=130.0, y=48.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=164.0, y=48.0)),
        ],
        stroke=Some(
          @core.Brush::linear_gradient(
            start=@core.Point::new(x=130.0, y=48.0),
            end=@core.Point::new(x=164.0, y=48.0),
            start_color=red(),
            end_color=blue(),
          ),
        ),
        stroke_width=4.0,
      ),
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=172.0, y=56.0)),
          @core.PathVerb::QuadTo(
            @core.Point::new(x=184.0, y=32.0),
            @core.Point::new(x=196.0, y=56.0),
          ),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(cyan())),
      ),
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=200.0, y=56.0)),
          @core.PathVerb::CubicTo(
            @core.Point::new(x=202.0, y=32.0),
            @core.Point::new(x=214.0, y=32.0),
            @core.Point::new(x=214.0, y=56.0),
          ),
        ],
        stroke=Some(@core.Brush::solid(@core.Color::black())),
        stroke_width=3.0,
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="Skia",
        frame=@core.Rect::new(x=4.0, y=68.0, width=48.0, height=20.0),
        font=@core.FontSpec::new(size=16.0),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=@core.RoundedRect::new(
          rect=@core.Rect::new(x=62.0, y=70.0, width=14.0, height=10.0),
          radius=3.0,
        ),
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.55),
        offset=@core.Point::new(x=0.0, y=0.0),
        blur_radius=3.0,
        spread=0.0,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=90.0, y=72.0, width=12.0, height=12.0),
      gray(0.25),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Screen),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=90.0, y=72.0, width=12.0, height=12.0),
      gray(0.5),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=108.0, y=72.0, width=12.0, height=12.0),
      gray(0.75),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Overlay),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=108.0, y=72.0, width=12.0, height=12.0),
      gray(0.25),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=126.0, y=72.0, width=12.0, height=12.0),
      gray(0.25),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Darken),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=126.0, y=72.0, width=12.0, height=12.0),
      gray(0.75),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=144.0, y=72.0, width=12.0, height=12.0),
      gray(0.75),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Lighten),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=144.0, y=72.0, width=12.0, height=12.0),
      gray(0.25),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RoundedMask(
          @core.RoundedRect::new(
            rect=@core.Rect::new(x=178.0, y=72.0, width=12.0, height=12.0),
            radius=6.0,
          ),
        ),
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=174.0, y=68.0, width=20.0, height=20.0),
      green(),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.5,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=40.0, y=104.0, width=8.0, height=8.0),
        ),
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=36.0, y=100.0, width=16.0, height=16.0),
      blue(),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=60.0, y=104.0, width=12.0, height=12.0),
      red(),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Multiply),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=60.0, y=104.0, width=12.0, height=12.0),
      cyan(),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(0.5)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=82.0, y=104.0, width=10.0, height=10.0),
      red(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PushFilter(@core.FilterEffect::Saturate(0.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=98.0, y=104.0, width=10.0, height=10.0),
      red(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PushFilter(@core.FilterEffect::Contrast(0.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=114.0, y=104.0, width=10.0, height=10.0),
      red(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PushFilter(
      @core.FilterEffect::ColorMatrix([
        0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=130.0, y=104.0, width=10.0, height=10.0),
      red(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(3.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=150.0, y=104.0, width=10.0, height=10.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: missing_image_source(),
      frame: @core.Rect::new(x=164.0, y=88.0, width=14.0, height=8.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="vignette",
        frame=@core.Rect::new(x=164.0, y=100.0, width=18.0, height=18.0),
        uniforms=[0.9],
        fallback=@core.Brush::solid(green()),
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="solid",
        frame=@core.Rect::new(x=84.0, y=132.0, width=12.0, height=10.0),
        fallback=@core.Brush::solid(magenta()),
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="linear-gradient-debug",
        frame=@core.Rect::new(x=102.0, y=132.0, width=24.0, height=10.0),
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=102.0, y=132.0),
          end=@core.Point::new(x=126.0, y=132.0),
          start_color=red(),
          end_color=blue(),
        ),
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="MMMMMMMM",
        frame=@core.Rect::new(x=132.0, y=124.0, width=8.0, height=22.0),
        font=@core.FontSpec::new(size=18.0),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.5,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=194.0, y=104.0, width=10.0, height=10.0),
        ),
      ),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(0.5)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=194.0, y=104.0, width=10.0, height=10.0),
      red(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushTransform(@core.Transform2D::{
      a: 2.0,
      b: 0.0,
      c: 0.0,
      d: 1.5,
      tx: 4.0,
      ty: 130.0,
    }),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=2.0, y=2.0, width=6.0, height=6.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=2.0, y=2.0, width=10.0, height=6.0),
      red(),
    ),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=34.0, dy=132.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.5,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=0.0, y=0.0, width=12.0, height=10.0),
        ),
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=-4.0, y=-4.0, width=20.0, height=18.0),
      blue(),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=58.0, dy=132.0),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(0.5)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      red(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopTransform,
  ]
}

///|
fn color_filters_available() -> Bool {
  @skia_native.ColorFilter::saturation(1.0) is Some(_)
}

///|
fn assert_no_unexpected_unsupported_commands(
  renderer : @skia_renderer.SkiaRasterRenderer,
  context : String,
) -> Unit {
  let diagnostics = renderer.unsupported_command_diagnostics()
  let unexpected : Array[@skia_renderer.SkiaUnsupportedCommandDiagnostic] = []
  for diagnostic in diagnostics {
    let tolerate = !color_filters_available() &&
      diagnostic.command == "PushFilter"
    if !tolerate {
      unexpected.push(diagnostic)
    }
  }
  if unexpected.length() > 0 {
    println(
      "MoUI Skia renderer smoke unsupported command diagnostics (\{context}):",
    )
    for diagnostic in diagnostics {
      println("  - \{diagnostic.command}: \{diagnostic.reason}")
    }
    fail_smoke("MoUI Skia renderer smoke hit unsupported commands (\{context})")
  }
}

///|
fn renderer_diagnostic_pixel_commands() -> Array[@core.DrawCommand] {
  [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=8.0, y=8.0, width=48.0, height=48.0),
        radius=24.0,
      ),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=32.0, y=32.0),
        radius=24.0,
        center_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
        edge_color=@core.Color::rgba(r=0.05, g=0.08, b=0.95),
      ),
    ),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=72.0, dy=8.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=48.0, height=48.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.9,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=0.0, y=0.0, width=48.0, height=48.0),
        ),
      ),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(0.6)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=4.0, y=4.0, width=14.0, height=14.0),
      magenta(),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=22.0, y=4.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=38.0, y=18.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=22.0, y=18.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(cyan())),
      ),
    ),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: one_pixel_red_png_data_uri(),
      frame: @core.Rect::new(x=2.0, y=26.0, width=8.0, height=8.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="A",
        frame=@core.Rect::new(x=32.0, y=22.0, width=20.0, height=24.0),
        font=@core.FontSpec::new(size=20.0, weight=600),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopTransform,
  ]
}

///|
fn run_renderer_diagnostic_pixel_smoke() -> Unit {
  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia renderer smoke pixel presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let renderer_result = try
    @skia_renderer.create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=128.0, height=64.0),
        scale_factor=1.0,
      ),
      target,
    )
  catch {
    err => Err(err.message())
  } noraise {
    renderer => Ok(renderer)
  }
  guard renderer_result is Ok(renderer) else {
    fail_smoke("failed to create MoUI Skia renderer smoke pixel renderer")
  }
  renderer.render(renderer_diagnostic_pixel_commands()) catch {
    err =>
      fail_smoke(
        "failed to render MoUI Skia renderer smoke pixels: \{err.message()}",
      )
  }
  assert_no_unexpected_unsupported_commands(renderer, "diagnostic-pixel")
  match captured.val {
    Some(frame) => {
      assert_region_has_redish_pixel(
        frame,
        @core.Rect::new(x=28.0, y=28.0, width=8.0, height=8.0),
      )
      assert_region_has_purpleish_pixel(
        frame,
        @core.Rect::new(x=42.0, y=28.0, width=6.0, height=8.0),
      )
      assert_region_has_blueish_pixel(
        frame,
        @core.Rect::new(x=52.0, y=28.0, width=4.0, height=8.0),
      )
      assert_region_has_brightness_filtered_magenta_pixel(
        frame,
        @core.Rect::new(x=76.0, y=12.0, width=16.0, height=16.0),
      )
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=94.0, y=12.0, width=18.0, height=16.0),
        0,
        255,
        255,
        255,
        40,
      )
      assert_region_has_redish_pixel(
        frame,
        @core.Rect::new(x=74.0, y=34.0, width=10.0, height=10.0),
      )
      assert_region_has_dark_pixel(
        frame,
        @core.Rect::new(x=104.0, y=30.0, width=20.0, height=24.0),
      )
    }
    None => fail_smoke("Skia renderer smoke presenter did not receive a frame")
  }
  renderer.dispose()
  println(
    "MoUI renderer smoke radialGradient passed center-mid-edge-pixels shader-payload",
  )
  println("MoUI renderer smoke transformPixels passed pixel-markers")
}

///|
fn run_gpu_metal_renderer_smoke() -> Unit {
  println(@skia_renderer.skia_gpu_metal_preflight_summary())
  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia GPU Metal smoke presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let result = try
    @skia_renderer.create_with_present_target_and_route(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=128.0, height=64.0),
        scale_factor=1.0,
      ),
      target,
      surface_route=@skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute,
    )
  catch {
    err => Err(err)
  } noraise {
    renderer => Ok(renderer)
  }
  match result {
    Ok(renderer) => {
      if !renderer.surface_route().is_gpu() {
        fail_smoke("MoUI Skia GPU Metal smoke did not select the GPU route")
      }
      if !renderer.surface_is_gpu() {
        fail_smoke("MoUI Skia GPU Metal smoke did not create a GPU surface")
      }
      renderer.render(renderer_diagnostic_pixel_commands()) catch {
        err =>
          fail_smoke(
            "failed to render MoUI Skia GPU Metal smoke frame: \{err.message()}",
          )
      }
      if renderer.present_count() != 1 {
        fail_smoke("MoUI Skia GPU Metal smoke did not present one frame")
      }
      assert_no_unexpected_unsupported_commands(renderer, "gpu-metal")
      match captured.val {
        Some(frame) => {
          assert_region_has_redish_pixel(
            frame,
            @core.Rect::new(x=28.0, y=28.0, width=8.0, height=8.0),
          )
          assert_region_has_purpleish_pixel(
            frame,
            @core.Rect::new(x=42.0, y=28.0, width=6.0, height=8.0),
          )
          assert_region_has_blueish_pixel(
            frame,
            @core.Rect::new(x=52.0, y=28.0, width=4.0, height=8.0),
          )
          assert_region_has_dark_pixel(
            frame,
            @core.Rect::new(x=104.0, y=30.0, width=20.0, height=24.0),
          )
        }
        None =>
          fail_smoke(
            "MoUI Skia GPU Metal smoke presenter did not receive a frame",
          )
      }
      let diagnostic = renderer.surface_diagnostic_summary()
      println("MoUI Skia GPU Metal route diagnostics: \{diagnostic}")
      renderer.dispose()
      println(
        "MoUI Skia GPU Metal renderer smoke passed route=metal-gpu surface_gpu=true present_count=1 pixel-markers",
      )
    }
    Err(err) =>
      fail_smoke(
        "failed to create MoUI Skia GPU Metal renderer: \{err.message()}",
      )
  }
}

///|
fn async_image_smoke_commands(
  local_png_path : String,
) -> Array[@core.DrawCommand] {
  [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: one_pixel_red_png_data_uri(),
      frame: @core.Rect::new(x=2.0, y=2.0, width=6.0, height=6.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: local_png_path,
      frame: @core.Rect::new(x=12.0, y=2.0, width=6.0, height=6.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]
}

///|
fn assert_image_status(
  renderer : @skia_renderer.SkiaRasterRenderer,
  source : String,
  status : @render.ImageResourceStatus,
) -> Unit {
  for record in renderer.image_resources() {
    if record.source == source {
      if record.status != status {
        fail_smoke("Skia async image smoke recorded an unexpected image status")
      }
      return ()
    }
  }
  fail_smoke("Skia async image smoke did not record the expected image source")
}

///|
fn run_async_image_second_frame_smoke() -> Unit {
  let local_png_path = smoke_temp_path(
    "moui-skia-renderer-smoke-async-image.png",
  )
  remove_local_smoke_file(local_png_path)
  write_local_smoke_png(local_png_path)
  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia async image smoke presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let renderer_result = try
    @skia_renderer.create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=24.0, height=10.0),
        scale_factor=1.0,
      ),
      target,
      async_image_loading=true,
    )
  catch {
    err => Err(err.message())
  } noraise {
    renderer => Ok(renderer)
  }
  guard renderer_result is Ok(renderer) else {
    remove_local_smoke_file(local_png_path)
    fail_smoke("failed to create MoUI Skia async image smoke renderer")
  }

  let commands = async_image_smoke_commands(local_png_path)
  renderer.render(commands) catch {
    err => {
      remove_local_smoke_file(local_png_path)
      fail_smoke(
        "failed to render MoUI Skia async image first frame: \{err.message()}",
      )
    }
  }
  if renderer.present_count() != 1 {
    remove_local_smoke_file(local_png_path)
    fail_smoke("Skia async image smoke did not present the loading frame")
  }
  assert_image_status(
    renderer,
    one_pixel_red_png_data_uri(),
    @render.ImageResourceStatus::ImageLoading,
  )
  assert_image_status(
    renderer,
    local_png_path,
    @render.ImageResourceStatus::ImageLoading,
  )

  let host_renderer = @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(
        @render.RendererSurfaceMetrics::new(
          logical_size=metrics.logical_size,
          physical_size=metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
      ) catch {
        err =>
          fail_smoke(
            "failed to resize Skia async image smoke renderer: \{err.message()}",
          )
      }
    },
    render=draw_commands => {
      renderer.render(draw_commands) catch {
        err =>
          fail_smoke(
            "failed to render Skia async image smoke host frame: \{err.message()}",
          )
      }
    },
    text_system=() => renderer.text_system(),
    image_resources=() => renderer.image_resources(),
    image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
    apply_image_resource_load_completion=Some(completion => {
      renderer.apply_image_resource_load_completion(completion)
    }),
    set_image_resource_change_callback=callback => {
      renderer.set_image_resource_change_callback(callback)
    },
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
  )
  let window_id = @host.HostWindowId::new(99)
  let tracker = @host.HostImageResourceRepaintTracker::new()
  let baseline = tracker.record_presented(window_id, host_renderer)
  if baseline.current_status_counts.loading_count != 2 {
    remove_local_smoke_file(local_png_path)
    fail_smoke("Skia async image smoke did not baseline two loading images")
  }
  let redraws : Array[@host.HostWindowId] = []
  let completion_source = @host.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => redraws.push(id),
  )
  let loader = @host.HostAsyncImageLoader::new(start_load=(
    _id,
    source,
    complete,
  ) => {
    complete(@skia_renderer.skia_image_load_completion(source))
    None
  })
  let scheduled = loader.schedule_loading_resources(
    window_id, host_renderer, completion_source,
  )
  if scheduled.loading_count != 2 || scheduled.scheduled_count != 2 {
    remove_local_smoke_file(local_png_path)
    fail_smoke("Skia async image smoke did not schedule both loading images")
  }
  if redraws.length() < 1 {
    remove_local_smoke_file(local_png_path)
    fail_smoke("Skia async image smoke did not request a repaint")
  }
  if loader.diagnostics().completed_count != 2 {
    remove_local_smoke_file(local_png_path)
    fail_smoke("Skia async image smoke did not complete both image loads")
  }
  if completion_source.diagnostics().redraw_requested_count < 1 {
    remove_local_smoke_file(local_png_path)
    fail_smoke("Skia async image smoke did not route through repaint tracker")
  }
  assert_image_status(
    renderer,
    one_pixel_red_png_data_uri(),
    @render.ImageResourceStatus::ImageReady,
  )
  assert_image_status(
    renderer,
    local_png_path,
    @render.ImageResourceStatus::ImageReady,
  )

  renderer.render(commands) catch {
    err => {
      remove_local_smoke_file(local_png_path)
      fail_smoke(
        "failed to render MoUI Skia async image second frame: \{err.message()}",
      )
    }
  }
  remove_local_smoke_file(local_png_path)
  if renderer.present_count() != 2 {
    fail_smoke("Skia async image smoke did not present the second frame")
  }
  match captured.val {
    Some(frame) => {
      assert_pixel(frame, 4, 4, 255, 0, 0, 255)
      assert_pixel(frame, 14, 4, 255, 0, 0, 255)
    }
    None =>
      fail_smoke("Skia async image smoke presenter did not receive a frame")
  }
  println("MoUI Skia async image second-frame smoke passed")
  println(
    "MoUI renderer smoke asyncImageSecondFrame passed late-completion repaint-request second-frame-pixels",
  )
}

///|
fn run_async_image_deferred_completion_smoke() -> Unit {
  // 使用 HostNativeAsyncImageSource 模拟 deferred completion（非同步完成）。
  // 这是迈向 off-main provider 的中间验证步骤：loader 不在 start_load 回调中
  // 同步调用 complete，而是将请求注册到 native_source，后续手动触发 completion。
  let local_png_path = smoke_temp_path(
    "moui-skia-renderer-smoke-async-image-deferred.png",
  )
  remove_local_smoke_file(local_png_path)
  write_local_smoke_png(local_png_path)
  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia async image deferred-completion smoke presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let renderer_result = try
    @skia_renderer.create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=24.0, height=10.0),
        scale_factor=1.0,
      ),
      target,
      async_image_loading=true,
    )
  catch {
    err => Err(err.message())
  } noraise {
    renderer => Ok(renderer)
  }
  guard renderer_result is Ok(renderer) else {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "failed to create MoUI Skia async image deferred-completion smoke renderer",
    )
  }

  let commands = async_image_smoke_commands(local_png_path)
  renderer.render(commands) catch {
    err => {
      remove_local_smoke_file(local_png_path)
      fail_smoke(
        "failed to render MoUI Skia async image deferred-completion first frame: \{err.message()}",
      )
    }
  }
  if renderer.present_count() != 1 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke did not present the loading frame",
    )
  }
  assert_image_status(
    renderer,
    one_pixel_red_png_data_uri(),
    @render.ImageResourceStatus::ImageLoading,
  )
  assert_image_status(
    renderer,
    local_png_path,
    @render.ImageResourceStatus::ImageLoading,
  )

  let host_renderer = @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(
        @render.RendererSurfaceMetrics::new(
          logical_size=metrics.logical_size,
          physical_size=metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
      ) catch {
        err =>
          fail_smoke(
            "failed to resize Skia async image deferred-completion smoke renderer: \{err.message()}",
          )
      }
    },
    render=draw_commands => {
      renderer.render(draw_commands) catch {
        err =>
          fail_smoke(
            "failed to render Skia async image deferred-completion smoke host frame: \{err.message()}",
          )
      }
    },
    text_system=() => renderer.text_system(),
    image_resources=() => renderer.image_resources(),
    image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
    apply_image_resource_load_completion=Some(completion => {
      renderer.apply_image_resource_load_completion(completion)
    }),
    set_image_resource_change_callback=callback => {
      renderer.set_image_resource_change_callback(callback)
    },
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
  )
  let window_id = @host.HostWindowId::new(100)
  let tracker = @host.HostImageResourceRepaintTracker::new()
  let baseline = tracker.record_presented(window_id, host_renderer)
  if baseline.current_status_counts.loading_count != 2 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke did not baseline two loading images",
    )
  }
  let redraws : Array[@host.HostWindowId] = []
  let completion_source = @host.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => redraws.push(id),
  )
  // 使用 HostNativeAsyncImageSource 创建 deferred loader。
  // start_load 回调只注册请求，不调用 complete —— 模拟异步加载尚未完成。
  let native_source = @host.HostNativeAsyncImageSource::new()
  let loader = native_source.loader()
  let scheduled = loader.schedule_loading_resources(
    window_id, host_renderer, completion_source,
  )
  if scheduled.loading_count != 2 || scheduled.scheduled_count != 2 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke did not schedule both loading images",
    )
  }
  // 验证两个请求被注册到 native_source 而非同步完成。
  let pending = native_source.pending_requests()
  if pending.length() != 2 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke did not register two pending requests",
    )
  }
  if loader.diagnostics().completed_count != 0 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke completed loads prematurely",
    )
  }
  // 手动触发两个 completion（模拟后台解码完成）。
  let completion1 = native_source.complete(
    window_id,
    @skia_renderer.skia_image_load_completion(one_pixel_red_png_data_uri()),
  )
  if completion1.status !=
    @host.HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke first completion was not delivered",
    )
  }
  let completion2 = native_source.complete(
    window_id,
    @skia_renderer.skia_image_load_completion(local_png_path),
  )
  if completion2.status !=
    @host.HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke second completion was not delivered",
    )
  }
  if redraws.length() < 1 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke did not request a repaint after completion",
    )
  }
  if loader.diagnostics().completed_count != 2 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke did not complete both image loads",
    )
  }
  if completion_source.diagnostics().redraw_requested_count < 1 {
    remove_local_smoke_file(local_png_path)
    fail_smoke(
      "Skia async image deferred-completion smoke did not route through repaint tracker",
    )
  }
  assert_image_status(
    renderer,
    one_pixel_red_png_data_uri(),
    @render.ImageResourceStatus::ImageReady,
  )
  assert_image_status(
    renderer,
    local_png_path,
    @render.ImageResourceStatus::ImageReady,
  )

  renderer.render(commands) catch {
    err => {
      remove_local_smoke_file(local_png_path)
      fail_smoke(
        "failed to render MoUI Skia async image deferred-completion second frame: \{err.message()}",
      )
    }
  }
  remove_local_smoke_file(local_png_path)
  if renderer.present_count() != 2 {
    fail_smoke(
      "Skia async image deferred-completion smoke did not present the second frame",
    )
  }
  match captured.val {
    Some(frame) => {
      assert_pixel(frame, 4, 4, 255, 0, 0, 255)
      assert_pixel(frame, 14, 4, 255, 0, 0, 255)
    }
    None =>
      fail_smoke(
        "Skia async image deferred-completion smoke presenter did not receive a frame",
      )
  }
  println("MoUI Skia async image deferred-completion smoke passed")
  println(
    "MoUI renderer smoke asyncImageDeferredCompletion passed deferred-completion pending-requests repaint-request second-frame-pixels",
  )
}

///|
fn main {
  if !@skia_renderer.skia_available() {
    fail_smoke(
      "real Skia backend is unavailable; configure moui_skia/native with MOUI_SKIA_HAS_SKIA, Skia headers, and linker flags before running this MoUI smoke",
    )
  }
  if @skia_native.skia_shaper_available() {
    println("MoUI Skia renderer smoke shaper available")
  }
  if smoke_env_flag_enabled("MOUI_SKIA_RUN_GPU_METAL_SMOKE") {
    run_gpu_metal_renderer_smoke()
  }

  run_renderer_diagnostic_pixel_smoke()

  let local_png_path = smoke_temp_path(
    "moui-skia-renderer-smoke-local-image.png",
  )
  remove_local_smoke_file(local_png_path)
  write_local_smoke_png(local_png_path)

  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia renderer smoke presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let renderer_result = try
    @skia_renderer.create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=216.0, height=152.0),
        scale_factor=1.0,
      ),
      target,
    )
  catch {
    err => Err(err.message())
  } noraise {
    renderer => Ok(renderer)
  }
  guard renderer_result is Ok(renderer) else {
    fail_smoke("failed to create MoUI Skia renderer")
  }

  renderer.render(renderer_smoke_commands(local_png_path)) catch {
    err => {
      remove_local_smoke_file(local_png_path)
      fail_smoke("failed to render MoUI Skia smoke frame: \{err.message()}")
    }
  }
  remove_local_smoke_file(local_png_path)

  if renderer.present_count() != 1 {
    fail_smoke("MoUI Skia renderer did not present exactly one frame")
  }
  assert_no_unexpected_unsupported_commands(renderer, "renderer-smoke")
  assert_image_resources(renderer, local_png_path)
  assert_skia_text_system_carets(renderer)

  match captured.val {
    Some(frame) => {
      if frame.width != 216 || frame.height != 152 || frame.row_bytes < 864 {
        fail_smoke("MoUI Skia smoke frame dimensions are unexpected")
      }
      assert_pixel(frame, 0, 0, 255, 255, 255, 255)
      assert_pixel(frame, 8, 8, 255, 0, 0, 255)
      assert_pixel(frame, 18, 8, 0, 255, 0, 255)
      assert_pixel(frame, 24, 10, 255, 255, 255, 255)
      assert_pixel(frame, 42, 10, 0, 0, 255, 255)
      assert_pixel(frame, 52, 10, 255, 0, 255, 255)
      assert_pixel(frame, 58, 10, 255, 255, 255, 255)
      assert_pixel_near(frame, 70, 10, 230, 0, 25, 255, 35)
      assert_pixel_near(frame, 86, 10, 25, 0, 230, 255, 35)
      assert_pixel(frame, 8, 28, 0, 255, 255, 255)
      assert_pixel(frame, 16, 28, 255, 255, 255, 255)
      assert_pixel(frame, 31, 29, 255, 0, 255, 255)
      assert_pixel(frame, 24, 22, 255, 255, 255, 255)
      assert_pixel(frame, 48, 28, 255, 255, 0, 255)
      assert_pixel_near(frame, 70, 30, 128, 128, 128, 255, 8)
      assert_pixel(frame, 12, 50, 0, 255, 0, 255)
      assert_pixel_near(frame, 38, 50, 128, 0, 128, 255, 80)
      assert_pixel(frame, 56, 44, 0, 0, 255, 255)
      assert_pixel(frame, 60, 44, 255, 255, 0, 255)
      assert_pixel(frame, 82, 48, 255, 0, 0, 255)
      assert_pixel(frame, 92, 44, 255, 0, 0, 255)
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=94.0, y=44.0, width=7.0, height=10.0),
        235,
        0,
        20,
        255,
        55,
      )
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=117.0, y=44.0, width=6.0, height=10.0),
        20,
        0,
        235,
        255,
        55,
      )
      assert_pixel(frame, 108, 48, 255, 255, 255, 255)
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=130.0, y=46.0, width=6.0, height=5.0),
        235,
        0,
        20,
        255,
        55,
      )
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=159.0, y=46.0, width=6.0, height=5.0),
        20,
        0,
        235,
        255,
        55,
      )
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=181.0, y=44.0, width=7.0, height=6.0),
        0,
        255,
        255,
        255,
        20,
      )
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=202.0, y=36.0, width=12.0, height=18.0),
        0,
        0,
        0,
        255,
        20,
      )
      assert_region_has_dark_pixel(
        frame,
        @core.Rect::new(x=4.0, y=68.0, width=48.0, height=20.0),
      )
      assert_pixel_near(frame, 69, 75, 115, 115, 115, 255, 50)
      assert_pixel_near(frame, 58, 75, 230, 230, 230, 255, 35)
      assert_pixel_near(frame, 96, 78, 159, 159, 159, 255, 8)
      assert_pixel_near(frame, 114, 78, 159, 159, 159, 255, 8)
      assert_pixel_near(frame, 132, 78, 64, 64, 64, 255, 8)
      assert_pixel_near(frame, 150, 78, 191, 191, 191, 255, 8)
      assert_pixel_near(frame, 184, 78, 0, 255, 0, 255, 8)
      assert_pixel_near(frame, 178, 72, 255, 255, 255, 255, 2)
      assert_pixel_near(frame, 44, 108, 128, 128, 255, 255, 8)
      assert_pixel(frame, 38, 108, 255, 255, 255, 255)
      assert_pixel_near(frame, 66, 110, 0, 0, 0, 255, 8)
      assert_pixel_near_filter_aware(
        frame, 86, 108, 128, 0, 0, 255, 255, 0, 0, 255, 8,
      )
      assert_pixel_near_filter_aware(
        frame, 102, 108, 54, 54, 54, 255, 255, 0, 0, 255, 8,
      )
      assert_pixel_near_filter_aware(
        frame, 118, 108, 128, 128, 128, 255, 255, 0, 0, 255, 8,
      )
      assert_pixel_near_filter_aware(
        frame, 134, 108, 0, 255, 0, 255, 255, 0, 0, 255, 8,
      )
      assert_pixel_luma_between(frame, 155, 109, 0, 160, 255)
      assert_pixel_luma_between(frame, 148, 109, 20, 245, 255)
      assert_pixel_near(frame, 142, 109, 255, 255, 255, 255, 2)
      assert_pixel_near(frame, 171, 92, 145, 163, 189, 255, 55)
      assert_pixel_near(frame, 173, 109, 0, 255, 0, 255, 45)
      assert_pixel_luma_between(frame, 181, 101, 0, 95, 255)
      assert_pixel_near_filter_aware(
        frame, 198, 108, 192, 128, 128, 255, 255, 128, 128, 255, 8,
      )
      assert_pixel(frame, 192, 108, 255, 255, 255, 255)
      assert_pixel(frame, 12, 137, 255, 0, 0, 255)
      assert_pixel(frame, 26, 137, 255, 255, 255, 255)
      assert_pixel_near(frame, 40, 137, 128, 128, 255, 255, 8)
      assert_pixel(frame, 48, 137, 255, 255, 255, 255)
      assert_pixel_near_filter_aware(
        frame, 63, 137, 128, 0, 0, 255, 255, 0, 0, 255, 8,
      )
      assert_pixel(frame, 70, 137, 255, 255, 255, 255)
      assert_pixel(frame, 90, 137, 255, 0, 255, 255)
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=103.0, y=134.0, width=7.0, height=6.0),
        235,
        0,
        20,
        255,
        55,
      )
      assert_region_has_pixel_near(
        frame,
        @core.Rect::new(x=120.0, y=134.0, width=6.0, height=6.0),
        20,
        0,
        235,
        255,
        55,
      )
      assert_region_has_dark_pixel(
        frame,
        @core.Rect::new(x=132.0, y=124.0, width=8.0, height=22.0),
      )
      assert_region_has_no_dark_pixel(
        frame,
        @core.Rect::new(x=146.0, y=124.0, width=44.0, height=22.0),
      )
      run_async_image_second_frame_smoke()
      run_async_image_deferred_completion_smoke()
      println("MoUI Skia renderer smoke passed")
    }
    None => fail_smoke("MoUI Skia smoke presenter did not receive a frame")
  }
}

///|
fn assert_image_resources(
  renderer : @skia_renderer.SkiaRasterRenderer,
  local_png_path : String,
) -> Unit {
  let resources = renderer.image_resources()
  let mut saw_data_uri_ready = false
  let mut saw_local_ready = false
  let mut saw_missing_failed = false
  for record in resources {
    if record.source == one_pixel_red_png_data_uri() &&
      record.status == @render.ImageResourceStatus::ImageReady &&
      record.width == 1 &&
      record.height == 1 {
      saw_data_uri_ready = true
    }
    if record.source == local_png_path &&
      record.status == @render.ImageResourceStatus::ImageReady &&
      record.width == 1 &&
      record.height == 1 {
      saw_local_ready = true
    }
    if record.source == missing_image_source() &&
      record.status == @render.ImageResourceStatus::ImageFailed &&
      record.diagnostic.contains("unavailable") {
      saw_missing_failed = true
    }
  }
  if !saw_data_uri_ready {
    fail_smoke("Skia smoke did not record ready data URI image")
  }
  if !saw_local_ready {
    fail_smoke("Skia smoke did not record ready local file image")
  }
  if !saw_missing_failed {
    fail_smoke("Skia smoke did not record failed missing image")
  }
}

///|
fn assert_skia_text_system_carets(
  renderer : @skia_renderer.SkiaRasterRenderer,
) -> Unit {
  let font = @core.FontSpec::new(size=18.0, weight=400)
  let layout = renderer
    .text_system()
    .measure_text(@core.TextLayoutInput::new(text="Slim", font~))
  if layout.caret_positions.length() != 5 {
    fail_smoke("Skia smoke text system did not cover every caret")
  }
  if layout.caret_positions[0] != 0.0 {
    fail_smoke("Skia smoke text system first caret is not zero")
  }
  if layout.caret_positions[4] != layout.size.width {
    fail_smoke(
      "Skia smoke text system final caret does not match measured width",
    )
  }
  if layout.baseline <= 0.0 || layout.size.height < layout.baseline {
    fail_smoke("Skia smoke text system did not use valid font metrics")
  }
  if layout.caret_positions[1] <= 0.0 ||
    layout.caret_positions[2] <= layout.caret_positions[1] {
    fail_smoke("Skia smoke text system did not return measured prefix carets")
  }
  let clamped = renderer
    .text_system()
    .measure_text(
      @core.TextLayoutInput::new(text="MoUI", font~, max_width=12.0),
    )
  if clamped.size.width != 12.0 {
    fail_smoke("Skia smoke text system did not clamp measured width")
  }
  for caret in clamped.caret_positions {
    if caret > 12.0 {
      fail_smoke("Skia smoke text system did not clamp measured carets")
    }
  }
}
