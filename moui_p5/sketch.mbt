///|
/// The p5 sketch object.
///
/// This is the MoonBit equivalent of p5.js *instance mode*: every drawing and
/// state function is a method on `Sketch`, and the lifecycle callbacks receive
/// the same object. The drawing backend is a `Surface`, so the same sketch can
/// run on MoUI's draw-command stream, a headless recorder, or a future backend.

///|
#derive(Eq)
pub(all) enum AngleMode {
  Radians
  Degrees
}

///|
priv struct StyleState {
  fill : Color?
  stroke : Color?
  stroke_weight : Double
  stroke_cap : StrokeCap
  stroke_join : StrokeJoin
  rect_mode : ShapeMode
  ellipse_mode : ShapeMode
  angle_mode : AngleMode
  color_mode : ColorMode
  color_ranges : ColorRanges
  matrix : Matrix
  text_font : FontSpec
  text_align_h : HAlign
  text_align_v : VAlign
  text_wrap : TextWrap
  spline_tightness : Double
  tint : Color?
  blend : BlendMode
}

///|
fn StyleState::new() -> StyleState {
  {
    fill: Some(Color::rgb(255, 255, 255)),
    stroke: Some(Color::rgb(0, 0, 0)),
    stroke_weight: 1.0,
    stroke_cap: Round,
    stroke_join: Miter,
    rect_mode: Corner,
    ellipse_mode: Center,
    angle_mode: Radians,
    color_mode: RGB,
    color_ranges: default_color_ranges(RGB),
    matrix: Matrix::identity(),
    text_font: FontSpec::new(),
    text_align_h: Left,
    text_align_v: Baseline,
    text_wrap: Word,
    spline_tightness: 0.0,
    tint: None,
    blend: Blend,
  }
}

///|
/// A p5 sketch.
pub struct Sketch {
  mut width : Double
  mut height : Double
  mut frame_count : Int32
  mut delta_time : Double
  mut elapsed_ms : Double
  mut mouse_x : Double
  mut mouse_y : Double
  mut pmouse_x : Double
  mut pmouse_y : Double
  mut moved_x : Double
  mut moved_y : Double
  mut mouse_is_pressed : Bool
  mut mouse_button : Int32
  touches : Array[Touch]
  mut composing : Bool
  mut composition_text : String
  mut last_input_text : String
  mut key : String
  mut code : String
  mut key_is_pressed : Bool
  mut key_code : Int32
  mut focused : Bool
  priv surface : &Surface
  priv mut style : StyleState
  priv stack : Array[StyleState]
  priv mut canvas_epoch : Int32
  priv mut graphics : RecordingSurface?
  priv mut shape : Path?
  priv spline_points : Array[(Double, Double)]
  priv mut next_vertex_moves : Bool
  priv mut rng : Random
  priv mut noise : Noise
  priv callbacks : SketchCallbacks
  priv mut looping : Bool
  priv mut target_frame_rate : Double
  priv mut redraw_frames : Int32
  priv mut started : Bool
  priv mut clock_start : Double
  priv mut last_ms : Double
  priv mut last_draw_ms : Double
  priv mut last_frame_mouse_x : Double
  priv mut last_frame_mouse_y : Double
  priv mut image_fetcher : ImageFetcher?
  priv mut file_ports : FilePorts
  priv keys_down : Map[String, Bool]
}

