///|
/// Typography, math, random/noise, and input methods on `Sketch`.

// ==== typography ====

///|
pub fn Sketch::text_size(self : Sketch, size : Double) -> Unit {
  self.style = {
    ..self.style,
    text_font: { ..self.style.text_font, size, leading: size * 1.2, },
  }
}

///|
pub fn Sketch::get_text_size(self : Sketch) -> Double {
  self.style.text_font.size
}

///|
pub fn Sketch::text_font(
  self : Sketch,
  family : String,
  size~ : Double = -1.0,
) -> Unit {
  let size = if size > 0.0 { size } else { self.style.text_font.size }
  self.style = {
    ..self.style,
    text_font: {
      ..self.style.text_font,
      family,
      size,
      leading: self.style.text_font.leading,
    },
  }
}

///|
pub fn Sketch::text_style(self : Sketch, style : TextStyle) -> Unit {
  let (weight, italic) = match style {
    Normal => (400, false)
    Italic => (400, true)
    Bold => (700, false)
    BoldItalic => (700, true)
  }
  self.style = {
    ..self.style,
    text_font: { ..self.style.text_font, weight, italic, },
  }
}

///|
pub fn Sketch::text_leading(self : Sketch, leading : Double) -> Unit {
  self.style = {
    ..self.style,
    text_font: { ..self.style.text_font, leading, },
  }
}

///|
pub fn Sketch::get_text_leading(self : Sketch) -> Double {
  self.style.text_font.leading
}

///|
pub fn Sketch::text_align(
  self : Sketch,
  horizontal : HAlign,
  vertical~ : VAlign = Baseline,
) -> Unit {
  self.style = {
    ..self.style,
    text_align_h: horizontal,
    text_align_v: vertical,
  }
}

///|
pub fn Sketch::text_wrap(self : Sketch, mode : TextWrap) -> Unit {
  self.style = { ..self.style, text_wrap: mode, }
}

///|
fn Sketch::measure_line(
  self : Sketch,
  line : String,
  font : FontSpec,
) -> Double {
  self.surface.measure_width(line, font)
}

///|
fn Sketch::wrap_words(
  self : Sketch,
  line : String,
  maximum : Double,
  font : FontSpec,
) -> Array[String] {
  let words = line.split(" ").map(word => word.to_owned()).collect()
  let output : Array[String] = []
  let mut current = ""
  for word in words {
    let candidate = if current == "" { word } else { current + " " + word }
    if current != "" && self.measure_line(candidate, font) > maximum {
      output.push(current)
      current = word
    } else {
      current = candidate
    }
  }
  if current != "" {
    output.push(current)
  }
  if output.is_empty() {
    output.push("")
  }
  output
}

///|
fn Sketch::wrap_chars(
  self : Sketch,
  line : String,
  maximum : Double,
  font : FontSpec,
) -> Array[String] {
  let output : Array[String] = []
  let mut current = ""
  for char in line {
    let candidate = current + char.to_string()
    if current != "" && self.measure_line(candidate, font) > maximum {
      output.push(current)
      current = char.to_string()
    } else {
      current = candidate
    }
  }
  if current != "" {
    output.push(current)
  }
  if output.is_empty() {
    output.push("")
  }
  output
}

///|
/// Draws text. `x`/`y` are interpreted through `text_align` and
/// `text_size`/`text_leading`. Newlines are always honored; `max_width`
/// additionally wraps by words (or characters under `TextWrap::Char`).
pub fn Sketch::text(
  self : Sketch,
  content : String,
  x : Double,
  y : Double,
  max_width~ : Double = 0.0,
  max_height~ : Double = 0.0,
) -> Unit {
  let font = self.style.text_font
  let stroke = self.style.stroke
  let color = match (self.style.fill, stroke) {
    (Some(color), _) => color
    // Stroke-only text: transparent fill makes the fill pass a no-op, so the
    // glyph outline is the only ink (p5's noFill + stroke contract). Backends
    // without a text-stroke pass render nothing, which is their honest
    // degradation.
    (None, Some(_)) => Color::transparent()
    (None, None) => return
  }
  let lines : Array[String] = []
  for raw_view in content.split("\n") {
    let raw = raw_view.to_owned()
    if max_width > 0.0 && self.measure_line(raw, font) > max_width {
      let wrapped = match self.style.text_wrap {
        Word => self.wrap_words(raw, max_width, font)
        Char => self.wrap_chars(raw, max_width, font)
      }
      lines.append(wrapped)
    } else {
      lines.push(raw)
    }
  }
  if lines.is_empty() {
    lines.push("")
  }
  let line_height = if font.leading > 0.0 {
    font.leading
  } else {
    font.size * 1.2
  }
  if max_height > 0.0 {
    let allowed = (max_height / line_height).floor().to_int().max(1)
    if lines.length() > allowed {
      lines.truncate(allowed)
    }
  }
  let total_height = line_height * lines.length().to_double()
  let metrics = self.surface.text_metrics(font)
  let top = match self.style.text_align_v {
    Top => y
    VCenter => y - total_height / 2.0
    Bottom => y - total_height
    Baseline => y - metrics.ascent
  }
  for index, line in lines {
    let baseline = top + line_height * index.to_double() + metrics.ascent
    self.surface.set_transform(self.style.matrix)
    self.surface.fill_text(
      line,
      x,
      baseline,
      color,
      stroke,
      self.style.stroke_weight,
      font,
      self.style.text_align_h,
      Baseline,
    )
  }
}

