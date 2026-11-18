///|
/// Compact command JSON for the p5 web readback interpreter. The shape is
/// purpose-built (not the derived DrawCommand JSON) so the JS side stays a
/// small, stable switch.

///|
fn json_num(value : Double) -> String {
  value.to_string()
}

///|
fn json_color_suffix(color : @core.Color) -> String {
  ",\"c\":[\{json_num(color.r)},\{json_num(color.g)},\{json_num(color.b)},\{json_num(color.a)}]"
}

///|
fn json_hex4(value : Int32) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let out = StringBuilder()
  for shift in [12, 8, 4, 0] {
    let digit = (value >> shift) & 0xF
    ignore(out.write_char(digits[digit]))
  }
  out.to_string()
}

///|
fn json_string(value : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for ch in value {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ =>
        if ch.to_int() < 0x20 {
          out.write_string("\\u\{json_hex4(ch.to_int())}")
        } else {
          out.write_char(ch)
        }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn json_verbs(verbs : Array[@core.PathVerb]) -> String {
  let out = StringBuilder()
  out.write_string("[")
  for index, verb in verbs {
    if index > 0 {
      out.write_string(",")
    }
    match verb {
      @core.MoveTo(point) =>
        out.write_string("[\"M\",\{json_num(point.x)},\{json_num(point.y)}]")
      @core.LineTo(point) =>
        out.write_string("[\"L\",\{json_num(point.x)},\{json_num(point.y)}]")
      @core.QuadTo(control, point) =>
        out.write_string(
          "[\"Q\",\{json_num(control.x)},\{json_num(control.y)},\{json_num(point.x)},\{json_num(point.y)}]",
        )
      @core.CubicTo(first, second, point) =>
        out.write_string(
          "[\"C\",\{json_num(first.x)},\{json_num(first.y)},\{json_num(second.x)},\{json_num(second.y)},\{json_num(point.x)},\{json_num(point.y)}]",
        )
      @core.Close => out.write_string("[\"Z\"]")
    }
  }
  out.write_string("]")
  out.to_string()
}

///|
fn json_color_key_suffix(key : String, color : @core.Color?) -> String {
  match color {
    Some(color) =>
      ",\"\{key}\":[\{json_num(color.r)},\{json_num(color.g)},\{json_num(color.b)},\{json_num(color.a)}]"
    None => ",\"\{key}\":null"
  }
}

///|
fn json_brush_color(brush : @core.Brush?) -> @core.Color? {
  // The p5 adapter only emits solid brushes; gradients degrade to their
  // fallback color exactly like the live renderer's stroke path does.
  match brush {
    Some(brush) => Some(brush.fallback_color())
    None => None
  }
}

///|
fn json_rect(rect : @core.Rect) -> String {
  "\"x\":\{json_num(rect.origin.x)},\"y\":\{json_num(rect.origin.y)},\"w\":\{json_num(rect.size.width)},\"h\":\{json_num(rect.size.height)}"
}

///|
fn json_command(command : @core.DrawCommand) -> String {
  match command {
    @core.Clear(color) => "{\"op\":\"clear\"\{json_color_suffix(color)}}"
    @core.FillRect(rect, color) =>
      "{\"op\":\"rect\",\{json_rect(rect)}\{json_color_suffix(color)}}"
    @core.StrokeRect(rect, color, width) =>
      "{\"op\":\"srect\",\{json_rect(rect)},\"lw\":\{json_num(width)}\{json_color_suffix(color)}}"
    @core.FillRoundedRect(rounded, color) =>
      "{\"op\":\"rrect\",\{json_rect(rounded.rect)},\"r\":\{json_num(rounded.radius)}\{json_color_suffix(color)}}"
    @core.StrokeRoundedRect(rounded, color, width) =>
      "{\"op\":\"srrect\",\{json_rect(rounded.rect)},\"r\":\{json_num(rounded.radius)},\"lw\":\{json_num(width)}\{json_color_suffix(color)}}"
    @core.DrawPath(spec) =>
      "{\"op\":\"path\",\"v\":\{json_verbs(spec.verbs)},\"sw\":\{json_num(spec.stroke_width)}\{json_color_key_suffix("f", json_brush_color(spec.fill))}\{json_color_key_suffix("s", json_brush_color(spec.stroke))}}"
    @core.DrawText(run) =>
      "{\"op\":\"text\",\"t\":\{json_string(run.text)},\{json_rect(run.frame)},\"size\":\{json_num(run.font.size)},\"weight\":\{json_num(run.font.weight.to_double())}\{json_color_suffix(run.color)}\{json_color_key_suffix("sc", run.stroke_color)},\"sw\":\{json_num(run.stroke_width)}}"
    @core.DrawImage(run) =>
      "{\"op\":\"image\",\"src\":\{json_string(run.source)},\{json_rect(run.frame)}}"
    @core.PushClip(rect) => "{\"op\":\"clip\",\{json_rect(rect)}}"
    @core.PushPathClip(spec) =>
      match spec.shape_bounds() {
        Some(bounds) => "{\"op\":\"clip\",\{json_rect(bounds)}}"
        None => "{\"op\":\"clip\",\"x\":0,\"y\":0,\"w\":0,\"h\":0}"
      }
    @core.PushTransform(transform) =>
      "{\"op\":\"transform\",\"a\":\{json_num(transform.a)},\"b\":\{json_num(transform.b)},\"c\":\{json_num(transform.c)},\"d\":\{json_num(transform.d)},\"tx\":\{json_num(transform.tx)},\"ty\":\{json_num(transform.ty)}}"
    @core.PushOpacity(opacity) =>
      "{\"op\":\"opacity\",\"v\":\{json_num(opacity)}}"
    @core.PushLayer(layer) =>
      match layer.blend_mode {
        @core.BlendMode::Source => "{\"op\":\"layer\",\"mode\":\"copy\"}"
        _ => "{\"op\":\"layer\",\"mode\":\"source-over\"}"
      }
    @core.PopClip | @core.PopPathClip => "{\"op\":\"endclip\"}"
    @core.PopTransform => "{\"op\":\"endtransform\"}"
    @core.PopOpacity => "{\"op\":\"endopacity\"}"
    @core.PopLayer => "{\"op\":\"endlayer\"}"
    _ => ""
  }
}

///|
/// Serializes a command list plus logical size into the readback JSON.
pub fn commands_json(
  commands : Array[@core.DrawCommand],
  width : Double,
  height : Double,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"w\":\{json_num(width)},\"h\":\{json_num(height)},\"ops\":[",
  )
  let mut emitted = 0
  for command in commands {
    let encoded = json_command(command)
    if encoded != "" {
      if emitted > 0 {
        out.write_string(",")
      }
      out.write_string(encoded)
      emitted = emitted + 1
    }
  }
  out.write_string("]}")
  out.to_string()
}
