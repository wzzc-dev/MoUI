///|
/// MoUI draw-command backend and canvas view for the p5 sketch core.
///
/// The adapter is deliberately thin: it translates p5 paths, text, clips, and
/// transforms into MoUI's renderer-neutral `DrawCommand` stream, then returns
/// that stream from a `ViewNode` paint pass.

///|
pub struct MoUISurface {
  priv commands : Array[@core.DrawCommand]
  priv mut current : @p5.Matrix
  priv mut transform_pushes : Int32
  priv transform_stack : Array[(@p5.Matrix, Int32)]
  priv mut text_system : @core.TextSystem
  priv mut blend : @p5.BlendMode
}

///|
pub fn MoUISurface::new() -> MoUISurface {
  {
    commands: [],
    current: @p5.Matrix::identity(),
    transform_pushes: 0,
    transform_stack: [],
    text_system: @core.TextSystem::fallback(),
    blend: @p5.Blend,
  }
}

///|
/// Binds the text system supplied by the current layout pass.
pub fn MoUISurface::set_text_system(
  self : MoUISurface,
  text_system : @core.TextSystem,
) -> Unit {
  self.text_system = text_system
}

///|
/// Clears per-frame state. Call once before `Sketch::frame`.
pub fn MoUISurface::begin_frame(self : MoUISurface) -> Unit {
  self.commands.clear()
  self.current = @p5.Matrix::identity()
  self.transform_pushes = 0
  self.transform_stack.clear()
  self.blend = @p5.Blend
}

///|
/// Returns the commands produced by the last frame and resets the buffer.
pub fn MoUISurface::finish(self : MoUISurface) -> Array[@core.DrawCommand] {
  let output = self.commands.copy()
  self.commands.clear()
  output
}

///|
fn to_core_color(color : @p5.Color) -> @core.Color {
  @core.Color::rgba(r=color.r, g=color.g, b=color.b, a=color.a)
}

///|
fn to_core_font(font : @p5.FontSpec) -> @core.FontSpec {
  @core.FontSpec::new(
    families=@core.FontFamilyStack::new([@core.FontFamily::Name(font.family)]),
    size=font.size,
    weight=font.weight,
    style=if font.italic {
      @core.FontStyle::Italic
    } else {
      @core.FontStyle::Normal
    },
  )
}

///|
fn to_core_verbs(path : @p5.Path) -> Array[@core.PathVerb] {
  let verbs : Array[@core.PathVerb] = []
  for command in path.commands {
    match command {
      @p5.MoveTo(x, y) => verbs.push(@core.MoveTo(@core.Point::new(x~, y~)))
      @p5.LineTo(x, y) => verbs.push(@core.LineTo(@core.Point::new(x~, y~)))
      @p5.QuadTo(cx, cy, x, y) =>
        verbs.push(
          @core.QuadTo(@core.Point::new(x=cx, y=cy), @core.Point::new(x~, y~)),
        )
      @p5.CubicTo(c1x, c1y, c2x, c2y, x, y) =>
        verbs.push(
          @core.CubicTo(
            @core.Point::new(x=c1x, y=c1y),
            @core.Point::new(x=c2x, y=c2y),
            @core.Point::new(x~, y~),
          ),
        )
      @p5.Close => verbs.push(@core.Close)
    }
  }
  verbs
}

///|
fn MoUISurface::push_transform(self : MoUISurface, matrix : @p5.Matrix) -> Unit {
  let transform : @core.Transform2D = {
    a: matrix.a,
    b: matrix.b,
    c: matrix.c,
    d: matrix.d,
    tx: matrix.tx,
    ty: matrix.ty,
  }
  self.commands.push(@core.PushTransform(transform))
  self.transform_pushes = self.transform_pushes + 1
}

