///|
pub(all) suberror SunRendererError {
  InvalidSurfaceSize(Int, Int)
  PresentFailed(String)
} derive(Eq, Debug, ToJson)

///|
pub fn SunRendererError::message(self : SunRendererError) -> String {
  match self {
    InvalidSurfaceSize(width, height) =>
      "invalid Sun raster surface size \{width}x\{height}"
    PresentFailed(description) => "Sun presenter failed: \{description}"
  }
}

///|
pub(all) struct SunPixelFrame {
  width : Int
  height : Int
  row_bytes : Int
  scale_factor : Double
  pixels : FixedArray[Byte]
  bytes : Bytes
} derive(Debug)

///|
pub(all) struct SunPresentTarget {
  description : String
  present : (SunPixelFrame) -> Bool
}

///|
pub(all) struct SunUnsupportedCommandDiagnostic {
  command : String
  reason : String
} derive(Eq, Debug, ToJson)

///|
priv enum SunCanvasScopeKind {
  Clip
  RoundedClip
  Transform
  Opacity
} derive(Eq)

///|
pub(all) struct SunRasterRenderer {
  mut metrics : @render.RendererSurfaceMetrics
  target : SunPresentTarget
  mut canvas : @sun_graphics.Canvas
  mut present_count : Int
  mut unsupported_command_count : Int
  unsupported_command_diagnostics : Array[SunUnsupportedCommandDiagnostic]
  mut last_frame : SunPixelFrame?
}

///|
pub fn SunPresentTarget::new(
  description~ : String,
  present~ : (SunPixelFrame) -> Bool,
) -> SunPresentTarget {
  { description, present }
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::SunRasterNative,
    status=@render.RendererCapabilityStatus::Supported,
    can_render=true,
    can_resize=true,
    owns_surface=true,
    description="Experimental native Sun CPU raster renderer over moui_sun graphics/text primitives with structured unsupported-command diagnostics.",
  )
}

///|
pub fn renderer_descriptor() -> @render.RendererDescriptor {
  sun_raster_native_descriptor()
}

///|
pub fn sun_raster_native_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::SunRasterNative,
    family=@render.RendererFamily::Sun,
    presentation=@render.RendererPresentationModel::CpuPixelFrame,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=@render.renderer_backend_capabilities(
      @render.RendererBackendKind::SunRasterNative,
    ),
    description="Experimental native Sun CPU raster renderer that presents copied RGBA pixel frames to host providers.",
  )
}

///|
pub fn create_with_present_target(
  metrics : @render.RendererSurfaceMetrics,
  target : SunPresentTarget,
) -> SunRasterRenderer raise SunRendererError {
  let width = sun_dim_to_int(metrics.physical_size.width)
  let height = sun_dim_to_int(metrics.physical_size.height)
  guard width > 0 && height > 0 else {
    raise SunRendererError::InvalidSurfaceSize(width, height)
  }
  {
    metrics,
    target,
    canvas: @sun_graphics.Canvas::new(width, height),
    present_count: 0,
    unsupported_command_count: 0,
    unsupported_command_diagnostics: [],
    last_frame: None,
  }
}