///|
pub fn Sketch::text_width(self : Sketch, content : String) -> Double {
  self.measure_line(content, self.style.text_font)
}

///|
pub fn Sketch::text_ascent(self : Sketch) -> Double {
  self.surface.text_metrics(self.style.text_font).ascent
}

///|
pub fn Sketch::text_descent(self : Sketch) -> Double {
  self.surface.text_metrics(self.style.text_font).descent
}

// ==== math ====

///|
fn Sketch::to_radians(self : Sketch, angle : Double) -> Double {
  match self.style.angle_mode {
    Radians => angle
    Degrees => radians(angle)
  }
}

///|
fn Sketch::from_radians(self : Sketch, angle : Double) -> Double {
  match self.style.angle_mode {
    Radians => angle
    Degrees => degrees(angle)
  }
}

///|
pub fn Sketch::sin(self : Sketch, angle : Double) -> Double {
  @cmath.sin(self.to_radians(angle))
}

///|
pub fn Sketch::cos(self : Sketch, angle : Double) -> Double {
  @cmath.cos(self.to_radians(angle))
}

///|
pub fn Sketch::tan(self : Sketch, angle : Double) -> Double {
  @cmath.tan(self.to_radians(angle))
}

///|
pub fn Sketch::asin(self : Sketch, value : Double) -> Double {
  self.from_radians(@cmath.asin(value))
}

///|
pub fn Sketch::acos(self : Sketch, value : Double) -> Double {
  self.from_radians(@cmath.acos(value))
}

///|
pub fn Sketch::atan(self : Sketch, value : Double) -> Double {
  self.from_radians(@cmath.atan(value))
}

///|
pub fn Sketch::atan2(self : Sketch, y : Double, x : Double) -> Double {
  self.from_radians(@cmath.atan2(y, x))
}

///|
pub fn Sketch::random(self : Sketch) -> Double {
  self.rng.next()
}

///|
pub fn Sketch::random_max(self : Sketch, maximum : Double) -> Double {
  self.rng.next() * maximum
}

///|
pub fn Sketch::random_range(
  self : Sketch,
  minimum : Double,
  maximum : Double,
) -> Double {
  self.rng.range(minimum, maximum)
}

///|
pub fn[T] Sketch::random_choice(self : Sketch, choices : ArrayView[T]) -> T {
  self.rng.choice(choices)
}

///|
pub fn Sketch::random_gaussian(
  self : Sketch,
  mean~ : Double = 0.0,
  sd~ : Double = 1.0,
) -> Double {
  self.rng.gaussian(mean~, sd~)
}

///|
pub fn Sketch::random_seed(self : Sketch, seed : Double) -> Unit {
  self.rng.set_seed(seed)
}

///|
pub fn Sketch::random2d(self : Sketch) -> Vector {
  let angle = self.rng.next() * TAU
  Vector::new(x=@cmath.cos(angle), y=@cmath.sin(angle))
}

///|
pub fn Sketch::random3d(self : Sketch) -> Vector {
  let z = self.rng.next() * 2.0 - 1.0
  let angle = self.rng.next() * TAU
  let r = (1.0 - z * z).max(0.0).sqrt()
  Vector::new(x=r * @cmath.cos(angle), y=r * @cmath.sin(angle), z~)
}