///|
pub fn Sketch::new(
  surface : &Surface,
  width : Double,
  height : Double,
  file_ports~ : FilePorts = default_file_ports(),
) -> Sketch {
  {
    width,
    height,
    frame_count: 0,
    delta_time: 0.0,
    elapsed_ms: 0.0,
    mouse_x: 0.0,
    mouse_y: 0.0,
    pmouse_x: 0.0,
    pmouse_y: 0.0,
    moved_x: 0.0,
    moved_y: 0.0,
    mouse_is_pressed: false,
    mouse_button: 0,
    touches: [],
    composing: false,
    composition_text: "",
    last_input_text: "",
    key: "",
    code: "",
    key_is_pressed: false,
    key_code: 0,
    focused: true,
    surface,
    style: StyleState::new(),
    stack: [],
    canvas_epoch: 0,
    graphics: None,
    shape: None,
    spline_points: [],
    next_vertex_moves: false,
    rng: Random::new(0.0),
    noise: Noise::new(0.0),
    callbacks: {
      setup: no_setup,
      draw: no_draw,
      mouse_pressed: no_setup,
      mouse_released: no_setup,
      mouse_clicked: no_setup,
      double_clicked: no_setup,
      mouse_moved: no_setup,
      mouse_dragged: no_setup,
      mouse_wheel: (_, _) => (),
      key_pressed: no_setup,
      key_released: no_setup,
      key_typed: no_setup,
      touch_started: no_setup,
      touch_moved: no_setup,
      touch_ended: no_setup,
      text_input: (_, _) => (),
      composition_start: no_setup,
      composition_update: (_, _) => (),
      composition_end: (_, _) => (),
    },
    looping: true,
    target_frame_rate: 60.0,
    redraw_frames: 0,
    started: false,
    clock_start: 0.0,
    last_ms: 0.0,
    last_draw_ms: 0.0,
    last_frame_mouse_x: 0.0,
    last_frame_mouse_y: 0.0,
    image_fetcher: default_image_fetcher.val,
    file_ports,
    keys_down: {},
  }
}

///|
/// Replaces the host byte I/O used by `try_load_image` and `save_image` on
/// this sketch. `create_graphics` copies the current ports to the child
/// sketch; hosts usually install ports once with `set_default_file_ports`
/// instead of calling this per sketch.
pub fn Sketch::set_file_ports(self : Sketch, ports : FilePorts) -> Unit {
  self.file_ports = ports
}

///|
/// The byte I/O this sketch routes image loading and saving through.
pub fn Sketch::file_ports(self : Sketch) -> FilePorts {
  self.file_ports
}

///|
/// Resets the lifecycle (the next frame runs `setup` again) and restores the
/// default drawing state.
pub fn Sketch::reset_sketch(self : Sketch) -> Unit {
  self.frame_count = 0
  self.delta_time = 0.0
  self.last_draw_ms = 0.0
  self.last_frame_mouse_x = 0.0
  self.last_frame_mouse_y = 0.0
  self.elapsed_ms = 0.0
  self.started = false
  self.redraw_frames = 0
  self.style = StyleState::new()
  self.stack.clear()
  self.touches.clear()
  self.composing = false
  self.composition_text = ""
  self.last_input_text = ""
  self.canvas_epoch = self.canvas_epoch + 1
  match self.graphics {
    Some(graphics) => graphics.clear()
    None => ()
  }
  self.shape = None
  self.spline_points.clear()
  self.next_vertex_moves = false
  self.rng = Random::new(0.0)
  self.noise = Noise::new(0.0)
}

///|
/// Advances and draws one frame. `now_ms` is the host clock in milliseconds.
///
/// The first call runs `setup` and then `draw`. When the host repaints without
/// advancing its clock, the frame counter is not advanced and `draw` only runs
/// if a redraw was requested (so input remains responsive without double
/// stepping time-based animation).
pub fn Sketch::frame(self : Sketch, now_ms : Double) -> Bool {
  let first = !self.started
  if first {
    self.started = true
    self.clock_start = now_ms
    self.elapsed_ms = 0.0
    (self.callbacks.setup)(self)
  }
  let new_tick = first || now_ms > self.last_ms
  if new_tick {
    self.elapsed_ms = now_ms - self.clock_start
    self.last_ms = now_ms
  }
  let should_draw = first ||
    (self.looping && new_tick) ||
    self.redraw_frames > 0
  if should_draw {
    self.delta_time = if first { 0.0 } else { now_ms - self.last_draw_ms }
    self.last_draw_ms = now_ms
    self.frame_count = self.frame_count + 1
    self.pmouse_x = self.last_frame_mouse_x
    self.pmouse_y = self.last_frame_mouse_y
    (self.callbacks.draw)(self)
    self.last_frame_mouse_x = self.mouse_x
    self.last_frame_mouse_y = self.mouse_y
    if self.redraw_frames > 0 {
      self.redraw_frames = self.redraw_frames - 1
    }
  }
  should_draw
}

///|
pub fn Sketch::request_redraw(self : Sketch, frames~ : Int32 = 1) -> Unit {
  self.redraw_frames = self.redraw_frames.max(frames)
}