///|
pub fn SunRasterRenderer::resize(
  self : SunRasterRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit raise SunRendererError {
  self.metrics = metrics
  self.canvas = new_canvas_for_metrics(metrics)
}

///|
pub fn SunRasterRenderer::render(
  self : SunRasterRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit raise SunRendererError {
  self.canvas = new_canvas_for_metrics(self.metrics)
  self.canvas.clear(sun_color(@render.first_clear_color(commands)))
  self.canvas.scale(sx=self.metrics.scale_factor, sy=self.metrics.scale_factor)
  self.unsupported_command_count = 0
  self.unsupported_command_diagnostics.clear()
  let canvas_scopes : Array[SunCanvasScopeKind] = []
  let opacity_stack : Array[Double] = []
  for command in commands {
    self.render_command(command, canvas_scopes, opacity_stack)
  }
  if !canvas_scopes.is_empty() {
    for scope in canvas_scopes {
      self.record_unsupported_command(
        sun_scope_push_command(scope),
        "command stream ended with an open \{sun_scope_name(scope)} scope",
      )
    }
  }
  let frame = self.read_frame()
  self.last_frame = Some(frame)
  // Diagnostic: check multiple pixel values
  println("\{self.present_count}: frame=\{frame.width}x\{frame.height} scale=\{self.metrics.scale_factor} commands=\{commands.length()} unsupported=\{self.unsupported_command_count}")
  // Print first 8 commands
  let max_cmds = if commands.length() < 8 { commands.length() } else { 8 }
  for cmd_i in 0..<max_cmds {
    let cmd_str = match commands[cmd_i] {
      @core.DrawCommand::Clear(c) =>
        "Clear rgba=\{c.r},\{c.g},\{c.b},\{c.a}"
      @core.DrawCommand::FillRect(r, c) =>
        "FillRect x=\{r.origin.x} y=\{r.origin.y} w=\{r.size.width} h=\{r.size.height} color=\{c.r},\{c.g},\{c.b},\{c.a}"
      @core.DrawCommand::DrawText(t) =>
        "DrawText \"\{t.text}\" x=\{t.frame.origin.x} y=\{t.frame.origin.y} w=\{t.frame.size.width} h=\{t.frame.size.height}"
      _ => "other command"
    }
    println("  [\{cmd_i}] \{cmd_str}")
  }
  // Scan for non-white pixels in grid
  let mut found = false
  let mut sy = 0
  while sy < frame.height && !found {
    let mut sx = 0
    while sx < frame.width && !found {
      let off = (sy * frame.width + sx) * 4
      let pr = frame.pixels[off].to_int()
      let pg = frame.pixels[off + 1].to_int()
      let pb = frame.pixels[off + 2].to_int()
      if pr < 245 || pg < 245 || pb < 245 {
        println("  color at \{sx},\{sy} = rgba(\{pr},\{pg},\{pb},\{frame.pixels[off+3].to_int()})")
        found = true
      }
      sx = sx + 40
    }
    sy = sy + 40
  }
  if !found {
    // Show a few sample pixels
    println("  all scanned pixels are near-white (>245). Samples:")
    let sample_positions : Array[Int] = [0, 0, frame.width / 2, frame.height / 2, frame.width - 1, frame.height - 1]
    for si in 0..<3 {
      let sx_val = sample_positions[si * 2]
      let sy_val = sample_positions[si * 2 + 1]
      let soff = (sy_val * frame.width + sx_val) * 4
      println("    (\{sx_val},\{sy_val}) = rgba(\{frame.pixels[soff].to_int()},\{frame.pixels[soff+1].to_int()},\{frame.pixels[soff+2].to_int()},\{frame.pixels[soff+3].to_int()})")
    }
  }
  if (self.target.present)(frame) {
    self.present_count = self.present_count + 1
  } else {
    raise SunRendererError::PresentFailed(self.target.description)
  }
}

///|
pub fn SunRasterRenderer::text_system(
  self : SunRasterRenderer,
) -> @core.TextSystem {
  ignore(self)
  @core.TextSystem::fallback()
}

///|
pub fn SunRasterRenderer::present_count(self : SunRasterRenderer) -> Int {
  self.present_count
}

///|
pub fn SunRasterRenderer::unsupported_command_count(
  self : SunRasterRenderer,
) -> Int {
  self.unsupported_command_count
}

///|
pub fn SunRasterRenderer::unsupported_command_diagnostics(
  self : SunRasterRenderer,
) -> Array[SunUnsupportedCommandDiagnostic] {
  self.unsupported_command_diagnostics.copy()
}

///|
pub fn SunRasterRenderer::last_frame(
  self : SunRasterRenderer,
) -> SunPixelFrame? {
  self.last_frame
}

///|
pub fn SunRasterRenderer::dispose(self : SunRasterRenderer) -> Unit {
  ignore(self)
}

///|
fn new_canvas_for_metrics(
  metrics : @render.RendererSurfaceMetrics,
) -> @sun_graphics.Canvas raise SunRendererError {
  let width = sun_dim_to_int(metrics.physical_size.width)
  let height = sun_dim_to_int(metrics.physical_size.height)
  guard width > 0 && height > 0 else {
    raise SunRendererError::InvalidSurfaceSize(width, height)
  }
  @sun_graphics.Canvas::new(width, height)
}

///|
fn SunRasterRenderer::read_frame(self : SunRasterRenderer) -> SunPixelFrame {
  let pixmap = self.canvas.get_pixmap()
  let width = pixmap.get_width()
  let height = pixmap.get_height()
  let pixels = copy_fixed_pixels(pixmap.get_pixels())
  SunPixelFrame::{
    width,
    height,
    row_bytes: width * 4,
    scale_factor: self.metrics.scale_factor,
    pixels,
    bytes: pixmap.to_rgba_bytes(),
  }
}

///|
fn copy_fixed_pixels(src : FixedArray[Byte]) -> FixedArray[Byte] {
  let dst : FixedArray[Byte] = FixedArray::make(src.length(), 0)
  for index in 0..<src.length() {
    dst[index] = src[index]
  }
  dst
}

///|
fn SunRasterRenderer::render_command(
  self : SunRasterRenderer,
  command : @core.DrawCommand,
  canvas_scopes : Array[SunCanvasScopeKind],
  opacity_stack : Array[Double],
) -> Unit {
  let opacity = sun_current_opacity(opacity_stack)
  match command {
    @core.DrawCommand::Clear(color) => self.canvas.clear(sun_color(color))
    @core.DrawCommand::FillRect(rect, color) =>
      self.canvas.fill_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_paint(color, opacity),
      )
    @core.DrawCommand::StrokeRect(rect, color, width) =>
      self.canvas.stroke_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_stroke_paint(color, width, opacity),
      )
    @core.DrawCommand::FillRoundedRect(rounded, color) =>
      self.fill_rounded_rect(rounded, @core.Brush::solid(color), opacity)
    @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
      self.stroke_rounded_rect(
        rounded,
        @core.Brush::solid(color),
        width,
        opacity,
      )
    @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
      self.fill_rounded_rect(rounded, brush, opacity)
    @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
      self.stroke_rounded_rect(rounded, brush, width, opacity)
    @core.DrawCommand::DrawShadow(_) =>
      self.record_unsupported_command(
        "DrawShadow", "Sun renderer does not implement blurred shadow drawing yet",
      )
    @core.DrawCommand::DrawText(run) => {
      self.draw_text_placeholder(run, opacity)
      self.record_unsupported_command(
        "DrawText", "Sun raster drew debug placeholder glyphs; moui_sun/text font shaping is not wired to MoUI TextRun yet",
      )
    }
    @core.DrawCommand::DrawImage(_) =>
      self.record_unsupported_command(
        "DrawImage", "Sun image resource decoding is not wired to MoUI ImageRun yet",
      )
    @core.DrawCommand::PushClip(rect) => {
      self.canvas.save()
      canvas_scopes.push(SunCanvasScopeKind::Clip)
      self.canvas.intersect_clip_rect(sun_rect(rect))
    }
    @core.DrawCommand::PopClip =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        SunCanvasScopeKind::Clip,
      )
    @core.DrawCommand::PushRoundedClip(rounded) => {
      self.canvas.save()
      canvas_scopes.push(SunCanvasScopeKind::RoundedClip)
      self.canvas.intersect_clip_rect(sun_rect(rounded.rect))
      self.record_unsupported_command(
        "PushRoundedClip", "Sun renderer approximates rounded clips with their bounding rectangle",
      )
    }
    @core.DrawCommand::PopRoundedClip =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        SunCanvasScopeKind::RoundedClip,
      )
    @core.DrawCommand::PushTransform(transform) => {
      self.canvas.save()
      canvas_scopes.push(SunCanvasScopeKind::Transform)
      self.canvas.concat_transform(sun_transform(transform))
    }
    @core.DrawCommand::PopTransform =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        SunCanvasScopeKind::Transform,
      )
    @core.DrawCommand::PushOpacity(opacity) => {
      canvas_scopes.push(SunCanvasScopeKind::Opacity)
      opacity_stack.push(sun_clamp_unit(opacity))
    }
    @core.DrawCommand::PopOpacity =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        SunCanvasScopeKind::Opacity,
      )
    @core.DrawCommand::PushLayer(_) =>
      self.record_unsupported_command(
        "PushLayer", "Sun renderer does not implement offscreen layer scopes yet",
      )
    @core.DrawCommand::PopLayer =>
      self.record_unsupported_command(
        "PopLayer", "Sun renderer does not implement offscreen layer scopes yet",
      )
    @core.DrawCommand::PushFilter(_) =>
      self.record_unsupported_command(
        "PushFilter", "Sun renderer does not implement filter scopes yet",
      )
    @core.DrawCommand::PopFilter =>
      self.record_unsupported_command(
        "PopFilter", "Sun renderer does not implement filter scopes yet",
      )
    @core.DrawCommand::DrawPath(path) => self.draw_path(path, opacity)
    @core.DrawCommand::DrawShaderEffect(_) =>
      self.record_unsupported_command(
        "DrawShaderEffect", "Sun renderer does not implement shader effects yet",
      )
    @core.DrawCommand::BeginCachedLayer(_) =>
      self.record_unsupported_command(
        "BeginCachedLayer", "Sun renderer does not implement cached layer scopes yet",
      )
    @core.DrawCommand::EndCachedLayer(_) =>
      self.record_unsupported_command(
        "EndCachedLayer", "Sun renderer does not implement cached layer scopes yet",
      )
    @core.DrawCommand::DrawCachedLayer(_) =>
      self.record_unsupported_command(
        "DrawCachedLayer", "Sun renderer does not implement cached layer draws yet",
      )
  }
}

