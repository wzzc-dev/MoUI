///|
/// Wire shape of one plugin frame. `commands` carries every core
/// `DrawCommand` variant; `clear_color` is the frame backdrop the plugin
/// runtime chose (the host paints it instead of guessing from its own bridge
/// program), and `unsupported` counts any command this encoder could not
/// represent so DevTools can report a real gap instead of dropping paint.
pub struct FramePayload {
  commands : Array[@core.DrawCommand]
  clear_color : @core.Color
  unsupported : Int32
  platform_views : Array[@core.PlatformViewPlacement]?
  overlay_bounds : @core.Rect?
  semantics : @core.SemanticsFramePayload?
  text_input : @core.TextInputState?
}

///|
pub fn FramePayload::commands(self : FramePayload) -> Array[@core.DrawCommand] {
  self.commands
}

///|
pub fn FramePayload::clear_color(self : FramePayload) -> @core.Color {
  self.clear_color
}

///|
pub fn FramePayload::unsupported(self : FramePayload) -> Int32 {
  self.unsupported
}

///|
pub fn FramePayload::platform_views(
  self : FramePayload,
) -> Array[@core.PlatformViewPlacement]? {
  self.platform_views
}

///|
pub fn FramePayload::overlay_bounds(self : FramePayload) -> @core.Rect? {
  self.overlay_bounds
}

///|
pub fn FramePayload::semantics(
  self : FramePayload,
) -> @core.SemanticsFramePayload? {
  self.semantics
}

///|
pub fn FramePayload::text_input(self : FramePayload) -> @core.TextInputState? {
  self.text_input
}

///|
fn point_json(point : @core.Point) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["x"] = number_json(point.x)
  fields["y"] = number_json(point.y)
  Json::object(fields)
}

///|
fn point_from_json(value : Json?) -> @core.Point? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let x = match wire_number(fields.get("x")) {
    Some(value) => value
    None => return None
  }
  let y = match wire_number(fields.get("y")) {
    Some(value) => value
    None => return None
  }
  Some(@core.Point::new(x~, y~))
}

///|
fn json_numbers(values : Array[Double]) -> Json {
  Json::array(values.map(value => number_json(value)))
}

///|
fn numbers_from_json(value : Json?) -> Array[Double]? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let values : Array[Double] = []
  for item in items {
    match wire_number(Some(item)) {
      Some(value) => values.push(value)
      None => return None
    }
  }
  Some(values)
}

///|
fn int_json(value : Int32) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn nullable_color_json(value : @core.Color?) -> Json {
  match value {
    Some(color) => color_json(color)
    None => Json::null()
  }
}

///|
/// Optional fields keep the original v1 leniency: absent or null means the
/// default, and a malformed value is treated as absent rather than poisoning
/// the whole frame.
fn nullable_color_from_json(value : Json?) -> @core.Color? {
  match value {
    Some(Json::Null) | None => None
    Some(inner) => color_from_json(Some(inner))
  }
}

///|
fn nullable_rect_json(value : @core.Rect?) -> Json {
  match value {
    Some(rect) => rect_json(rect)
    None => Json::null()
  }
}

///|
fn nullable_rect_from_json(value : Json?) -> @core.Rect? {
  match value {
    Some(Json::Null) | None => None
    Some(inner) => rect_from_json(Some(inner))
  }
}

///|
fn font_family_kind_name(family : @core.FontFamily) -> String {
  match family {
    Name(_) => "name"
    SystemUi => "system-ui"
    UiSansSerif => "ui-sans-serif"
    UiSerif => "ui-serif"
    UiMonospace => "ui-monospace"
    SansSerif => "sans-serif"
    Serif => "serif"
    Monospace => "monospace"
    Emoji => "emoji"
    Math => "math"
    FangSong => "fangsong"
  }
}

///|
fn font_family_json(family : @core.FontFamily) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["kind"] = string_json(font_family_kind_name(family))
  match family {
    Name(name) => fields["name"] = string_json(name)
    _ => ()
  }
  Json::object(fields)
}

///|
fn font_family_from_json(value : Json?) -> @core.FontFamily? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "name" =>
      match wire_string(fields.get("name")) {
        Some(name) => Some(@core.FontFamily::Name(name))
        None => None
      }
    "system-ui" => Some(@core.FontFamily::SystemUi)
    "ui-sans-serif" => Some(@core.FontFamily::UiSansSerif)
    "ui-serif" => Some(@core.FontFamily::UiSerif)
    "ui-monospace" => Some(@core.FontFamily::UiMonospace)
    "sans-serif" => Some(@core.FontFamily::SansSerif)
    "serif" => Some(@core.FontFamily::Serif)
    "monospace" => Some(@core.FontFamily::Monospace)
    "emoji" => Some(@core.FontFamily::Emoji)
    "math" => Some(@core.FontFamily::Math)
    "fangsong" => Some(@core.FontFamily::FangSong)
    _ => None
  }
}

///|
fn font_family_name(font : @core.FontSpec) -> String {
  if font.families.families.is_empty() {
    "system-ui"
  } else {
    font.families.families[0].css_name()
  }
}

///|
fn font_families_json(families : @core.FontFamilyStack) -> Json {
  Json::array(families.families.map(family => font_family_json(family)))
}

///|
fn font_families_from_json(value : Json?) -> @core.FontFamilyStack? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let families : Array[@core.FontFamily] = []
  for item in items {
    match font_family_from_json(Some(item)) {
      Some(family) => families.push(family)
      None => return None
    }
  }
  Some(@core.FontFamilyStack::new(families))
}

///|
fn variations_json(variations : Array[@core.FontVariation]) -> Json {
  Json::array(
    variations.map(variation => {
      let fields : Map[String, Json] = Map([])
      fields["axis"] = string_json(variation.axis)
      fields["value"] = number_json(variation.value)
      Json::object(fields)
    }),
  )
}

///|
fn variations_from_json(value : Json?) -> Array[@core.FontVariation]? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let variations : Array[@core.FontVariation] = []
  for item in items {
    let fields = match wire_object(Some(item)) {
      Some(fields) => fields
      None => return None
    }
    let axis = match wire_string(fields.get("axis")) {
      Some(axis) => axis
      None => return None
    }
    let value = match wire_number(fields.get("value")) {
      Some(value) => value
      None => return None
    }
    variations.push(@core.FontVariation::new(axis~, value~))
  }
  Some(variations)
}