///|
pub fn Sketch::noise(
  self : Sketch,
  x : Double,
  y~ : Double = 0.0,
  z~ : Double = 0.0,
) -> Double {
  self.noise.noise(x, y~, z~)
}

///|
pub fn Sketch::noise_seed(self : Sketch, seed : Double) -> Unit {
  self.noise.set_seed(seed)
}

///|
pub fn Sketch::noise_detail(
  self : Sketch,
  octaves : Int32,
  falloff~ : Double = 0.5,
) -> Unit {
  self.noise.detail(octaves, falloff~)
}

///|
pub fn Sketch::create_vector(
  self : Sketch,
  x : Double,
  y : Double,
  z~ : Double = 0.0,
) -> Vector {
  let _ = self
  Vector::new(x~, y~, z~)
}

// ==== input ====

///|
/// Places the cursor without firing a pointer callback. Useful in `setup` so
/// the first frame already has a sensible hover position.
pub fn Sketch::set_mouse_position(
  self : Sketch,
  x : Double,
  y : Double,
) -> Unit {
  self.mouse_x = x
  self.mouse_y = y
  self.pmouse_x = x
  self.pmouse_y = y
  self.last_frame_mouse_x = x
  self.last_frame_mouse_y = y
  self.moved_x = 0.0
  self.moved_y = 0.0
}

///|
/// Reports committed text input (IME commit or direct typing).
pub fn Sketch::text_input(self : Sketch, text : String) -> Unit {
  self.last_input_text = text
  (self.callbacks.text_input)(self, text)
  self.request_redraw()
}

///|
/// Starts an IME composition. `composition_text` becomes the empty preedit.
pub fn Sketch::composition_start(self : Sketch) -> Unit {
  self.composing = true
  self.composition_text = ""
  (self.callbacks.composition_start)(self)
  self.request_redraw()
}

///|
/// Updates the active preedit. `composing` stays true.
pub fn Sketch::composition_update(self : Sketch, text : String) -> Unit {
  self.composing = true
  self.composition_text = text
  (self.callbacks.composition_update)(self, text)
  self.request_redraw()
}

///|
/// Ends composition with the committed text. The preedit is cleared and the
/// text is recorded in `last_input_text`.
pub fn Sketch::composition_end(self : Sketch, text : String) -> Unit {
  self.composing = false
  self.composition_text = ""
  self.last_input_text = text
  (self.callbacks.composition_end)(self, text)
  self.request_redraw()
}

///|
/// Begins (or restarts) a pointer contact. The same `id` updates one entry in
/// `touches`; `pressure` is clamped to `0..1` and defaults to `1.0` ("no host
/// pressure signal"). The callback reads the committed `p.touches`.
pub fn Sketch::touch_started_at(
  self : Sketch,
  id : Int32,
  x : Double,
  y : Double,
  pressure~ : Double = 1.0,
) -> Unit {
  let touch = Touch::new(x~, y~, id~, pressure~)
  let mut index = 0
  while index < self.touches.length() {
    if self.touches[index].id == id {
      ignore(self.touches.remove(index))
    } else {
      index = index + 1
    }
  }
  self.touches.push(touch)
  (self.callbacks.touch_started)(self)
  self.request_redraw()
}

///|
/// Moves one contact. A Move for an unknown id is treated as a start so a
/// host that drops the initial Down still reports a usable contact.
pub fn Sketch::touch_moved_to(
  self : Sketch,
  id : Int32,
  x : Double,
  y : Double,
  pressure~ : Double = 1.0,
) -> Unit {
  let touch = Touch::new(x~, y~, id~, pressure~)
  let mut found = false
  for index in 0..<self.touches.length() {
    if self.touches[index].id == id {
      self.touches[index] = touch
      found = true
    }
  }
  if !found {
    self.touches.push(touch)
  }
  (self.callbacks.touch_moved)(self)
  self.request_redraw()
}

///|
/// Ends one contact. The ended contact is removed before the callback, matching
/// p5's `touches` view inside `touchEnded`.
pub fn Sketch::touch_ended_at(self : Sketch, id : Int32) -> Unit {
  let mut removed = false
  let mut index = 0
  while index < self.touches.length() {
    if self.touches[index].id == id {
      ignore(self.touches.remove(index))
      removed = true
    } else {
      index = index + 1
    }
  }
  if removed {
    (self.callbacks.touch_ended)(self)
    self.request_redraw()
  }
}