///|
pub fn Sketch::no_loop(self : Sketch) -> Unit {
  self.looping = false
}

///|
pub fn Sketch::loop_(self : Sketch) -> Unit {
  self.looping = true
}

///|
pub fn Sketch::is_looping(self : Sketch) -> Bool {
  self.looping
}

///|
pub fn Sketch::redraw(self : Sketch, frames~ : Int32 = 1) -> Unit {
  self.request_redraw(frames~)
}

///|
pub fn Sketch::frame_rate(self : Sketch, value : Double) -> Unit {
  if value > 0.0 {
    self.target_frame_rate = value
  }
}

///|
pub fn Sketch::get_frame_rate(self : Sketch) -> Double {
  self.target_frame_rate
}

///|
pub fn Sketch::millis(self : Sketch) -> Double {
  self.elapsed_ms
}

///|
pub fn Sketch::resize_canvas(
  self : Sketch,
  width : Double,
  height : Double,
) -> Unit {
  self.width = width
  self.height = height
}

// ==== style state ====

///|
pub fn[C : ColorArg] Sketch::fill(self : Sketch, color : C) -> Unit {
  self.style = {
    ..self.style,
    fill: Some(color.to_color(self.style.color_mode, self.style.color_ranges)),
  }
}

///|
pub fn Sketch::no_fill(self : Sketch) -> Unit {
  self.style = { ..self.style, fill: None, }
}

///|
pub fn[C : ColorArg] Sketch::stroke(self : Sketch, color : C) -> Unit {
  self.style = {
    ..self.style,
    stroke: Some(color.to_color(self.style.color_mode, self.style.color_ranges)),
  }
}

///|
pub fn Sketch::no_stroke(self : Sketch) -> Unit {
  self.style = { ..self.style, stroke: None, }
}

///|
/// Multiplies subsequent image draws by `color` (p5 `tint`).
pub fn[C : ColorArg] Sketch::tint(self : Sketch, color : C) -> Unit {
  self.style = {
    ..self.style,
    tint: Some(color.to_color(self.style.color_mode, self.style.color_ranges)),
  }
}

///|
pub fn Sketch::no_tint(self : Sketch) -> Unit {
  self.style = { ..self.style, tint: None, }
}

///|
pub fn Sketch::stroke_weight(self : Sketch, weight : Double) -> Unit {
  self.style = { ..self.style, stroke_weight: weight.max(0.0), }
}

///|
pub fn Sketch::stroke_cap(self : Sketch, cap : StrokeCap) -> Unit {
  self.style = { ..self.style, stroke_cap: cap, }
}

///|
pub fn Sketch::stroke_join(self : Sketch, join : StrokeJoin) -> Unit {
  self.style = { ..self.style, stroke_join: join, }
}

///|
pub fn[C : ColorArg] Sketch::background(self : Sketch, color : C) -> Unit {
  let resolved = color.to_color(self.style.color_mode, self.style.color_ranges)
  // p5's background is canvas-space, not affected by the current transform.
  // An opaque background replaces the retained canvas; an alpha background
  // blends over it, so only the opaque case starts a new canvas epoch.
  if resolved.a >= 0.999 {
    self.canvas_epoch = self.canvas_epoch + 1
  }
  self.surface.set_transform(Matrix::identity())
  self.surface.fill_rect(0.0, 0.0, self.width, self.height, resolved)
}

///|
pub fn Sketch::clear(self : Sketch) -> Unit {
  self.canvas_epoch = self.canvas_epoch + 1
  self.surface.set_transform(Matrix::identity())
  self.surface.clear_rect(0.0, 0.0, self.width, self.height)
}

///|
pub fn Sketch::push(self : Sketch) -> Unit {
  self.stack.push(self.style)
  self.surface.save()
}

///|
pub fn Sketch::pop(self : Sketch) -> Unit {
  match self.stack.pop() {
    Some(style) => {
      self.style = style
      self.surface.restore()
    }
    None => ()
  }
}

///|
pub fn Sketch::rect_mode(self : Sketch, mode : ShapeMode) -> Unit {
  self.style = { ..self.style, rect_mode: mode, }
}

///|
pub fn Sketch::ellipse_mode(self : Sketch, mode : ShapeMode) -> Unit {
  self.style = { ..self.style, ellipse_mode: mode, }
}