///|
fn features_json(features : Array[@core.FontFeature]) -> Json {
  Json::array(
    features.map(feature => {
      let fields : Map[String, Json] = Map([])
      fields["tag"] = string_json(feature.tag)
      fields["value"] = int_json(feature.value)
      Json::object(fields)
    }),
  )
}

///|
fn features_from_json(value : Json?) -> Array[@core.FontFeature]? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let features : Array[@core.FontFeature] = []
  for item in items {
    let fields = match wire_object(Some(item)) {
      Some(fields) => fields
      None => return None
    }
    let tag = match wire_string(fields.get("tag")) {
      Some(tag) => tag
      None => return None
    }
    let value = match wire_int(fields.get("value")) {
      Some(value) => value
      None => return None
    }
    features.push(@core.FontFeature::new(tag~, value~))
  }
  Some(features)
}

///|
fn text_align_name(align : @core.TextAlign) -> String {
  match align {
    TextStart => "TextStart"
    TextCenter => "TextCenter"
    TextEnd => "TextEnd"
  }
}

///|
fn text_align_from_name(name : String) -> @core.TextAlign? {
  match name {
    "TextStart" => Some(@core.TextAlign::TextStart)
    "TextCenter" => Some(@core.TextAlign::TextCenter)
    "TextEnd" => Some(@core.TextAlign::TextEnd)
    _ => None
  }
}

///|
fn font_json(font : @core.FontSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  // `family` keeps the first family for readers of the original v1 shape;
  // `families` is the lossless stack every current bridge host reads.
  fields["family"] = string_json(font_family_name(font))
  fields["families"] = font_families_json(font.families)
  fields["size"] = number_json(font.size)
  fields["weight"] = int_json(font.weight)
  fields["style"] = string_json(
    match font.style {
      Normal => "Normal"
      Italic => "Italic"
    },
  )
  fields["variations"] = variations_json(font.variations)
  fields["features"] = features_json(font.features)
  fields["line_height"] = match font.line_height {
    Some(value) => number_json(value)
    None => Json::null()
  }
  fields["letter_spacing"] = match font.letter_spacing {
    Some(value) => number_json(value)
    None => Json::null()
  }
  Json::object(fields)
}

///|
fn font_from_json(value : Json?) -> @core.FontSpec? {
  let fields = match wire_object(value) {
    Some(font) => font
    None => return None
  }
  let size = match wire_number(fields.get("size")) {
    Some(size) => size
    None => return None
  }
  let weight = match wire_int(fields.get("weight")) {
    Some(weight) => weight
    None => return None
  }
  let style = match wire_string(fields.get("style")) {
    Some("Italic") => @core.FontStyle::Italic
    Some("Normal") => @core.FontStyle::Normal
    // The first v1 frame shape used an `italic` flag instead of a style name.
    None =>
      if wire_bool(fields.get("italic")).unwrap_or(false) {
        @core.FontStyle::Italic
      } else {
        @core.FontStyle::Normal
      }
    _ => return None
  }
  let families = match fields.get("families") {
    Some(_) =>
      match font_families_from_json(fields.get("families")) {
        Some(families) => families
        None => return None
      }
    None => {
      // Backward compatibility with the first v1 text shape, which carried one
      // css family name.
      let family = wire_string(fields.get("family")).unwrap_or("system-ui")
      if family == "system-ui" || family == "" {
        @core.FontFamilyStack::system_ui()
      } else {
        @core.FontFamilyStack::named(family)
      }
    }
  }
  let variations = match fields.get("variations") {
    None => []
    Some(_) =>
      match variations_from_json(fields.get("variations")) {
        Some(variations) => variations
        None => return None
      }
  }
  let features = match fields.get("features") {
    None => []
    Some(_) =>
      match features_from_json(fields.get("features")) {
        Some(features) => features
        None => return None
      }
  }
  Some(
    @core.FontSpec::new(
      families~,
      size~,
      weight~,
      style~,
      variations~,
      line_height?=wire_nullable_number(fields.get("line_height")),
      letter_spacing?=wire_nullable_number(fields.get("letter_spacing")),
      features~,
    ),
  )
}

///|
fn text_run_json(run : @core.TextRun) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["text"] = string_json(run.text)
  fields["rect"] = rect_json(run.frame)
  fields["font"] = font_json(run.font)
  fields["color"] = color_json(run.color)
  fields["align"] = string_json(text_align_name(run.align))
  fields["stroke_color"] = nullable_color_json(run.stroke_color)
  fields["stroke_width"] = number_json(run.stroke_width)
  Json::object(fields)
}

///|
fn text_run_from_json(value : Json?) -> @core.TextRun? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let text = match wire_string(fields.get("text")) {
    Some(text) => text
    None => return None
  }
  let frame = match rect_from_json(fields.get("rect")) {
    Some(rect) => rect
    None => return None
  }
  let font = match font_from_json(fields.get("font")) {
    Some(font) => font
    None => return None
  }
  let color = match color_from_json(fields.get("color")) {
    Some(color) => color
    None => return None
  }
  let align = match wire_string(fields.get("align")) {
    Some(name) =>
      match text_align_from_name(name) {
        Some(align) => align
        None => return None
      }
    None => return None
  }
  let stroke_color = nullable_color_from_json(fields.get("stroke_color"))
  let stroke_width = wire_number(fields.get("stroke_width")).unwrap_or(0.0)
  Some(@core.TextRun::{
    text,
    frame,
    font,
    color,
    align,
    stroke_color,
    stroke_width,
  })
}

///|
fn linear_gradient_json(gradient : @core.LinearGradientSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["start"] = point_json(gradient.start)
  fields["end"] = point_json(gradient.end)
  fields["start_color"] = color_json(gradient.start_color)
  fields["end_color"] = color_json(gradient.end_color)
  Json::object(fields)
}