///|
fn SunRasterRenderer::fill_rounded_rect(
  self : SunRasterRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  opacity : Double,
) -> Unit {
  let rect = rounded.rect
  self.canvas.fill_rounded_rect(
    rect.origin.x,
    rect.origin.y,
    rect.size.width,
    rect.size.height,
    rounded.radius,
    sun_brush_paint(brush, opacity),
  )
}

///|
fn SunRasterRenderer::stroke_rounded_rect(
  self : SunRasterRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  width : Double,
  opacity : Double,
) -> Unit {
  let rect = rounded.rect
  self.canvas.stroke_rounded_rect(
    rect.origin.x,
    rect.origin.y,
    rect.size.width,
    rect.size.height,
    rounded.radius,
    sun_brush_stroke_paint(brush, width, opacity),
  )
}

///|
fn SunRasterRenderer::draw_path(
  self : SunRasterRenderer,
  path : @core.PathSpec,
  opacity : Double,
) -> Unit {
  let sun_path = sun_path(path)
  match path.fill {
    Some(brush) =>
      self.canvas.fill_path(sun_path, sun_brush_paint(brush, opacity))
    None => ()
  }
  match path.stroke {
    Some(brush) =>
      self.canvas.stroke_path(
        sun_path,
        sun_brush_stroke_paint(brush, path.stroke_width, opacity),
      )
    None => ()
  }
  if path.fill is None && path.stroke is None {
    self.record_unsupported_command(
      "DrawPath", "path command has neither fill nor stroke brush",
    )
  }
}