///|
fn MoUISurface::push_blend(self : MoUISurface) -> Unit {
  if self.blend != @p5.Blend {
    let mode = match self.blend {
      // Unreachable behind the != Blend guard; keeps the match total.
      @p5.Blend => @core.BlendMode::SourceOver
      @p5.Multiply => @core.BlendMode::Multiply
      @p5.Screen => @core.BlendMode::Screen
      @p5.Overlay => @core.BlendMode::Overlay
      @p5.Darken => @core.BlendMode::Darken
      @p5.Lighten => @core.BlendMode::Lighten
      @p5.Add => @core.BlendMode::Add
      @p5.Difference => @core.BlendMode::Difference
      @p5.Exclusion => @core.BlendMode::Exclusion
      @p5.HardLight => @core.BlendMode::HardLight
      @p5.SoftLight => @core.BlendMode::SoftLight
      @p5.Dodge => @core.BlendMode::ColorDodge
      @p5.Burn => @core.BlendMode::ColorBurn
    }
    self.commands.push(
      @core.PushLayer(@core.LayerSpec::new(blend_mode=mode, offscreen=true)),
    )
  }
}

///|
fn MoUISurface::pop_blend(self : MoUISurface) -> Unit {
  if self.blend != @p5.Blend {
    self.commands.push(@core.PopLayer)
  }
}

///|
pub impl @p5.Surface for MoUISurface with fn set_transform(self, matrix) {
  if matrix == self.current {
    return
  }
  let delta = self.current.inverse().compose(matrix)
  self.push_transform(delta)
  self.current = matrix
}

///|
pub impl @p5.Surface for MoUISurface with fn save(self) {
  self.transform_stack.push((self.current, self.transform_pushes))
  self.push_transform(@p5.Matrix::identity())
}

///|
pub impl @p5.Surface for MoUISurface with fn restore(self) {
  match self.transform_stack.pop() {
    Some((matrix, pushes)) => {
      while self.transform_pushes > pushes {
        self.commands.push(@core.PopTransform)
        self.transform_pushes = self.transform_pushes - 1
      }
      self.current = matrix
    }
    None => ()
  }
}

///|
pub impl @p5.Surface for MoUISurface with fn fill_path(self, path, color) {
  self.push_blend()
  let spec = @core.PathSpec::new(
    verbs=to_core_verbs(path),
    fill=Some(@core.Brush::solid(to_core_color(color))),
  )
  self.commands.push(@core.DrawPath(spec))
  self.pop_blend()
}

///|
fn core_stroke_cap(cap : @p5.StrokeCap) -> @core.StrokeCap {
  match cap {
    @p5.Round => @core.Round
    // p5 SQUARE is the butt cap; PROJECT extends past the endpoint.
    @p5.Square => @core.Butt
    @p5.Project => @core.Square
  }
}

///|
fn core_stroke_join(join : @p5.StrokeJoin) -> @core.StrokeJoin {
  match join {
    @p5.Miter => @core.Miter
    @p5.Bevel => @core.Bevel
    @p5.RoundJoin => @core.Round
  }
}

///|
pub impl @p5.Surface for MoUISurface with fn stroke_path(
  self,
  path,
  color,
  width,
  cap,
  join,
) {
  self.push_blend()
  let spec = @core.PathSpec::new(
    verbs=to_core_verbs(path),
    stroke=Some(@core.Brush::solid(to_core_color(color))),
    stroke_width=width,
    stroke_cap=Some(core_stroke_cap(cap)),
    stroke_join=Some(core_stroke_join(join)),
  )
  self.commands.push(@core.DrawPath(spec))
  self.pop_blend()
}

///|
pub impl @p5.Surface for MoUISurface with fn fill_rounded_rect(
  self,
  x,
  y,
  width,
  height,
  radius,
  color,
) {
  self.push_blend()
  self.commands.push(
    @core.FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x~, y~, width~, height~),
        radius~,
      ),
      to_core_color(color),
    ),
  )
  self.pop_blend()
}