///|
fn linear_gradient_from_json(value : Json?) -> @core.LinearGradientSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let start = match point_from_json(fields.get("start")) {
    Some(point) => point
    None => return None
  }
  let end = match point_from_json(fields.get("end")) {
    Some(point) => point
    None => return None
  }
  let start_color = match color_from_json(fields.get("start_color")) {
    Some(color) => color
    None => return None
  }
  let end_color = match color_from_json(fields.get("end_color")) {
    Some(color) => color
    None => return None
  }
  Some(@core.LinearGradientSpec::{ start, end, start_color, end_color, })
}

///|
fn radial_gradient_json(gradient : @core.RadialGradientSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["center"] = point_json(gradient.center)
  fields["radius"] = number_json(gradient.radius)
  fields["center_color"] = color_json(gradient.center_color)
  fields["edge_color"] = color_json(gradient.edge_color)
  Json::object(fields)
}

///|
fn radial_gradient_from_json(value : Json?) -> @core.RadialGradientSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let center = match point_from_json(fields.get("center")) {
    Some(point) => point
    None => return None
  }
  let radius = match wire_number(fields.get("radius")) {
    Some(radius) => radius
    None => return None
  }
  let center_color = match color_from_json(fields.get("center_color")) {
    Some(color) => color
    None => return None
  }
  let edge_color = match color_from_json(fields.get("edge_color")) {
    Some(color) => color
    None => return None
  }
  Some(@core.RadialGradientSpec::{ center, radius, center_color, edge_color, })
}

///|
fn gradient_axis_json(axis : @core.GradientAxis) -> Json {
  let fields : Map[String, Json] = Map([])
  match axis {
    LinearAxis(start, end) => {
      fields["kind"] = string_json("linear")
      fields["start"] = point_json(start)
      fields["end"] = point_json(end)
    }
    RadialAxis(center, radius) => {
      fields["kind"] = string_json("radial")
      fields["center"] = point_json(center)
      fields["radius"] = number_json(radius)
    }
    ConicAxis(center, angle_degrees) => {
      fields["kind"] = string_json("conic")
      fields["center"] = point_json(center)
      fields["angle_degrees"] = number_json(angle_degrees)
    }
  }
  Json::object(fields)
}

///|
fn gradient_axis_from_json(value : Json?) -> @core.GradientAxis? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "linear" => {
      let start = match point_from_json(fields.get("start")) {
        Some(point) => point
        None => return None
      }
      let end = match point_from_json(fields.get("end")) {
        Some(point) => point
        None => return None
      }
      Some(@core.GradientAxis::LinearAxis(start, end))
    }
    "radial" => {
      let center = match point_from_json(fields.get("center")) {
        Some(point) => point
        None => return None
      }
      let radius = match wire_number(fields.get("radius")) {
        Some(radius) => radius
        None => return None
      }
      Some(@core.GradientAxis::RadialAxis(center, radius))
    }
    "conic" => {
      let center = match point_from_json(fields.get("center")) {
        Some(point) => point
        None => return None
      }
      let angle = match wire_number(fields.get("angle_degrees")) {
        Some(angle) => angle
        None => return None
      }
      Some(@core.GradientAxis::ConicAxis(center, angle))
    }
    _ => None
  }
}

///|
fn gradient_stops_json(stops : Array[@core.GradientStop]) -> Json {
  Json::array(
    stops.map(stop => {
      let fields : Map[String, Json] = Map([])
      fields["color"] = color_json(stop.color)
      fields["at"] = number_json(stop.at)
      Json::object(fields)
    }),
  )
}

///|
fn gradient_stops_from_json(value : Json?) -> Array[@core.GradientStop]? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let stops : Array[@core.GradientStop] = []
  for item in items {
    let fields = match wire_object(Some(item)) {
      Some(fields) => fields
      None => return None
    }
    let color = match color_from_json(fields.get("color")) {
      Some(color) => color
      None => return None
    }
    let at = match wire_number(fields.get("at")) {
      Some(at) => at
      None => return None
    }
    stops.push(@core.GradientStop::new(color~, at~))
  }
  Some(stops)
}

///|
fn stops_gradient_json(spec : @core.StopsGradientSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["axis"] = gradient_axis_json(spec.axis)
  fields["stops"] = gradient_stops_json(spec.stops)
  fields["oklab"] = bool_json(spec.oklab)
  Json::object(fields)
}

///|
fn stops_gradient_from_json(value : Json?) -> @core.StopsGradientSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let axis = match gradient_axis_from_json(fields.get("axis")) {
    Some(axis) => axis
    None => return None
  }
  let stops = match gradient_stops_from_json(fields.get("stops")) {
    Some(stops) => stops
    None => return None
  }
  let oklab = wire_bool(fields.get("oklab")).unwrap_or(false)
  Some(@core.StopsGradientSpec::new(axis~, stops~, oklab~))
}

///|
fn brush_json(brush : @core.Brush) -> Json {
  let fields : Map[String, Json] = Map([])
  match brush {
    Solid(color) => {
      fields["kind"] = string_json("solid")
      fields["color"] = color_json(color)
    }
    LinearGradient(gradient) => {
      fields["kind"] = string_json("linear")
      fields["gradient"] = linear_gradient_json(gradient)
    }
    RadialGradient(gradient) => {
      fields["kind"] = string_json("radial")
      fields["gradient"] = radial_gradient_json(gradient)
    }
    StopsGradient(spec) => {
      fields["kind"] = string_json("stops")
      fields["gradient"] = stops_gradient_json(spec)
    }
  }
  Json::object(fields)
}

///|
fn brush_from_json(value : Json?) -> @core.Brush? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "solid" =>
      match color_from_json(fields.get("color")) {
        Some(color) => Some(@core.Brush::Solid(color))
        None => None
      }
    "linear" =>
      match linear_gradient_from_json(fields.get("gradient")) {
        Some(gradient) => Some(@core.Brush::LinearGradient(gradient))
        None => None
      }
    "radial" =>
      match radial_gradient_from_json(fields.get("gradient")) {
        Some(gradient) => Some(@core.Brush::RadialGradient(gradient))
        None => None
      }
    "stops" =>
      match stops_gradient_from_json(fields.get("gradient")) {
        Some(spec) => Some(@core.Brush::StopsGradient(spec))
        None => None
      }
    _ => None
  }
}