///|
fn SunRasterRenderer::draw_text_placeholder(
  self : SunRasterRenderer,
  run : @core.TextRun,
  opacity : Double,
) -> Unit {
  guard run.frame.size.width > 0.0 && run.frame.size.height > 0.0 else {
    return
  }
  guard run.text.length() > 0 else { return }
  let font_size = sun_text_placeholder_font_size(run.font.size)
  let unit = (font_size / 7.0).max(1.0)
  let advance = unit * 6.0
  let line_height = (font_size * 1.2).max(unit * 8.0)
  let paint = sun_paint(run.color, opacity)
  let lines = sun_text_placeholder_lines(run.text)
  let mut line_index = 0
  for line in lines {
    let line_top = run.frame.origin.y +
      line_index.to_double() * line_height +
      (line_height - unit * 7.0).max(0.0) * 0.5
    guard line_top < run.frame.origin.y + run.frame.size.height else { return }
    let line_width = line.length().to_double() * advance
    let start_x = sun_text_placeholder_start_x(run, line_width)
    self.draw_text_placeholder_line(
      line,
      start_x,
      line_top,
      unit,
      advance,
      run.frame,
      paint,
    )
    line_index = line_index + 1
  }
}

///|
fn SunRasterRenderer::draw_text_placeholder_line(
  self : SunRasterRenderer,
  line : Array[Char],
  start_x : Double,
  top : Double,
  unit : Double,
  advance : Double,
  frame : @core.Rect,
  paint : @sun_graphics.Paint,
) -> Unit {
  let left = frame.origin.x
  let top_bound = frame.origin.y
  let right = frame.origin.x + frame.size.width
  let bottom = frame.origin.y + frame.size.height
  let mut cursor_x = start_x
  for ch in line {
    if cursor_x >= right {
      return
    }
    let glyph = sun_debug_glyph_rows(ch)
    for row in 0..<glyph.length() {
      let row_bits = glyph[row]
      for col in 0..<5 {
        if row_bits.land(1 << (4 - col)) != 0 {
          let cell_x = cursor_x + col.to_double() * unit
          let cell_y = top + row.to_double() * unit
          let draw_left = cell_x.max(left)
          let draw_top = cell_y.max(top_bound)
          let draw_right = (cell_x + unit).min(right)
          let draw_bottom = (cell_y + unit).min(bottom)
          if draw_left < draw_right && draw_top < draw_bottom {
            self.canvas.fill_rect(
              draw_left,
              draw_top,
              draw_right - draw_left,
              draw_bottom - draw_top,
              paint,
            )
          }
        }
      }
    }
    cursor_x = cursor_x + advance
  }
}