///|
pub impl @p5.Surface for MoUISurface with fn stroke_rounded_rect(
  self,
  x,
  y,
  width,
  height,
  radius,
  color,
  stroke_width,
) {
  self.push_blend()
  self.commands.push(
    @core.StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x~, y~, width~, height~),
        radius~,
      ),
      to_core_color(color),
      stroke_width,
    ),
  )
  self.pop_blend()
}

///|
pub impl @p5.Surface for MoUISurface with fn fill_rect(
  self,
  x,
  y,
  width,
  height,
  color,
) {
  self.push_blend()
  self.commands.push(
    @core.FillRect(
      @core.Rect::new(x~, y~, width~, height~),
      to_core_color(color),
    ),
  )
  self.pop_blend()
}

///|
pub impl @p5.Surface for MoUISurface with fn clear_rect(self, _, _, _, _) {
  self.commands.push(@core.Clear(@core.Color::transparent()))
}

///|
pub impl @p5.Surface for MoUISurface with fn draw_image(
  self,
  image,
  x,
  y,
  width,
  height,
  opacity,
  tint,
) {
  self.push_blend()
  self.commands.push(
    @core.DrawImage(
      @core.ImageRun::new(
        p5_image_source(image, tint),
        @core.Rect::new(x~, y~, width~, height~),
        opacity~,
        fit=@core.ImageFit::Stretch,
      ),
    ),
  )
  self.pop_blend()
}

///|
pub impl @p5.Surface for MoUISurface with fn clip_path(self, path) {
  self.commands.push(
    @core.PushPathClip(@core.PathSpec::new(verbs=to_core_verbs(path))),
  )
}

///|
pub impl @p5.Surface for MoUISurface with fn clip_end(self) {
  self.commands.push(@core.PopPathClip)
}

///|
pub impl @p5.Surface for MoUISurface with fn fill_text(
  self,
  text,
  x,
  y,
  color,
  stroke,
  stroke_width,
  font,
  align_h,
  align_v,
) {
  if text == "" {
    return
  }
  let core_font = to_core_font(font)
  let layout = self.text_system.measure_text(
    @core.TextLayoutInput::new(text~, font=core_font),
  )
  let width = layout.size.width
  let height = layout.size.height
  let frame_x = match align_h {
    @p5.Left => x
    @p5.HCenter => x - width / 2.0
    @p5.Right => x - width
  }
  let frame_y = match align_v {
    @p5.Top => y
    @p5.VCenter => y - height / 2.0
    @p5.Bottom => y - height
    @p5.Baseline => y - layout.baseline
  }
  let run = @core.TextRun::new(
    text~,
    frame=@core.Rect::new(x=frame_x, y=frame_y, width~, height~),
    font=core_font,
    color=to_core_color(color),
    align=@core.TextAlign::TextStart,
    stroke_color=match stroke {
      Some(stroke_color) => Some(to_core_color(stroke_color))
      None => None
    },
    stroke_width~,
  )
  self.push_blend()
  self.commands.push(@core.DrawText(run))
  self.pop_blend()
}

///|
pub impl @p5.Surface for MoUISurface with fn measure_width(self, text, font) {
  let layout = self.text_system.measure_text(
    @core.TextLayoutInput::new(text~, font=to_core_font(font)),
  )
  layout.size.width
}

///|
pub impl @p5.Surface for MoUISurface with fn text_metrics(self, font) {
  let layout = self.text_system.measure_text(
    @core.TextLayoutInput::new(text="Hg", font=to_core_font(font)),
  )
  @p5.TextMetrics::new(
    width=layout.size.width,
    height=layout.size.height,
    ascent=layout.baseline,
    descent=layout.size.height - layout.baseline,
  )
}

///|
pub impl @p5.Surface for MoUISurface with fn set_blend_mode(self, mode) {
  self.blend = mode
}

///|
pub impl @p5.Surface for MoUISurface with fn set_smoothing(_, _) {

}

///|
/// Pointer phase in the adapter's public input surface.
#derive(Eq)
pub(all) enum PointerPhase {
  Move
  Down
  Up
  Cancel
  Exit
}