///|
fn shadow_spec_json(spec : @core.ShadowSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["rect"] = rounded_rect_json(spec.rect)
  fields["color"] = color_json(spec.color)
  fields["offset"] = point_json(spec.offset)
  fields["blur_radius"] = number_json(spec.blur_radius)
  fields["spread"] = number_json(spec.spread)
  Json::object(fields)
}

///|
fn shadow_spec_from_json(value : Json?) -> @core.ShadowSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let rect = match rounded_rect_from_json(fields.get("rect")) {
    Some(rect) => rect
    None => return None
  }
  let color = match color_from_json(fields.get("color")) {
    Some(color) => color
    None => return None
  }
  let offset = match point_from_json(fields.get("offset")) {
    Some(point) => point
    None => return None
  }
  let blur_radius = match wire_number(fields.get("blur_radius")) {
    Some(value) => value
    None => return None
  }
  let spread = wire_number(fields.get("spread")).unwrap_or(0.0)
  Some(@core.ShadowSpec::{ rect, color, offset, blur_radius, spread, })
}

///|
fn image_fit_name(fit : @core.ImageFit) -> String {
  match fit {
    Contain => "Contain"
    Cover => "Cover"
    Stretch => "Stretch"
    ScaleDown => "ScaleDown"
    FitWidth => "FitWidth"
    FitHeight => "FitHeight"
  }
}

///|
fn image_fit_from_name(name : String) -> @core.ImageFit? {
  match name {
    "Contain" => Some(@core.ImageFit::Contain)
    "Cover" => Some(@core.ImageFit::Cover)
    "Stretch" => Some(@core.ImageFit::Stretch)
    "ScaleDown" => Some(@core.ImageFit::ScaleDown)
    "FitWidth" => Some(@core.ImageFit::FitWidth)
    "FitHeight" => Some(@core.ImageFit::FitHeight)
    _ => None
  }
}

///|
fn image_run_json(run : @core.ImageRun) -> Json {
  let fields : Map[String, Json] = Map([])
  // `source` is the path the plugin painted; the host loads the same source.
  fields["source"] = string_json(run.source)
  fields["rect"] = rect_json(run.frame)
  fields["opacity"] = number_json(run.opacity)
  fields["fit"] = string_json(image_fit_name(run.fit))
  fields["src_rect"] = nullable_rect_json(run.src_rect)
  Json::object(fields)
}

///|
fn image_run_from_json(value : Json?) -> @core.ImageRun? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let source = match wire_string(fields.get("source")) {
    Some(source) => source
    None => return None
  }
  let frame = match rect_from_json(fields.get("rect")) {
    Some(rect) => rect
    None => return None
  }
  let opacity = wire_number(fields.get("opacity")).unwrap_or(1.0)
  let fit = match wire_string(fields.get("fit")) {
    Some(name) =>
      match image_fit_from_name(name) {
        Some(fit) => fit
        None => return None
      }
    None => @core.ImageFit::Contain
  }
  let src_rect = nullable_rect_from_json(fields.get("src_rect"))
  Some(@core.ImageRun::{ source, frame, opacity, fit, src_rect, })
}

///|
fn transform_json(transform : @core.Transform2D) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["a"] = number_json(transform.a)
  fields["b"] = number_json(transform.b)
  fields["c"] = number_json(transform.c)
  fields["d"] = number_json(transform.d)
  fields["tx"] = number_json(transform.tx)
  fields["ty"] = number_json(transform.ty)
  Json::object(fields)
}

///|
fn transform_from_json(value : Json?) -> @core.Transform2D? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let a = match wire_number(fields.get("a")) {
    Some(value) => value
    None => return None
  }
  let b = match wire_number(fields.get("b")) {
    Some(value) => value
    None => return None
  }
  let c = match wire_number(fields.get("c")) {
    Some(value) => value
    None => return None
  }
  let d = match wire_number(fields.get("d")) {
    Some(value) => value
    None => return None
  }
  let tx = match wire_number(fields.get("tx")) {
    Some(value) => value
    None => return None
  }
  let ty = match wire_number(fields.get("ty")) {
    Some(value) => value
    None => return None
  }
  Some(@core.Transform2D::{ a, b, c, d, tx, ty, })
}

///|
fn blend_mode_name(mode : @core.BlendMode) -> String {
  match mode {
    SourceOver => "SourceOver"
    Multiply => "Multiply"
    Screen => "Screen"
    Overlay => "Overlay"
    Darken => "Darken"
    Lighten => "Lighten"
    Add => "Add"
    Difference => "Difference"
    Exclusion => "Exclusion"
    HardLight => "HardLight"
    SoftLight => "SoftLight"
    ColorDodge => "ColorDodge"
    ColorBurn => "ColorBurn"
    Source => "Source"
  }
}

///|
fn blend_mode_from_name(name : String) -> @core.BlendMode? {
  match name {
    "SourceOver" => Some(@core.BlendMode::SourceOver)
    "Multiply" => Some(@core.BlendMode::Multiply)
    "Screen" => Some(@core.BlendMode::Screen)
    "Overlay" => Some(@core.BlendMode::Overlay)
    "Darken" => Some(@core.BlendMode::Darken)
    "Lighten" => Some(@core.BlendMode::Lighten)
    "Add" => Some(@core.BlendMode::Add)
    "Difference" => Some(@core.BlendMode::Difference)
    "Exclusion" => Some(@core.BlendMode::Exclusion)
    "HardLight" => Some(@core.BlendMode::HardLight)
    "SoftLight" => Some(@core.BlendMode::SoftLight)
    "ColorDodge" => Some(@core.BlendMode::ColorDodge)
    "ColorBurn" => Some(@core.BlendMode::ColorBurn)
    "Source" => Some(@core.BlendMode::Source)
    _ => None
  }
}