///|
fn sun_text_placeholder_font_size(size : Double) -> Double {
  guard size == size && size > 0.0 else { return 12.0 }
  size.max(6.0).min(96.0)
}

///|
fn sun_text_placeholder_start_x(
  run : @core.TextRun,
  line_width : Double,
) -> Double {
  match run.align {
    @core.TextAlign::TextStart => run.frame.origin.x
    @core.TextAlign::TextCenter =>
      run.frame.origin.x + (run.frame.size.width - line_width) * 0.5
    @core.TextAlign::TextEnd =>
      run.frame.origin.x + run.frame.size.width - line_width
  }
}

///|
fn sun_text_placeholder_lines(text : String) -> Array[Array[Char]] {
  let lines : Array[Array[Char]] = []
  let current : Array[Char] = []
  for ch in text {
    if ch.to_int() == 10 {
      lines.push(current.copy())
      current.clear()
    } else {
      current.push(ch)
    }
  }
  lines.push(current.copy())
  lines
}

///|
fn sun_debug_glyph_rows(ch : Char) -> Array[Int] {
  let code = ch.to_int()
  let normalized = if code >= 97 && code <= 122 { code - 32 } else { code }
  match normalized {
    32 | 9 => [0, 0, 0, 0, 0, 0, 0]
    33 => [4, 4, 4, 4, 4, 0, 4]
    34 => [10, 10, 10, 0, 0, 0, 0]
    35 => [10, 31, 10, 10, 31, 10, 0]
    36 => [4, 15, 20, 14, 5, 30, 4]
    37 => [24, 25, 2, 4, 8, 19, 3]
    38 => [12, 18, 20, 8, 21, 18, 13]
    39 => [4, 4, 8, 0, 0, 0, 0]
    40 => [2, 4, 8, 8, 8, 4, 2]
    41 => [8, 4, 2, 2, 2, 4, 8]
    42 => [0, 4, 21, 14, 21, 4, 0]
    43 => [0, 4, 4, 31, 4, 4, 0]
    44 => [0, 0, 0, 0, 4, 4, 8]
    45 => [0, 0, 0, 31, 0, 0, 0]
    46 => [0, 0, 0, 0, 0, 12, 12]
    47 => [1, 2, 4, 8, 16, 0, 0]
    48 => [14, 17, 19, 21, 25, 17, 14]
    49 => [4, 12, 4, 4, 4, 4, 14]
    50 => [14, 17, 1, 2, 4, 8, 31]
    51 => [30, 1, 1, 14, 1, 1, 30]
    52 => [2, 6, 10, 18, 31, 2, 2]
    53 => [31, 16, 30, 1, 1, 17, 14]
    54 => [6, 8, 16, 30, 17, 17, 14]
    55 => [31, 1, 2, 4, 8, 8, 8]
    56 => [14, 17, 17, 14, 17, 17, 14]
    57 => [14, 17, 17, 15, 1, 2, 12]
    58 => [0, 12, 12, 0, 12, 12, 0]
    59 => [0, 12, 12, 0, 4, 4, 8]
    60 => [2, 4, 8, 16, 8, 4, 2]
    61 => [0, 0, 31, 0, 31, 0, 0]
    62 => [8, 4, 2, 1, 2, 4, 8]
    63 => [14, 17, 1, 2, 4, 0, 4]
    64 => [14, 17, 23, 21, 23, 16, 14]
    65 => [14, 17, 17, 31, 17, 17, 17]
    66 => [30, 17, 17, 30, 17, 17, 30]
    67 => [14, 17, 16, 16, 16, 17, 14]
    68 => [30, 17, 17, 17, 17, 17, 30]
    69 => [31, 16, 16, 30, 16, 16, 31]
    70 => [31, 16, 16, 30, 16, 16, 16]
    71 => [14, 17, 16, 23, 17, 17, 15]
    72 => [17, 17, 17, 31, 17, 17, 17]
    73 => [14, 4, 4, 4, 4, 4, 14]
    74 => [7, 2, 2, 2, 18, 18, 12]
    75 => [17, 18, 20, 24, 20, 18, 17]
    76 => [16, 16, 16, 16, 16, 16, 31]
    77 => [17, 27, 21, 21, 17, 17, 17]
    78 => [17, 25, 21, 19, 17, 17, 17]
    79 => [14, 17, 17, 17, 17, 17, 14]
    80 => [30, 17, 17, 30, 16, 16, 16]
    81 => [14, 17, 17, 17, 21, 18, 13]
    82 => [30, 17, 17, 30, 20, 18, 17]
    83 => [15, 16, 16, 14, 1, 1, 30]
    84 => [31, 4, 4, 4, 4, 4, 4]
    85 => [17, 17, 17, 17, 17, 17, 14]
    86 => [17, 17, 17, 17, 17, 10, 4]
    87 => [17, 17, 17, 21, 21, 21, 10]
    88 => [17, 17, 10, 4, 10, 17, 17]
    89 => [17, 17, 10, 4, 4, 4, 4]
    90 => [31, 1, 2, 4, 8, 16, 31]
    91 => [14, 8, 8, 8, 8, 8, 14]
    92 => [16, 8, 4, 2, 1, 0, 0]
    93 => [14, 2, 2, 2, 2, 2, 14]
    94 => [4, 10, 17, 0, 0, 0, 0]
    95 => [0, 0, 0, 0, 0, 0, 31]
    96 => [8, 4, 2, 0, 0, 0, 0]
    123 => [2, 4, 4, 8, 4, 4, 2]
    124 => [4, 4, 4, 0, 4, 4, 4]
    125 => [8, 4, 4, 2, 4, 4, 8]
    126 => [0, 8, 21, 2, 0, 0, 0]
    _ => [31, 17, 21, 17, 21, 17, 31]
  }
}