///|
pub fn Sketch::angle_mode(self : Sketch, mode : AngleMode) -> Unit {
  self.style = { ..self.style, angle_mode: mode, }
}

///|
pub fn Sketch::get_angle_mode(self : Sketch) -> AngleMode {
  self.style.angle_mode
}

///|
pub fn Sketch::color_mode(self : Sketch, mode : ColorMode) -> Unit {
  self.style = {
    ..self.style,
    color_mode: mode,
    color_ranges: default_color_ranges(mode),
  }
}

///|
pub fn Sketch::color_mode_max(
  self : Sketch,
  mode : ColorMode,
  maximum : Double,
) -> Unit {
  self.style = {
    ..self.style,
    color_mode: mode,
    color_ranges: ColorRanges::uniform(mode, maximum),
  }
}

///|
pub fn Sketch::color_mode_maxes(
  self : Sketch,
  mode : ColorMode,
  c0 : Double,
  c1 : Double,
  c2 : Double,
  alpha~ : Double = 255.0,
) -> Unit {
  self.style = {
    ..self.style,
    color_mode: mode,
    color_ranges: ColorRanges::new(c0, c1, c2, alpha),
  }
}

///|
pub fn Sketch::get_color_mode(self : Sketch) -> ColorMode {
  self.style.color_mode
}

///|
pub fn Sketch::blend_mode(self : Sketch, mode : BlendMode) -> Unit {
  self.style = { ..self.style, blend: mode, }
  self.surface.set_blend_mode(mode)
}

///|
pub fn Sketch::smooth(self : Sketch) -> Unit {
  self.surface.set_smoothing(true)
}

///|
pub fn Sketch::no_smooth(self : Sketch) -> Unit {
  self.surface.set_smoothing(false)
}

///|
pub fn[C : ColorArg] Sketch::color(self : Sketch, color : C) -> Color {
  color.to_color(self.style.color_mode, self.style.color_ranges)
}

///|
pub fn Sketch::get_fill(self : Sketch) -> Color? {
  self.style.fill
}

///|
pub fn Sketch::get_stroke(self : Sketch) -> Color? {
  self.style.stroke
}

// ==== transforms ====

///|
pub fn Sketch::translate(self : Sketch, x : Double, y : Double) -> Unit {
  self.style = {
    ..self.style,
    matrix: self.style.matrix.compose(Matrix::translation(x, y)),
  }
}

///|
fn Sketch::angle_radians(self : Sketch, angle : Double) -> Double {
  match self.style.angle_mode {
    Radians => angle
    Degrees => radians(angle)
  }
}

///|
pub fn Sketch::rotate(self : Sketch, angle : Double) -> Unit {
  self.style = {
    ..self.style,
    matrix: self.style.matrix.compose(
      Matrix::rotation(self.angle_radians(angle)),
    ),
  }
}

///|
pub fn Sketch::scale(self : Sketch, x : Double, y~ : Double = x) -> Unit {
  self.style = {
    ..self.style,
    matrix: self.style.matrix.compose(Matrix::scaling(x, y)),
  }
}

///|
pub fn Sketch::shear_x(self : Sketch, angle : Double) -> Unit {
  self.style = {
    ..self.style,
    matrix: self.style.matrix.compose(
      Matrix::shear(@cmath.tan(self.angle_radians(angle)), 0.0),
    ),
  }
}

///|
pub fn Sketch::shear_y(self : Sketch, angle : Double) -> Unit {
  self.style = {
    ..self.style,
    matrix: self.style.matrix.compose(
      Matrix::shear(0.0, @cmath.tan(self.angle_radians(angle))),
    ),
  }
}