///|
fn layer_mask_json(mask : @core.LayerMask) -> Json {
  let fields : Map[String, Json] = Map([])
  match mask {
    NoMask => fields["kind"] = string_json("none")
    RectMask(rect) => {
      fields["kind"] = string_json("rect")
      fields["rect"] = rect_json(rect)
    }
    RoundedMask(rounded) => {
      fields["kind"] = string_json("rounded")
      fields["rounded"] = rounded_rect_json(rounded)
    }
  }
  Json::object(fields)
}

///|
fn layer_mask_from_json(value : Json?) -> @core.LayerMask? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "none" => Some(@core.LayerMask::NoMask)
    "rect" =>
      match rect_from_json(fields.get("rect")) {
        Some(rect) => Some(@core.LayerMask::RectMask(rect))
        None => None
      }
    "rounded" =>
      match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => Some(@core.LayerMask::RoundedMask(rounded))
        None => None
      }
    _ => None
  }
}

///|
fn layer_spec_json(spec : @core.LayerSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["opacity"] = number_json(spec.opacity)
  fields["blend_mode"] = string_json(blend_mode_name(spec.blend_mode))
  fields["mask"] = layer_mask_json(spec.mask)
  fields["offscreen"] = bool_json(spec.offscreen)
  Json::object(fields)
}

///|
fn layer_spec_from_json(value : Json?) -> @core.LayerSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let opacity = wire_number(fields.get("opacity")).unwrap_or(1.0)
  let blend_mode = match wire_string(fields.get("blend_mode")) {
    Some(name) =>
      match blend_mode_from_name(name) {
        Some(mode) => mode
        None => return None
      }
    None => @core.BlendMode::SourceOver
  }
  let mask = match layer_mask_from_json(fields.get("mask")) {
    Some(mask) => mask
    None => return None
  }
  let offscreen = wire_bool(fields.get("offscreen")).unwrap_or(false)
  Some(@core.LayerSpec::{ opacity, blend_mode, mask, offscreen, })
}

///|
fn retained_layer_spec_json(spec : @core.RetainedLayerSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["key"] = string_json(spec.key)
  fields["rect"] = rect_json(spec.frame)
  fields["content_revision"] = int_json(spec.content_revision)
  fields["scale_factor"] = number_json(spec.scale_factor)
  Json::object(fields)
}

///|
fn retained_layer_spec_from_json(value : Json?) -> @core.RetainedLayerSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let key = match wire_string(fields.get("key")) {
    Some(key) => key
    None => return None
  }
  let frame = match rect_from_json(fields.get("rect")) {
    Some(rect) => rect
    None => return None
  }
  let content_revision = match wire_int(fields.get("content_revision")) {
    Some(value) => value
    None => return None
  }
  let scale_factor = wire_number(fields.get("scale_factor")).unwrap_or(1.0)
  Some(@core.RetainedLayerSpec::{ key, frame, content_revision, scale_factor, })
}

///|
fn filter_json(effect : @core.FilterEffect) -> Json {
  let fields : Map[String, Json] = Map([])
  match effect {
    Blur(radius) => {
      fields["kind"] = string_json("blur")
      fields["value"] = number_json(radius)
    }
    Saturate(amount) => {
      fields["kind"] = string_json("saturate")
      fields["value"] = number_json(amount)
    }
    Brightness(amount) => {
      fields["kind"] = string_json("brightness")
      fields["value"] = number_json(amount)
    }
    Contrast(amount) => {
      fields["kind"] = string_json("contrast")
      fields["value"] = number_json(amount)
    }
    ColorMatrix(matrix) => {
      fields["kind"] = string_json("color_matrix")
      fields["matrix"] = json_numbers(matrix)
    }
  }
  Json::object(fields)
}

///|
fn filter_from_json(value : Json?) -> @core.FilterEffect? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "blur" =>
      match wire_number(fields.get("value")) {
        Some(radius) => Some(@core.FilterEffect::Blur(radius))
        None => None
      }
    "saturate" =>
      match wire_number(fields.get("value")) {
        Some(amount) => Some(@core.FilterEffect::Saturate(amount))
        None => None
      }
    "brightness" =>
      match wire_number(fields.get("value")) {
        Some(amount) => Some(@core.FilterEffect::Brightness(amount))
        None => None
      }
    "contrast" =>
      match wire_number(fields.get("value")) {
        Some(amount) => Some(@core.FilterEffect::Contrast(amount))
        None => None
      }
    "color_matrix" =>
      match numbers_from_json(fields.get("matrix")) {
        Some(matrix) => Some(@core.FilterEffect::ColorMatrix(matrix))
        None => None
      }
    _ => None
  }
}

///|
fn stroke_cap_name(cap : @core.StrokeCap) -> String {
  match cap {
    Butt => "Butt"
    Round => "Round"
    Square => "Square"
  }
}

///|
fn stroke_cap_from_name(name : String) -> @core.StrokeCap? {
  match name {
    "Butt" => Some(@core.StrokeCap::Butt)
    "Round" => Some(@core.StrokeCap::Round)
    "Square" => Some(@core.StrokeCap::Square)
    _ => None
  }
}

///|
fn stroke_join_name(join : @core.StrokeJoin) -> String {
  match join {
    Miter => "Miter"
    Round => "Round"
    Bevel => "Bevel"
  }
}

///|
fn stroke_join_from_name(name : String) -> @core.StrokeJoin? {
  match name {
    "Miter" => Some(@core.StrokeJoin::Miter)
    "Round" => Some(@core.StrokeJoin::Round)
    "Bevel" => Some(@core.StrokeJoin::Bevel)
    _ => None
  }
}

///|
fn path_verb_json(verb : @core.PathVerb) -> Json {
  let fields : Map[String, Json] = Map([])
  match verb {
    MoveTo(point) => {
      fields["kind"] = string_json("move_to")
      fields["point"] = point_json(point)
    }
    LineTo(point) => {
      fields["kind"] = string_json("line_to")
      fields["point"] = point_json(point)
    }
    QuadTo(control, end) => {
      fields["kind"] = string_json("quad_to")
      fields["control"] = point_json(control)
      fields["end"] = point_json(end)
    }
    CubicTo(control1, control2, end) => {
      fields["kind"] = string_json("cubic_to")
      fields["control1"] = point_json(control1)
      fields["control2"] = point_json(control2)
      fields["end"] = point_json(end)
    }
    Close => fields["kind"] = string_json("close")
  }
  Json::object(fields)
}