///|
fn SunRasterRenderer::pop_canvas_scope(
  self : SunRasterRenderer,
  canvas_scopes : Array[SunCanvasScopeKind],
  opacity_stack : Array[Double],
  expected : SunCanvasScopeKind,
) -> Unit {
  match canvas_scopes.pop() {
    Some(actual) =>
      if actual == expected {
        match actual {
          SunCanvasScopeKind::Opacity => ignore(opacity_stack.pop())
          _ => ignore(self.canvas.restore())
        }
      } else {
        canvas_scopes.push(actual)
        self.record_unsupported_command(
          sun_scope_pop_command(expected),
          "pop did not match active \{sun_scope_name(actual)} scope",
        )
      }
    None =>
      self.record_unsupported_command(
        sun_scope_pop_command(expected),
        "pop has no matching push scope",
      )
  }
}

///|
fn SunRasterRenderer::record_unsupported_command(
  self : SunRasterRenderer,
  command : String,
  reason : String,
) -> Unit {
  self.unsupported_command_count = self.unsupported_command_count + 1
  self.unsupported_command_diagnostics.push({ command, reason })
}

///|
fn sun_scope_name(scope : SunCanvasScopeKind) -> String {
  match scope {
    Clip => "clip"
    RoundedClip => "rounded-clip"
    Transform => "transform"
    Opacity => "opacity"
  }
}

///|
fn sun_scope_push_command(scope : SunCanvasScopeKind) -> String {
  match scope {
    Clip => "PushClip"
    RoundedClip => "PushRoundedClip"
    Transform => "PushTransform"
    Opacity => "PushOpacity"
  }
}

///|
fn sun_scope_pop_command(scope : SunCanvasScopeKind) -> String {
  match scope {
    Clip => "PopClip"
    RoundedClip => "PopRoundedClip"
    Transform => "PopTransform"
    Opacity => "PopOpacity"
  }
}