///|
pub fn Sketch::apply_matrix(
  self : Sketch,
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> Unit {
  self.style = {
    ..self.style,
    matrix: self.style.matrix.compose({ a, b, c, d, tx: e, ty: f, }),
  }
}

///|
pub fn Sketch::reset_matrix(self : Sketch) -> Unit {
  self.style = { ..self.style, matrix: Matrix::identity(), }
}

///|
pub fn Sketch::get_matrix(self : Sketch) -> Matrix {
  self.style.matrix
}

///|
/// Monotonic counter bumped when the canvas is fully replaced
/// (`background` with opaque alpha, `clear`, or reset). Retained surfaces use
/// it to drop stale display-list history.
pub fn Sketch::canvas_epoch(self : Sketch) -> Int32 {
  self.canvas_epoch
}

// ==== primitive drawing ====

///|
fn Sketch::draw_path(
  self : Sketch,
  path : Path,
  fill : Color?,
  stroke : Color?,
  weight : Double,
) -> Unit {
  self.surface.set_transform(self.style.matrix)
  self.surface.set_blend_mode(self.style.blend)
  match fill {
    Some(color) => self.surface.fill_path(path, color)
    None => ()
  }
  match stroke {
    Some(color) =>
      self.surface.stroke_path(
        path,
        color,
        weight,
        self.style.stroke_cap,
        self.style.stroke_join,
      )
    None => ()
  }
}

///|
fn Sketch::draw_current(self : Sketch, path : Path) -> Unit {
  self.draw_path(
    path,
    self.style.fill,
    self.style.stroke,
    self.style.stroke_weight,
  )
}

///|
pub fn Sketch::point(self : Sketch, x : Double, y : Double) -> Unit {
  let color = match self.style.stroke {
    Some(color) => Some(color)
    None => self.style.fill
  }
  match color {
    Some(color) => {
      let radius = self.style.stroke_weight.max(1.0) / 2.0
      let path = Path::new()
      path.ellipse_at(x, y, radius, radius)
      self.surface.set_transform(self.style.matrix)
      self.surface.fill_path(path, color)
    }
    None => ()
  }
}

///|
pub fn Sketch::line(
  self : Sketch,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Unit {
  match self.style.stroke {
    Some(color) => {
      let path = Path::new()
      path.move_to(x1, y1)
      path.line_to(x2, y2)
      self.surface.set_transform(self.style.matrix)
      self.surface.stroke_path(
        path,
        color,
        self.style.stroke_weight,
        self.style.stroke_cap,
        self.style.stroke_join,
      )
    }
    None => ()
  }
}

///|
fn Sketch::rect_frame(
  self : Sketch,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double) {
  match self.style.rect_mode {
    Corner => (x, y, width, height)
    Corners => (x, y, width - x, height - y)
    Center => (x - width / 2.0, y - height / 2.0, width, height)
    Radius => (x - width, y - height, width * 2.0, height * 2.0)
  }
}

///|
pub fn Sketch::rect(
  self : Sketch,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  tl~ : Double = 0.0,
  tr~ : Double = 0.0,
  br~ : Double = 0.0,
  bl~ : Double = 0.0,
) -> Unit {
  let (x, y, width, height) = self.rect_frame(x, y, width, height)
  // Uniform positive corner radius is exactly MoUI's rounded-rect primitive:
  // SDF quads on the web backend and Skia rounded rects natively, instead of a
  // tessellated path. Circles/pills land here.
  if tl > 0.0 && tl == tr && tr == br && br == bl {
    self.draw_rounded_rect(x, y, width, height, tl)
    return
  }
  let path = Path::new()
  if tl == 0.0 && tr == 0.0 && br == 0.0 && bl == 0.0 {
    path.rect_at(x, y, width, height)
  } else {
    path.rounded_rect_at(x, y, width, height, tl, tr, br, bl)
  }
  self.draw_current(path)
}

///|
fn Sketch::draw_rounded_rect(
  self : Sketch,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
) -> Unit {
  self.surface.set_transform(self.style.matrix)
  self.surface.set_blend_mode(self.style.blend)
  match self.style.fill {
    Some(color) =>
      self.surface.fill_rounded_rect(x, y, width, height, radius, color)
    None => ()
  }
  match self.style.stroke {
    Some(color) =>
      self.surface.stroke_rounded_rect(
        x,
        y,
        width,
        height,
        radius,
        color,
        self.style.stroke_weight,
      )
    None => ()
  }
}

///|
pub fn Sketch::square(
  self : Sketch,
  x : Double,
  y : Double,
  size : Double,
  tl~ : Double = 0.0,
  tr~ : Double = 0.0,
  br~ : Double = 0.0,
  bl~ : Double = 0.0,
) -> Unit {
  self.rect(x, y, size, size, tl~, tr~, br~, bl~)
}

///|
fn Sketch::ellipse_frame(
  self : Sketch,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double) {
  match self.style.ellipse_mode {
    Corner => (x + width / 2.0, y + height / 2.0, width / 2.0, height / 2.0)
    Corners =>
      (
        (x + width) / 2.0,
        (y + height) / 2.0,
        (width - x).abs() / 2.0,
        (height - y).abs() / 2.0,
      )
    Center => (x, y, width / 2.0, height / 2.0)
    Radius => (x, y, width, height)
  }
}

///|
pub fn Sketch::ellipse(
  self : Sketch,
  x : Double,
  y : Double,
  width : Double,
  height~ : Double = width,
) -> Unit {
  let (cx, cy, rx, ry) = self.ellipse_frame(x, y, width, height)
  // A true circle is the uniform-radius rounded-rect primitive; only real
  // ellipses need the path route.
  if rx > 0.0 && (rx - ry).abs() <= 1.0e-9 {
    self.draw_rounded_rect(cx - rx, cy - ry, rx * 2.0, ry * 2.0, rx)
    return
  }
  let path = Path::new()
  path.ellipse_at(cx, cy, rx, ry)
  self.draw_current(path)
}

///|
pub fn Sketch::circle(
  self : Sketch,
  x : Double,
  y : Double,
  diameter : Double,
) -> Unit {
  self.ellipse(x, y, diameter)
}

///|
pub fn Sketch::arc(
  self : Sketch,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  start : Double,
  stop : Double,
  mode~ : ArcMode = Open,
) -> Unit {
  let (cx, cy, rx, ry) = self.ellipse_frame(x, y, width, height)
  let path = Path::new()
  path.arc_at(
    cx,
    cy,
    rx,
    ry,
    self.angle_radians(start),
    self.angle_radians(stop),
    mode,
  )
  self.draw_current(path)
}

///|
pub fn Sketch::triangle(
  self : Sketch,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  let path = Path::new()
  path.polygon([(x1, y1), (x2, y2), (x3, y3)])
  self.draw_current(path)
}

///|
pub fn Sketch::quad(
  self : Sketch,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  x4 : Double,
  y4 : Double,
) -> Unit {
  let path = Path::new()
  path.polygon([(x1, y1), (x2, y2), (x3, y3), (x4, y4)])
  self.draw_current(path)
}

///|
pub fn Sketch::bezier(
  self : Sketch,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  x4 : Double,
  y4 : Double,
) -> Unit {
  let path = Path::new()
  path.bezier_at(x1, y1, x2, y2, x3, y3, x4, y4)
  self.draw_current(path)
}

///|
pub fn Sketch::curve(
  self : Sketch,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  x4 : Double,
  y4 : Double,
) -> Unit {
  let path = Path::new()
  let scale = (1.0 - self.style.spline_tightness) / 6.0
  path.move_to(x2, y2)
  path.cubic_to(
    x2 + (x3 - x1) * scale,
    y2 + (y3 - y1) * scale,
    x3 + (x2 - x4) * scale,
    y3 + (y2 - y4) * scale,
    x3,
    y3,
  )
  self.draw_current(path)
}

// ==== custom shapes ====

///|
pub fn Sketch::begin_shape(self : Sketch) -> Unit {
  self.shape = Some(Path::new())
  self.spline_points.clear()
  self.next_vertex_moves = true
}

///|
/// Starts a new subpath inside the current shape. The next vertex starts with
/// a `MoveTo`, so independent contours can be filled with one `end_shape`.
pub fn Sketch::begin_contour(self : Sketch) -> Unit {
  if self.shape is Some(_) {
    self.flush_spline()
    self.next_vertex_moves = true
  }
}

///|
/// Ends the current subpath. `close=true` appends `Close`; the next contour
/// starts with a fresh `MoveTo` either way.
pub fn Sketch::end_contour(self : Sketch, close~ : Bool = false) -> Unit {
  self.flush_spline()
  match self.shape {
    Some(path) => {
      if close {
        path.close()
      }
      self.next_vertex_moves = true
    }
    None => ()
  }
}

///|
/// Converts buffered spline vertices into cubic Bézier segments.
///
/// The first and last samples are control points, matching p5's
/// `curveVertex`/`splineVertex` convention: `p0 … pn-1` emits segments
/// `p1→p2 … pn-3→pn-2`. `spline_tightness` 0 is Catmull-Rom.
fn Sketch::flush_spline(self : Sketch) -> Unit {
  let points = self.spline_points
  let count = points.length()
  match self.shape {
    Some(path) => {
      let mut drew = false
      if count >= 4 {
        if self.next_vertex_moves || path.is_empty_path() {
          path.move_to(points[1].0, points[1].1)
        }
        let scale = (1.0 - self.style.spline_tightness) / 6.0
        for index in 1..<(count - 2) {
          let p0 = points[index - 1]
          let p1 = points[index]
          let p2 = points[index + 1]
          let p3 = points[index + 2]
          path.cubic_to(
            p1.0 + (p2.0 - p0.0) * scale,
            p1.1 + (p2.1 - p0.1) * scale,
            p2.0 + (p1.0 - p3.0) * scale,
            p2.1 + (p1.1 - p3.1) * scale,
            p2.0,
            p2.1,
          )
          drew = true
        }
        if drew {
          self.next_vertex_moves = false
        }
      }
      points.clear()
    }
    None => points.clear()
  }
}

///|
pub fn Sketch::vertex(self : Sketch, x : Double, y : Double) -> Unit {
  self.flush_spline()
  match self.shape {
    Some(path) =>
      if self.next_vertex_moves || path.is_empty_path() {
        path.move_to(x, y)
        self.next_vertex_moves = false
      } else {
        path.line_to(x, y)
      }
    None => ()
  }
}

///|
pub fn Sketch::quadratic_vertex(
  self : Sketch,
  cx : Double,
  cy : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.flush_spline()
  match self.shape {
    Some(path) => path.quad_to(cx, cy, x, y)
    None => ()
  }
}

///|
/// Adds one cubic Bézier segment to the current shape.
pub fn Sketch::bezier_vertex(
  self : Sketch,
  c1x : Double,
  c1y : Double,
  c2x : Double,
  c2y : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.flush_spline()
  match self.shape {
    Some(path) => path.cubic_to(c1x, c1y, c2x, c2y, x, y)
    None => ()
  }
}

///|
/// Buffers a Catmull-Rom spline sample. Call `end_shape`/`end_contour` to
/// flush; the first and last samples act as control points.
pub fn Sketch::spline_vertex(self : Sketch, x : Double, y : Double) -> Unit {
  match self.shape {
    Some(_) => self.spline_points.push((x, y))
    None => ()
  }
}

///|
/// Alias for `spline_vertex`, matching p5's `curveVertex`.
pub fn Sketch::curve_vertex(self : Sketch, x : Double, y : Double) -> Unit {
  self.spline_vertex(x, y)
}

///|
/// Sets the Catmull-Rom tightness used by `spline_vertex`/`curve_vertex`
/// (0 = Catmull-Rom).
pub fn Sketch::spline_tightness(self : Sketch, tightness : Double) -> Unit {
  self.style = { ..self.style, spline_tightness: tightness, }
}

///|
pub fn Sketch::curve_tightness(self : Sketch, tightness : Double) -> Unit {
  self.style = { ..self.style, spline_tightness: tightness, }
}

///|
pub fn Sketch::end_shape(self : Sketch, close~ : Bool = false) -> Unit {
  self.flush_spline()
  match self.shape {
    Some(path) => {
      if close {
        path.close()
      }
      self.draw_current(path)
      self.shape = None
      self.next_vertex_moves = false
      self.spline_points.clear()
    }
    None => ()
  }
}

///|
/// Applies a rectangular clip to everything drawn until `clip_path_end`.
///
/// The draw-command protocol exposes rectangular clipping; a non-rectangular
/// clip path is conservatively clipped to its bounding box.
pub fn Sketch::clip_path_begin(self : Sketch, path : Path) -> Unit {
  self.surface.set_transform(self.style.matrix)
  self.surface.clip_path(path)
}

///|
pub fn Sketch::clip_path_end(self : Sketch) -> Unit {
  self.surface.clip_end()
}

///|
/// Scoped clip helper: uses `path` as the clip region for `body`.
pub fn Sketch::clip(
  self : Sketch,
  path : Path,
  body : (Sketch) -> Unit,
) -> Unit {
  self.surface.clip_path(path)
  body(self)
  self.surface.clip_end()
}

///|
pub extend AngleMode with Eq::{not_equal, equal}