///|
/// Primary-button press at local sketch coordinates.
pub fn Sketch::pointer_down(
  self : Sketch,
  x : Double,
  y : Double,
  button~ : Int32 = 0,
) -> Unit {
  let previous_x = self.mouse_x
  let previous_y = self.mouse_y
  self.mouse_x = x
  self.mouse_y = y
  self.moved_x = x - previous_x
  self.moved_y = y - previous_y
  self.mouse_is_pressed = true
  self.mouse_button = button
  (self.callbacks.mouse_pressed)(self)
  self.request_redraw()
}

///|
pub fn Sketch::pointer_move(self : Sketch, x : Double, y : Double) -> Unit {
  let previous_x = self.mouse_x
  let previous_y = self.mouse_y
  self.mouse_x = x
  self.mouse_y = y
  self.moved_x = x - previous_x
  self.moved_y = y - previous_y
  if self.mouse_is_pressed {
    (self.callbacks.mouse_dragged)(self)
  } else {
    (self.callbacks.mouse_moved)(self)
  }
  self.request_redraw()
}

///|
pub fn Sketch::pointer_up(self : Sketch, x : Double, y : Double) -> Unit {
  let previous_x = self.mouse_x
  let previous_y = self.mouse_y
  self.mouse_x = x
  self.mouse_y = y
  self.moved_x = x - previous_x
  self.moved_y = y - previous_y
  self.mouse_is_pressed = false
  (self.callbacks.mouse_released)(self)
  self.request_redraw()
}

///|
pub fn Sketch::pointer_clicked(self : Sketch, x : Double, y : Double) -> Unit {
  self.mouse_x = x
  self.mouse_y = y
  (self.callbacks.mouse_clicked)(self)
  self.request_redraw()
}

///|
pub fn Sketch::pointer_double_clicked(
  self : Sketch,
  x : Double,
  y : Double,
) -> Unit {
  self.mouse_x = x
  self.mouse_y = y
  (self.callbacks.double_clicked)(self)
  self.request_redraw()
}

///|
pub fn Sketch::pointer_wheel(self : Sketch, delta : Double) -> Unit {
  (self.callbacks.mouse_wheel)(self, delta)
  self.request_redraw()
}

///|
pub fn Sketch::key_down(
  self : Sketch,
  key : String,
  code~ : String = "",
  key_code~ : Int32 = 0,
) -> Unit {
  self.key = key
  self.code = code
  self.key_code = key_code
  self.key_is_pressed = true
  self.keys_down[key] = true
  (self.callbacks.key_pressed)(self)
  self.request_redraw()
}

///|
pub fn Sketch::key_up(
  self : Sketch,
  key : String,
  code~ : String = "",
  key_code~ : Int32 = 0,
) -> Unit {
  self.key = key
  self.code = code
  self.key_code = key_code
  self.key_is_pressed = false
  self.keys_down[key] = false
  (self.callbacks.key_released)(self)
  self.request_redraw()
}

///|
pub fn Sketch::key_typed_input(self : Sketch, key : String) -> Unit {
  self.key = key
  (self.callbacks.key_typed)(self)
  self.request_redraw()
}

///|
pub fn Sketch::key_is_down(self : Sketch, key : String) -> Bool {
  self.keys_down.get(key).unwrap_or(false)
}

///|
pub fn Sketch::focus_changed(self : Sketch, focused : Bool) -> Unit {
  self.focused = focused
}

// ==== colour accessors (p5 instance-style) ====

///|
pub fn[C : ColorArg] Sketch::red(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).red()
}

///|
pub fn[C : ColorArg] Sketch::green(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).green()
}

///|
pub fn[C : ColorArg] Sketch::blue(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).blue()
}

///|
pub fn[C : ColorArg] Sketch::alpha(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).alpha()
}

///|
pub fn[C : ColorArg] Sketch::hue(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).hue()
}

///|
pub fn[C : ColorArg] Sketch::saturation(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).saturation()
}

///|
pub fn[C : ColorArg] Sketch::brightness(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).brightness()
}

///|
pub fn[C : ColorArg] Sketch::lightness(self : Sketch, color : C) -> Double {
  color.to_color(self.style.color_mode, self.style.color_ranges).lightness()
}

///|
pub fn Sketch::lerp_color(
  self : Sketch,
  from : Color,
  to : Color,
  amount : Double,
) -> Color {
  let _ = self
  from.lerp(to, amount)
}

///|
pub fn Sketch::point_vec(self : Sketch, vector : Vector) -> Unit {
  self.point(vector.x, vector.y)
}