///|
fn sun_dim_to_int(value : Double) -> Int {
  if value != value || value <= 0.0 {
    0
  } else {
    value.ceil().to_int().max(1)
  }
}

///|
fn sun_color(color : @core.Color) -> @sun_graphics.Color {
  @sun_graphics.Color::new(
    r=sun_channel(color.r),
    g=sun_channel(color.g),
    b=sun_channel(color.b),
    a=sun_channel(color.a),
  )
}

///|
fn sun_channel(value : Double) -> Byte {
  (sun_clamp_unit(value) * 255.0 + 0.5).to_int().max(0).min(255).to_byte()
}

///|
fn sun_clamp_unit(value : Double) -> Double {
  guard value == value else { return 0.0 }
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn sun_current_opacity(opacity_stack : Array[Double]) -> Double {
  let mut opacity = 1.0
  for item in opacity_stack {
    opacity = opacity * item
  }
  opacity
}

///|
fn sun_paint(color : @core.Color, opacity : Double) -> @sun_graphics.Paint {
  @sun_graphics.Paint::new().set_color(sun_color(color)).set_opacity(opacity)
}

///|
fn sun_stroke_paint(
  color : @core.Color,
  width : Double,
  opacity : Double,
) -> @sun_graphics.Paint {
  sun_paint(color, opacity)
  .set_style(@sun_graphics.PaintStyle::Stroke)
  .set_stroke_width(width)
}

///|
fn sun_brush_paint(
  brush : @core.Brush,
  opacity : Double,
) -> @sun_graphics.Paint {
  let paint = @sun_graphics.Paint::new().set_opacity(opacity)
  match brush {
    @core.Brush::Solid(color) => paint.set_color(sun_color(color))
    @core.Brush::LinearGradient(gradient) =>
      paint
      .set_color(sun_color(gradient.start_color))
      .set_shader(
        @sun_graphics.PaintShader::linear_gradient(
          x0=gradient.start.x,
          y0=gradient.start.y,
          x1=gradient.end.x,
          y1=gradient.end.y,
          start_color=sun_color(gradient.start_color),
          end_color=sun_color(gradient.end_color),
        ),
      )
    @core.Brush::RadialGradient(gradient) =>
      paint
      .set_color(sun_color(gradient.center_color))
      .set_shader(
        @sun_graphics.PaintShader::radial_gradient(
          cx=gradient.center.x,
          cy=gradient.center.y,
          radius=gradient.radius,
          start_color=sun_color(gradient.center_color),
          end_color=sun_color(gradient.edge_color),
        ),
      )
  }
}

///|
fn sun_brush_stroke_paint(
  brush : @core.Brush,
  width : Double,
  opacity : Double,
) -> @sun_graphics.Paint {
  sun_brush_paint(brush, opacity)
  .set_style(@sun_graphics.PaintStyle::Stroke)
  .set_stroke_width(width)
}

///|
fn sun_rect(rect : @core.Rect) -> @sun_graphics.Rect {
  @sun_graphics.Rect::new(
    x=rect.origin.x,
    y=rect.origin.y,
    width=rect.size.width,
    height=rect.size.height,
  )
}

///|
fn sun_transform(transform : @core.Transform2D) -> @sun_graphics.Transform {
  @sun_graphics.Transform::affine(
    a=transform.a,
    b=transform.b,
    c=transform.c,
    d=transform.d,
    tx=transform.tx,
    ty=transform.ty,
  )
}

///|
fn sun_path(path : @core.PathSpec) -> @sun_graphics.Path {
  let out = @sun_graphics.Path::new()
  for verb in path.verbs {
    match verb {
      @core.PathVerb::MoveTo(point) => ignore(out.move_to(point.x, point.y))
      @core.PathVerb::LineTo(point) => ignore(out.line_to(point.x, point.y))
      @core.PathVerb::QuadTo(control, point) =>
        ignore(out.quad_to(control.x, control.y, point.x, point.y))
      @core.PathVerb::CubicTo(control1, control2, point) =>
        ignore(
          out.cubic_to(
            control1.x,
            control1.y,
            control2.x,
            control2.y,
            point.x,
            point.y,
          ),
        )
      @core.PathVerb::Close => ignore(out.close())
    }
  }
  out
}
