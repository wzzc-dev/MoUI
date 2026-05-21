///|
pub(all) struct SvgImportResult {
  commands : Array[@core.DrawCommand]
  diagnostics : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub fn import_svg_subset(svg : String) -> SvgImportResult {
  let result = SvgImportResult::{ commands: [], diagnostics: [] }
  if !svg.contains("<svg") {
    result.diagnostics.push("missing <svg> root")
    return result
  }
  import_svg_rects(svg, result)
  import_svg_circles(svg, result)
  import_svg_lines(svg, result)
  import_svg_polygons(svg, result, "polygon", close=true)
  import_svg_polygons(svg, result, "polyline", close=false)
  if svg.contains("<foreignObject") {
    result.diagnostics.push("foreignObject is unsupported")
  }
  if svg.contains("<animate") {
    result.diagnostics.push("SMIL animation is unsupported")
  }
  result
}

///|
fn import_svg_rects(svg : String, result : SvgImportResult) -> Unit {
  for tag in svg_tags(svg, "rect") {
    let x = svg_attr_double(tag, "x", 0.0)
    let y = svg_attr_double(tag, "y", 0.0)
    let width = svg_attr_double(tag, "width", 0.0)
    let height = svg_attr_double(tag, "height", 0.0)
    let rect = @core.Rect::new(x~, y~, width~, height~)
    match svg_attr_color(tag, "fill") {
      Some(color) => result.commands.push(@core.DrawCommand::FillRect(rect, color))
      None => ()
    }
    match svg_attr_color(tag, "stroke") {
      Some(color) =>
        result.commands.push(
          @core.DrawCommand::StrokeRect(
            rect,
            color,
            svg_attr_double(tag, "stroke-width", 1.0),
          ),
        )
      None => ()
    }
  }
}

///|
fn import_svg_circles(svg : String, result : SvgImportResult) -> Unit {
  for tag in svg_tags(svg, "circle") {
    let cx = svg_attr_double(tag, "cx", 0.0)
    let cy = svg_attr_double(tag, "cy", 0.0)
    let radius = svg_attr_double(tag, "r", 0.0)
    if radius > 0.0 {
      result.commands.push(
        @core.DrawCommand::DrawPath(
          @core.PathSpec::new(
            verbs=svg_circle_verbs(cx, cy, radius),
            fill=svg_attr_brush(tag, "fill"),
            stroke=svg_attr_brush(tag, "stroke"),
            stroke_width=svg_attr_double(tag, "stroke-width", 1.0),
          ),
        ),
      )
    }
  }
}

///|
fn import_svg_lines(svg : String, result : SvgImportResult) -> Unit {
  for tag in svg_tags(svg, "line") {
    let stroke = svg_attr_brush(tag, "stroke")
    match stroke {
      Some(_) =>
        result.commands.push(
          @core.DrawCommand::DrawPath(
            @core.PathSpec::new(
              verbs=[
                @core.PathVerb::MoveTo(
                  @core.Point::new(
                    x=svg_attr_double(tag, "x1", 0.0),
                    y=svg_attr_double(tag, "y1", 0.0),
                  ),
                ),
                @core.PathVerb::LineTo(
                  @core.Point::new(
                    x=svg_attr_double(tag, "x2", 0.0),
                    y=svg_attr_double(tag, "y2", 0.0),
                  ),
                ),
              ],
              stroke~,
              stroke_width=svg_attr_double(tag, "stroke-width", 1.0),
            ),
          ),
        )
      None => ()
    }
  }
}

///|
fn import_svg_polygons(
  svg : String,
  result : SvgImportResult,
  name : String,
  close~ : Bool,
) -> Unit {
  for tag in svg_tags(svg, name) {
    let points = svg_parse_points(svg_attr(tag, "points"))
    if points.length() > 0 {
      let verbs : Array[@core.PathVerb] = [
        @core.PathVerb::MoveTo(points[0]),
      ]
      for index in 1..<points.length() {
        verbs.push(@core.PathVerb::LineTo(points[index]))
      }
      if close {
        verbs.push(@core.PathVerb::Close)
      }
      result.commands.push(
        @core.DrawCommand::DrawPath(
          @core.PathSpec::new(
            verbs~,
            fill=svg_attr_brush(tag, "fill"),
            stroke=svg_attr_brush(tag, "stroke"),
            stroke_width=svg_attr_double(tag, "stroke-width", 1.0),
          ),
        ),
      )
    }
  }
}

///|
fn svg_tags(svg : String, name : String) -> Array[String] {
  let tags : Array[String] = []
  let chars = svg.to_array()
  let needle = ("<" + name).to_array()
  let mut index = 0
  while index < chars.length() {
    match svg_find_chars(chars, needle, index) {
      Some(start) => {
        match svg_find_char(chars, start, '>') {
          Some(end) => {
            tags.push(String::from_array(chars[start:end + 1]))
            index = end + 1
          }
          None => index = chars.length()
        }
      }
      None => index = chars.length()
    }
  }
  tags
}

///|
fn svg_attr(tag : String, name : String) -> String {
  let chars = tag.to_array()
  let needle = (name + "=\"").to_array()
  match svg_find_chars(chars, needle, 0) {
    Some(start) => {
      let value_start = start + needle.length()
      match svg_find_char(chars, value_start, '"') {
        Some(end) => String::from_array(chars[value_start:end])
        None => ""
      }
    }
    None => ""
  }
}

///|
fn svg_attr_double(tag : String, name : String, fallback : Double) -> Double {
  let value = svg_attr(tag, name)
  match svg_parse_double(value) {
    Some(parsed) => parsed
    None => fallback
  }
}

///|
fn svg_attr_brush(tag : String, name : String) -> @core.Brush? {
  match svg_attr_color(tag, name) {
    Some(color) => Some(@core.Brush::solid(color))
    None => None
  }
}

///|
fn svg_attr_color(tag : String, name : String) -> @core.Color? {
  match svg_attr(tag, name) {
    "" | "none" => None
    "black" => Some(@core.Color::black())
    "blue" => Some(@core.Color::blue())
    "gray" | "grey" => Some(@core.Color::gray())
    "red" => Some(@core.Color::rgba(r=1.0, g=0.0, b=0.0))
    "green" => Some(@core.Color::rgba(r=0.0, g=0.6, b=0.0))
    "white" => Some(@core.Color::white())
    _ => Some(@core.Color::black())
  }
}

///|
fn svg_circle_verbs(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@core.PathVerb] {
  let verbs : Array[@core.PathVerb] = []
  let unit_points = [
    @core.Point::new(x=1.0, y=0.0),
    @core.Point::new(x=0.70710678, y=0.70710678),
    @core.Point::new(x=0.0, y=1.0),
    @core.Point::new(x=-0.70710678, y=0.70710678),
    @core.Point::new(x=-1.0, y=0.0),
    @core.Point::new(x=-0.70710678, y=-0.70710678),
    @core.Point::new(x=0.0, y=-1.0),
    @core.Point::new(x=0.70710678, y=-0.70710678),
  ]
  for index, unit in unit_points {
    let point = @core.Point::new(
      x=cx + unit.x * radius,
      y=cy + unit.y * radius,
    )
    if index == 0 {
      verbs.push(@core.PathVerb::MoveTo(point))
    } else {
      verbs.push(@core.PathVerb::LineTo(point))
    }
  }
  verbs.push(@core.PathVerb::Close)
  verbs
}

///|
fn svg_parse_points(value : String) -> Array[@core.Point] {
  let points : Array[@core.Point] = []
  let numbers = svg_parse_number_list(value)
  let mut index = 0
  while index + 1 < numbers.length() {
    points.push(@core.Point::new(x=numbers[index], y=numbers[index + 1]))
    index = index + 2
  }
  points
}

///|
fn svg_parse_number_list(value : String) -> Array[Double] {
  let numbers : Array[Double] = []
  let chars = value.to_array()
  let token : Array[Char] = []
  for ch in chars {
    if ch == ',' || ch == ' ' || ch == '\n' || ch == '\t' {
      svg_flush_number_token(numbers, token)
    } else {
      token.push(ch)
    }
  }
  svg_flush_number_token(numbers, token)
  numbers
}

///|
fn svg_flush_number_token(numbers : Array[Double], token : Array[Char]) -> Unit {
  if token.length() > 0 {
    match svg_parse_double(String::from_array(token)) {
      Some(value) => numbers.push(value)
      None => ()
    }
    token.clear()
  }
}

///|
fn svg_parse_double(value : String) -> Double? {
  let chars = value.trim().to_owned().to_array()
  if chars.length() == 0 {
    return None
  }
  let mut sign = 1.0
  let mut index = 0
  if chars[0] == '-' {
    sign = -1.0
    index = 1
  }
  let mut whole = 0.0
  let mut seen_digit = false
  while index < chars.length() && svg_is_digit(chars[index]) {
    whole = whole * 10.0 + svg_digit_value(chars[index]).to_double()
    seen_digit = true
    index = index + 1
  }
  let mut fraction = 0.0
  let mut scale = 1.0
  if index < chars.length() && chars[index] == '.' {
    index = index + 1
    while index < chars.length() && svg_is_digit(chars[index]) {
      fraction = fraction * 10.0 + svg_digit_value(chars[index]).to_double()
      scale = scale * 10.0
      seen_digit = true
      index = index + 1
    }
  }
  if !seen_digit {
    None
  } else {
    Some(sign * (whole + fraction / scale))
  }
}

///|
fn svg_is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn svg_digit_value(ch : Char) -> Int {
  ch.to_int() - '0'.to_int()
}

///|
fn svg_find_chars(
  chars : Array[Char],
  needle : Array[Char],
  start : Int,
) -> Int? {
  if needle.length() == 0 {
    return Some(start)
  }
  let mut index = start
  while index + needle.length() <= chars.length() {
    if chars[index:index + needle.length()] == needle[:] {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn svg_find_char(chars : Array[Char], start : Int, target : Char) -> Int? {
  let mut index = start
  while index < chars.length() {
    if chars[index] == target {
      return Some(index)
    }
    index = index + 1
  }
  None
}