///|
fn path_verb_from_json(value : Json?) -> @core.PathVerb? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "move_to" =>
      match point_from_json(fields.get("point")) {
        Some(point) => Some(@core.PathVerb::MoveTo(point))
        None => None
      }
    "line_to" =>
      match point_from_json(fields.get("point")) {
        Some(point) => Some(@core.PathVerb::LineTo(point))
        None => None
      }
    "quad_to" => {
      let control = match point_from_json(fields.get("control")) {
        Some(point) => point
        None => return None
      }
      let end = match point_from_json(fields.get("end")) {
        Some(point) => point
        None => return None
      }
      Some(@core.PathVerb::QuadTo(control, end))
    }
    "cubic_to" => {
      let control1 = match point_from_json(fields.get("control1")) {
        Some(point) => point
        None => return None
      }
      let control2 = match point_from_json(fields.get("control2")) {
        Some(point) => point
        None => return None
      }
      let end = match point_from_json(fields.get("end")) {
        Some(point) => point
        None => return None
      }
      Some(@core.PathVerb::CubicTo(control1, control2, end))
    }
    "close" => Some(@core.PathVerb::Close)
    _ => None
  }
}

///|
fn path_spec_json(spec : @core.PathSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["verbs"] = Json::array(spec.verbs.map(verb => path_verb_json(verb)))
  fields["fill"] = match spec.fill {
    Some(brush) => brush_json(brush)
    None => Json::null()
  }
  fields["stroke"] = match spec.stroke {
    Some(brush) => brush_json(brush)
    None => Json::null()
  }
  fields["stroke_width"] = number_json(spec.stroke_width)
  fields["stroke_cap"] = match spec.stroke_cap {
    Some(cap) => string_json(stroke_cap_name(cap))
    None => Json::null()
  }
  fields["stroke_join"] = match spec.stroke_join {
    Some(join) => string_json(stroke_join_name(join))
    None => Json::null()
  }
  Json::object(fields)
}

///|
fn path_spec_from_json(value : Json?) -> @core.PathSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let items = match wire_array(fields.get("verbs")) {
    Some(items) => items
    None => return None
  }
  let verbs : Array[@core.PathVerb] = []
  for item in items {
    match path_verb_from_json(Some(item)) {
      Some(verb) => verbs.push(verb)
      None => return None
    }
  }
  let fill = match fields.get("fill") {
    Some(Json::Null) | None => None
    Some(value) =>
      match brush_from_json(Some(value)) {
        Some(brush) => Some(brush)
        None => return None
      }
  }
  let stroke = match fields.get("stroke") {
    Some(Json::Null) | None => None
    Some(value) =>
      match brush_from_json(Some(value)) {
        Some(brush) => Some(brush)
        None => return None
      }
  }
  let stroke_width = wire_number(fields.get("stroke_width")).unwrap_or(1.0)
  let stroke_cap = match fields.get("stroke_cap") {
    Some(Json::Null) | None => None
    Some(value) =>
      match wire_string(Some(value)) {
        Some(name) =>
          match stroke_cap_from_name(name) {
            Some(cap) => Some(cap)
            None => return None
          }
        None => return None
      }
  }
  let stroke_join = match fields.get("stroke_join") {
    Some(Json::Null) | None => None
    Some(value) =>
      match wire_string(Some(value)) {
        Some(name) =>
          match stroke_join_from_name(name) {
            Some(join) => Some(join)
            None => return None
          }
        None => return None
      }
  }
  Some(@core.PathSpec::{
    verbs,
    fill,
    stroke,
    stroke_width,
    stroke_cap,
    stroke_join,
  })
}

///|
fn shader_effect_json(spec : @core.ShaderEffectSpec) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["name"] = string_json(spec.name)
  fields["rect"] = rect_json(spec.frame)
  fields["uniforms"] = json_numbers(spec.uniforms)
  fields["fallback"] = brush_json(spec.fallback)
  Json::object(fields)
}

///|
fn shader_effect_from_json(value : Json?) -> @core.ShaderEffectSpec? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let name = match wire_string(fields.get("name")) {
    Some(name) => name
    None => return None
  }
  let frame = match rect_from_json(fields.get("rect")) {
    Some(rect) => rect
    None => return None
  }
  let uniforms = match numbers_from_json(fields.get("uniforms")) {
    Some(uniforms) => uniforms
    None => return None
  }
  let fallback = match brush_from_json(fields.get("fallback")) {
    Some(brush) => brush
    None => return None
  }
  Some(@core.ShaderEffectSpec::{ name, frame, uniforms, fallback, })
}