///|
/// Input sample in sketch-local coordinates, produced by the canvas view.
///
/// `Pointer` carries the phase, position, p5 button number (`0` left,
/// `1` middle, `2` right), MoUI pointer id, and normalized pressure. `Wheel`
/// carries the vertical wheel delta. `Key` carries the key, whether it went
/// down, and the printable text (if any).
#derive(Eq)
pub(all) enum CanvasInput {
  Pointer(PointerPhase, Double, Double, Int32, Int32, Double)
  Wheel(Double, Double, Double)
  Key(String, String, Bool, String?)
  TextInput(@core.TextInputEvent)
}

///|
/// Safety cap for retained history; a sketch that never clears is reset rather
/// than growing without bound.
const MAX_RETAINED_COMMANDS : Int32 = 120000

///|
/// Owns the surface and sketch pair for one canvas.
pub struct SketchView {
  priv surface : MoUISurface
  priv sketch : @p5.Sketch
  priv width : Double
  priv height : Double
  priv mut cached_commands : Array[@core.DrawCommand]
  priv mut has_cached : Bool
  priv mut press_active : Bool
  priv mut press_x : Double
  priv mut press_y : Double
  priv mut press_button : Int32
  priv mut has_last_click : Bool
  priv mut last_click_ms : Double
  priv mut last_click_x : Double
  priv mut last_click_y : Double
  priv persistent : Bool
  priv history : Array[@core.DrawCommand]
  priv mut history_epoch : Int32
  priv mut history_started : Bool
  priv mut rasterizer : CanvasRasterizer?
  priv mut pixel_buffer : @p5.Image?
  priv mut overlay_source : String?
}

///|
fn SketchView::make(
  width : Double,
  height : Double,
  persistent : Bool,
) -> SketchView {
  let surface = MoUISurface::new()
  let sketch = @p5.Sketch::new(surface as &@p5.Surface, width, height)
  {
    surface,
    sketch,
    width,
    height,
    cached_commands: [],
    has_cached: false,
    press_active: false,
    press_x: 0.0,
    press_y: 0.0,
    press_button: 0,
    has_last_click: false,
    last_click_ms: 0.0,
    last_click_x: 0.0,
    last_click_y: 0.0,
    persistent,
    history: [],
    history_epoch: 0,
    history_started: false,
    rasterizer: default_canvas_rasterizer.val,
    pixel_buffer: None,
    overlay_source: None,
  }
}

///|
/// Creates a p5-style retained canvas: draw commands accumulate across frames
/// until an opaque `background`, `clear`, or reset. This is display-list
/// persistence at the adapter layer; GUI retained-mode is unchanged.
pub fn SketchView::new(width : Double, height : Double) -> SketchView {
  SketchView::make(width, height, true)
}

///|
/// Creates a stateless canvas: every painted frame replaces the previous
/// display list (the behavior before the p5 retained layer).
pub fn SketchView::new_stateless(width : Double, height : Double) -> SketchView {
  SketchView::make(width, height, false)
}

///|
/// Binds the text system used for measurement. Normal paint passes install the
/// renderer's system automatically; offline frame capture
/// (`render_commands` without a runtime paint context) must inject the same
/// system the rasterizer's glyph shaping uses, or measured frames and drawn
/// runs disagree.
pub fn SketchView::set_text_system(
  self : SketchView,
  text_system : @core.TextSystem,
) -> Unit {
  self.surface.set_text_system(text_system)
}

///|
/// The mutable sketch behind this view.
pub fn SketchView::sketch(self : SketchView) -> @p5.Sketch {
  self.sketch
}

///|
fn p5_button(button : Int32) -> Int32 {
  // MoUI normalizes the secondary mouse button to 1; p5 numbers middle as 1
  // and right as 2.
  if button == 1 {
    2
  } else if button == 2 {
    1
  } else {
    0
  }
}