///|
fn command_json(command : @core.DrawCommand) -> Json {
  let fields : Map[String, Json] = Map([])
  match command {
    Clear(color) => {
      fields["kind"] = string_json("clear")
      fields["color"] = color_json(color)
    }
    FillRect(rect, color) => {
      fields["kind"] = string_json("fill_rect")
      fields["rect"] = rect_json(rect)
      fields["color"] = color_json(color)
    }
    StrokeRect(rect, color, width) => {
      fields["kind"] = string_json("stroke_rect")
      fields["rect"] = rect_json(rect)
      fields["color"] = color_json(color)
      fields["width"] = number_json(width)
    }
    FillRoundedRect(rounded, color) => {
      fields["kind"] = string_json("fill_rounded_rect")
      fields["rounded"] = rounded_rect_json(rounded)
      fields["color"] = color_json(color)
    }
    StrokeRoundedRect(rounded, color, width) => {
      fields["kind"] = string_json("stroke_rounded_rect")
      fields["rounded"] = rounded_rect_json(rounded)
      fields["color"] = color_json(color)
      fields["width"] = number_json(width)
    }
    FillRoundedRectBrush(rounded, brush) => {
      fields["kind"] = string_json("fill_rounded_rect_brush")
      fields["rounded"] = rounded_rect_json(rounded)
      fields["brush"] = brush_json(brush)
    }
    StrokeRoundedRectBrush(rounded, brush, width) => {
      fields["kind"] = string_json("stroke_rounded_rect_brush")
      fields["rounded"] = rounded_rect_json(rounded)
      fields["brush"] = brush_json(brush)
      fields["width"] = number_json(width)
    }
    DrawShadow(spec) => {
      fields["kind"] = string_json("draw_shadow")
      fields["shadow"] = shadow_spec_json(spec)
    }
    DrawText(run) => {
      fields["kind"] = string_json("draw_text")
      fields["run"] = text_run_json(run)
    }
    DrawImage(run) => {
      fields["kind"] = string_json("draw_image")
      fields["run"] = image_run_json(run)
    }
    PushClip(rect) => {
      fields["kind"] = string_json("push_clip")
      fields["rect"] = rect_json(rect)
    }
    PopClip => fields["kind"] = string_json("pop_clip")
    PushRoundedClip(rounded) => {
      fields["kind"] = string_json("push_rounded_clip")
      fields["rounded"] = rounded_rect_json(rounded)
    }
    PopRoundedClip => fields["kind"] = string_json("pop_rounded_clip")
    PushPathClip(spec) => {
      fields["kind"] = string_json("push_path_clip")
      fields["path"] = path_spec_json(spec)
    }
    PopPathClip => fields["kind"] = string_json("pop_path_clip")
    PushTransform(transform) => {
      fields["kind"] = string_json("push_transform")
      fields["transform"] = transform_json(transform)
    }
    PopTransform => fields["kind"] = string_json("pop_transform")
    PushOpacity(opacity) => {
      fields["kind"] = string_json("push_opacity")
      fields["opacity"] = number_json(opacity)
    }
    PopOpacity => fields["kind"] = string_json("pop_opacity")
    PushLayer(spec) => {
      fields["kind"] = string_json("push_layer")
      fields["layer"] = layer_spec_json(spec)
    }
    PopLayer => fields["kind"] = string_json("pop_layer")
    BeginRetainedLayer(spec) => {
      fields["kind"] = string_json("begin_retained_layer")
      fields["layer"] = retained_layer_spec_json(spec)
    }
    EndRetainedLayer(key) => {
      fields["kind"] = string_json("end_retained_layer")
      fields["key"] = string_json(key)
    }
    PushFilter(effect) => {
      fields["kind"] = string_json("push_filter")
      fields["filter"] = filter_json(effect)
    }
    PopFilter => fields["kind"] = string_json("pop_filter")
    DrawPath(spec) => {
      fields["kind"] = string_json("draw_path")
      fields["path"] = path_spec_json(spec)
    }
    DrawShaderEffect(spec) => {
      fields["kind"] = string_json("draw_shader_effect")
      fields["effect"] = shader_effect_json(spec)
    }
  }
  Json::object(fields)
}

///|
/// Encode a plugin `DrawFrame` for the bridge host. Every core `DrawCommand`
/// variant is represented; the root also carries the frame clear color so the
/// host paints the app's own backdrop. A future variant this encoder does not
/// know is counted in `unsupported` instead of silently dropped.
pub fn encode_frame(
  frame : @core.DrawFrame,
  text_input~ : @core.TextInputState? = None,
) -> String {
  let commands : Array[Json] = []
  for command in frame.commands {
    commands.push(command_json(command))
  }
  let root : Map[String, Json] = Map([])
  root["version"] = int_json(abi_version())
  root["commands"] = Json::array(commands)
  root["clear_color"] = color_json(frame.clear_color)
  // Platform-owned state rides beside the paint stream so the host adapters
  // (IME, accessibility, native platform views) see the plugin's real tree.
  root["platform_views"] = platform_view_placements_to_json(
    frame.platform_views,
  )
  root["overlay_bounds"] = nullable_rect_json(frame.overlay_bounds)
  root["semantics"] = nullable_semantics_json(frame.semantics)
  root["text_input"] = nullable_text_input_json(text_input)
  // The match in `command_json` is exhaustive, so the wire stays honest: a new
  // core variant is a compile error here rather than a silent drop.
  root["unsupported"] = int_json(0)
  Json::object(root).stringify()
}