///|
fn key_code_for(key : String) -> Int32 {
  match key {
    "Enter" => 13
    "Escape" => 27
    "Backspace" => 8
    "Tab" => 9
    " " | "Space" => 32
    "Shift" => 16
    "Control" => 17
    "Alt" => 18
    "Meta" => 91
    "ArrowLeft" => 37
    "ArrowUp" => 38
    "ArrowRight" => 39
    "ArrowDown" => 40
    "Delete" => 46
    "Home" => 36
    "End" => 35
    "PageUp" => 33
    "PageDown" => 34
    _ =>
      if key.length() == 1 {
        // p5 keyCode follows the uppercase ASCII code for letters.
        key.to_upper().get_char(0).unwrap().to_int()
      } else {
        0
      }
  }
}

///|
fn SketchView::finish_primary_press(
  self : SketchView,
  x : Double,
  y : Double,
  button : Int32,
  allow_click~ : Bool,
) -> Unit {
  self.sketch.pointer_up(x, y)
  if allow_click && self.press_active && button == self.press_button {
    let dx = x - self.press_x
    let dy = y - self.press_y
    if dx * dx + dy * dy <= 25.0 {
      self.sketch.pointer_clicked(x, y)
      let now = self.sketch.millis()
      let same_spot = (x - self.last_click_x) * (x - self.last_click_x) +
        (y - self.last_click_y) * (y - self.last_click_y) <=
        25.0
      if self.has_last_click && now - self.last_click_ms <= 320.0 && same_spot {
        self.sketch.pointer_double_clicked(x, y)
        self.has_last_click = false
      } else {
        self.has_last_click = true
        self.last_click_ms = now
        self.last_click_x = x
        self.last_click_y = y
      }
    }
  }
  self.press_active = false
}

///|
/// Applies one input sample to the sketch.
///
/// Every pointer stream updates `touches` and the touch callbacks. The primary
/// stream (`id == 0`) additionally drives p5's mouse state/callbacks so a
/// mouse or first finger behaves like `mouseX`/`mousePressed`.
pub fn SketchView::handle_input(self : SketchView, input : CanvasInput) -> Unit {
  match input {
    Pointer(phase, x, y, button, id, pressure) =>
      match phase {
        Down => {
          self.sketch.touch_started_at(id, x, y, pressure~)
          if id == 0 {
            self.press_active = true
            self.press_x = x
            self.press_y = y
            self.press_button = button
            self.sketch.pointer_down(x, y, button~)
          }
        }
        Move => {
          self.sketch.touch_moved_to(id, x, y, pressure~)
          if id == 0 {
            self.sketch.pointer_move(x, y)
          }
        }
        Up =>
          if id == 0 {
            self.sketch.touch_ended_at(id)
            self.finish_primary_press(x, y, button, allow_click=true)
          } else {
            self.sketch.touch_ended_at(id)
          }
        Cancel =>
          if id == 0 {
            self.sketch.touch_ended_at(id)
            self.finish_primary_press(x, y, button, allow_click=false)
          } else {
            self.sketch.touch_ended_at(id)
          }
        Exit => ()
      }
    Wheel(x, y, delta) => {
      self.sketch.pointer_move(x, y)
      self.sketch.pointer_wheel(delta)
    }
    Key(key, code, pressed, text) =>
      if pressed {
        self.sketch.key_down(key, code~, key_code=key_code_for(key))
        match text {
          Some(value) => if value != "" { self.sketch.key_typed_input(value) }
          None => ()
        }
      } else {
        self.sketch.key_up(key, code~, key_code=key_code_for(key))
      }
    TextInput(event) =>
      match event {
        @core.InsertText(text) => self.sketch.text_input(text)
        @core.ReplaceText(_, text) => self.sketch.text_input(text)
        @core.CompositionStart => self.sketch.composition_start()
        @core.CompositionUpdate(update) =>
          self.sketch.composition_update(update.text())
        @core.CompositionEnd(text) => self.sketch.composition_end(text)
        _ => ()
      }
  }
}

///|
/// Runs one p5 frame through the surface and returns the commands to paint.
///
/// In retained mode the fresh command batch is appended to the canvas
/// history; a changed `Sketch::canvas_epoch` (opaque background/clear/reset)
/// drops the old history first. Exposed for headless tests and tools.
pub fn SketchView::render_commands(
  self : SketchView,
  now_ms : Double,
) -> Array[@core.DrawCommand] {
  self.surface.begin_frame()
  let drew = self.sketch.frame(now_ms)
  let output = if drew {
    let fresh = self.surface.finish()
    if self.persistent {
      let epoch = self.sketch.canvas_epoch()
      if !self.history_started ||
        epoch != self.history_epoch ||
        self.history.length() + fresh.length() > MAX_RETAINED_COMMANDS {
        self.history.clear()
        self.history_epoch = epoch
        self.history_started = true
      }
      self.history.append(fresh)
      self.cached_commands = self.history.copy()
      self.has_cached = true
      self.cached_commands.copy()
    } else {
      self.cached_commands = fresh.copy()
      self.has_cached = true
      self.cached_commands.copy()
    }
  } else if self.has_cached {
    self.cached_commands.copy()
  } else {
    []
  }
  self.append_canvas_overlay(output)
  output
}

///|
fn local_point(position : @core.Point, frame : @core.Rect) -> (Double, Double) {
  (position.x - frame.origin.x, position.y - frame.origin.y)
}

///|
priv struct P5Canvas {
  view : SketchView
}

///|
impl @core.ViewNode for P5Canvas with fn identity(_self) {
  @core.ViewIdentity::new(kind="P5Canvas")
}

///|
impl @core.ViewNode for P5Canvas with fn layout(self, _ctx) {
  @core.ViewLayoutResult::new(
    size=@core.Size::new(width=self.view.width, height=self.view.height),
  )
}

///|
impl @core.ViewNode for P5Canvas with fn paint(self, ctx) {
  self.view.surface.set_text_system(ctx.text_system)
  let commands = self.view.render_commands(ctx.now_ms)
  if self.view.sketch.is_looping() {
    @core.ViewPaintPlan::animating_commands(commands)
  } else {
    @core.ViewPaintPlan::commands(commands)
  }
}

///|
impl @core.ViewNode for P5Canvas with fn semantics(_self) {
  @core.ViewSemanticsInfo::container(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Group,
    label="p5 sketch canvas",
    value="",
  )
}

///|
/// Returns a canvas view that feeds drag/tap input back as `CanvasInput`.
///
/// The runtime repaints while the sketch is looping; `no_loop` still requests
/// one repaint per input sample so paused sketches stay interactive.
pub fn SketchView::view(self : SketchView) -> @facade.View[CanvasInput] {
  @core.View::from_node(P5Canvas::{ view: self, })
  .on_pointer((event, frame) => {
    let (x, y) = local_point(event.position, frame)
    if event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0 {
      Wheel(x, y, event.wheel_delta.y)
    } else {
      let phase = match event.phase {
        @core.PointerPhase::Move => Move
        @core.PointerPhase::Down => Down
        @core.PointerPhase::Up => Up
        @core.PointerPhase::Cancel => Cancel
        @core.PointerPhase::Exit => Exit
      }
      Pointer(phase, x, y, p5_button(event.button), event.id, event.pressure)
    }
  })
  .on_keyboard_input(
    key_handler=event => Key(event.key, event.code, event.pressed, event.text),
    text_input_handler=event => TextInput(event),
  )
}

///|
pub extend CanvasInput with Eq::{not_equal, equal}

///|
pub extend MoUISurface with @p5.Surface::{
  set_transform,
  save,
  restore,
  fill_path,
  stroke_path,
  fill_rect,
  fill_rounded_rect,
  stroke_rounded_rect,
  clear_rect,
  draw_image,
  clip_path,
  clip_end,
  fill_text,
  measure_width,
  text_metrics,
  set_blend_mode,
  set_smoothing,
}

///|
pub extend PointerPhase with Eq::{not_equal, equal}