///|
fn command_from_json(value : Json) -> @core.DrawCommand? {
  let fields = match wire_object(Some(value)) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "clear" => {
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      Some(@core.DrawCommand::Clear(color))
    }
    "fill_rect" => {
      let rect = match rect_from_json(fields.get("rect")) {
        Some(rect) => rect
        None => return None
      }
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      Some(@core.DrawCommand::FillRect(rect, color))
    }
    "stroke_rect" => {
      let rect = match rect_from_json(fields.get("rect")) {
        Some(rect) => rect
        None => return None
      }
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      let width = match wire_number(fields.get("width")) {
        Some(width) => width
        None => return None
      }
      Some(@core.DrawCommand::StrokeRect(rect, color, width))
    }
    "fill_rounded_rect" => {
      let rounded = match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => rounded
        None => return None
      }
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      Some(@core.DrawCommand::FillRoundedRect(rounded, color))
    }
    "stroke_rounded_rect" => {
      let rounded = match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => rounded
        None => return None
      }
      let color = match color_from_json(fields.get("color")) {
        Some(color) => color
        None => return None
      }
      let width = match wire_number(fields.get("width")) {
        Some(width) => width
        None => return None
      }
      Some(@core.DrawCommand::StrokeRoundedRect(rounded, color, width))
    }
    "fill_rounded_rect_brush" => {
      let rounded = match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => rounded
        None => return None
      }
      let brush = match brush_from_json(fields.get("brush")) {
        Some(brush) => brush
        None => return None
      }
      Some(@core.DrawCommand::FillRoundedRectBrush(rounded, brush))
    }
    "stroke_rounded_rect_brush" => {
      let rounded = match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => rounded
        None => return None
      }
      let brush = match brush_from_json(fields.get("brush")) {
        Some(brush) => brush
        None => return None
      }
      let width = match wire_number(fields.get("width")) {
        Some(width) => width
        None => return None
      }
      Some(@core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width))
    }
    "draw_shadow" => {
      let spec = match shadow_spec_from_json(fields.get("shadow")) {
        Some(spec) => spec
        None => return None
      }
      Some(@core.DrawCommand::DrawShadow(spec))
    }
    "draw_text" => {
      let run = match text_run_from_json(fields.get("run")) {
        Some(run) => run
        None => return None
      }
      Some(@core.DrawCommand::DrawText(run))
    }
    // Original v1 name: the text run fields sat directly on the command.
    "text" =>
      match text_run_from_json(Some(value)) {
        Some(run) => Some(@core.DrawCommand::DrawText(run))
        None => None
      }
    "draw_image" => {
      let run = match image_run_from_json(fields.get("run")) {
        Some(run) => run
        None => return None
      }
      Some(@core.DrawCommand::DrawImage(run))
    }
    "push_clip" => {
      let rect = match rect_from_json(fields.get("rect")) {
        Some(rect) => rect
        None => return None
      }
      Some(@core.DrawCommand::PushClip(rect))
    }
    "pop_clip" => Some(@core.DrawCommand::PopClip)
    "push_rounded_clip" => {
      let rounded = match rounded_rect_from_json(fields.get("rounded")) {
        Some(rounded) => rounded
        None => return None
      }
      Some(@core.DrawCommand::PushRoundedClip(rounded))
    }
    "pop_rounded_clip" => Some(@core.DrawCommand::PopRoundedClip)
    "push_path_clip" => {
      let spec = match path_spec_from_json(fields.get("path")) {
        Some(spec) => spec
        None => return None
      }
      Some(@core.DrawCommand::PushPathClip(spec))
    }
    "pop_path_clip" => Some(@core.DrawCommand::PopPathClip)
    "push_transform" => {
      let transform = match transform_from_json(fields.get("transform")) {
        Some(transform) => transform
        None => return None
      }
      Some(@core.DrawCommand::PushTransform(transform))
    }
    "pop_transform" => Some(@core.DrawCommand::PopTransform)
    "push_opacity" => {
      let opacity = match wire_number(fields.get("opacity")) {
        Some(opacity) => opacity
        None => return None
      }
      Some(@core.DrawCommand::PushOpacity(opacity))
    }
    "pop_opacity" => Some(@core.DrawCommand::PopOpacity)
    "push_layer" => {
      let spec = match layer_spec_from_json(fields.get("layer")) {
        Some(spec) => spec
        None => return None
      }
      Some(@core.DrawCommand::PushLayer(spec))
    }
    "pop_layer" => Some(@core.DrawCommand::PopLayer)
    "begin_retained_layer" => {
      let spec = match retained_layer_spec_from_json(fields.get("layer")) {
        Some(spec) => spec
        None => return None
      }
      Some(@core.DrawCommand::BeginRetainedLayer(spec))
    }
    "end_retained_layer" => {
      let key = match wire_string(fields.get("key")) {
        Some(key) => key
        None => return None
      }
      Some(@core.DrawCommand::EndRetainedLayer(key))
    }
    "push_filter" => {
      let effect = match filter_from_json(fields.get("filter")) {
        Some(effect) => effect
        None => return None
      }
      Some(@core.DrawCommand::PushFilter(effect))
    }
    "pop_filter" => Some(@core.DrawCommand::PopFilter)
    "draw_path" => {
      let spec = match path_spec_from_json(fields.get("path")) {
        Some(spec) => spec
        None => return None
      }
      Some(@core.DrawCommand::DrawPath(spec))
    }
    "draw_shader_effect" => {
      let spec = match shader_effect_from_json(fields.get("effect")) {
        Some(spec) => spec
        None => return None
      }
      Some(@core.DrawCommand::DrawShaderEffect(spec))
    }
    _ => None
  }
}

///|
/// Decode the bridge frame back into real core commands plus the frame clear
/// color. Any malformed command rejects the whole payload: a partially painted
/// frame is worse than keeping the previous one.
pub fn decode_frame_payload(text : String) -> FramePayload? {
  let parsed = @json.parse(text) catch { _ => return None }
  let root = match wire_object(Some(parsed)) {
    Some(root) => root
    None => return None
  }
  match wire_int(root.get("version")) {
    Some(version) => if version != abi_version() { return None }
    None => return None
  }
  let items = match wire_array(root.get("commands")) {
    Some(items) => items
    None => return None
  }
  let commands : Array[@core.DrawCommand] = []
  for item in items {
    match command_from_json(item) {
      Some(command) => commands.push(command)
      None => return None
    }
  }
  let clear_color = match root.get("clear_color") {
    Some(Json::Null) | None => @core.Color::white()
    Some(_) =>
      match color_from_json(root.get("clear_color")) {
        Some(color) => color
        None => return None
      }
  }
  let unsupported = wire_int(root.get("unsupported")).unwrap_or(0)
  // Optional platform state is lenient about absence (older images) but
  // strict about a present malformed value: native views and accessibility
  // objects must not be driven from a half-decoded tree.
  let platform_views = match root.get("platform_views") {
    Some(Json::Null) | None => None
    Some(_) =>
      match platform_view_placements_from_json(root.get("platform_views")) {
        Some(views) => Some(views)
        None => return None
      }
  }
  let overlay_bounds = match root.get("overlay_bounds") {
    Some(Json::Null) | None => None
    Some(_) =>
      match rect_from_json(root.get("overlay_bounds")) {
        Some(rect) => Some(rect)
        None => return None
      }
  }
  let semantics = match root.get("semantics") {
    Some(Json::Null) | None => None
    Some(_) =>
      match semantics_payload_from_json(root.get("semantics")) {
        Some(payload) => Some(payload)
        None => return None
      }
  }
  let text_input = match root.get("text_input") {
    Some(Json::Null) | None => None
    Some(_) =>
      match text_input_state_from_json(root.get("text_input")) {
        Some(state) => Some(state)
        None => return None
      }
  }
  Some({
    commands,
    clear_color,
    unsupported,
    platform_views,
    overlay_bounds,
    semantics,
    text_input,
  })
}

///|
/// Command-only view of `decode_frame_payload`, kept for callers that only
/// paint the command stream.
pub fn decode_frame(text : String) -> Array[@core.DrawCommand]? {
  match decode_frame_payload(text) {
    Some(payload) => Some(payload.commands)
    None => None
  }
}
