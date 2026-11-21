///|
/// Protocol version shared by the bridge host and every generated plugin.
/// Bump it when a wire shape or ABI contract changes; the host refuses a
/// plugin with a different version instead of guessing.
pub fn abi_version() -> Int32 {
  1
}

///|
fn wire_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn wire_array(value : Json?) -> Array[Json]? {
  match value {
    Some(Json::Array(items)) => Some(items)
    _ => None
  }
}

///|
fn wire_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) => Some(text)
    _ => None
  }
}

///|
fn wire_number(value : Json?) -> Double? {
  match value {
    Some(Json::Number(number, repr=_)) => Some(number)
    _ => None
  }
}

///|
fn wire_int(value : Json?) -> Int32? {
  match wire_number(value) {
    Some(number) => Some(number.to_int())
    None => None
  }
}

///|
fn wire_bool(value : Json?) -> Bool? {
  match value {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn wire_nullable_number(value : Json?) -> Double? {
  match value {
    Some(Json::Null) | None => None
    _ => wire_number(value)
  }
}

///|
fn number_json(value : Double) -> Json {
  Json::number(value)
}

///|
fn string_json(value : String) -> Json {
  Json::string(value)
}

///|
fn bool_json(value : Bool) -> Json {
  Json::boolean(value)
}

///|
fn color_json(color : @core.Color) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["r"] = number_json(color.r)
  fields["g"] = number_json(color.g)
  fields["b"] = number_json(color.b)
  fields["a"] = number_json(color.a)
  Json::object(fields)
}

///|
fn color_from_json(value : Json?) -> @core.Color? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let r = match wire_number(fields.get("r")) {
    Some(value) => value
    None => return None
  }
  let g = match wire_number(fields.get("g")) {
    Some(value) => value
    None => return None
  }
  let b = match wire_number(fields.get("b")) {
    Some(value) => value
    None => return None
  }
  let a = match wire_number(fields.get("a")) {
    Some(value) => value
    None => return None
  }
  Some(@core.Color::rgba(r~, g~, b~, a~))
}

///|
fn rect_json(rect : @core.Rect) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["x"] = number_json(rect.origin.x)
  fields["y"] = number_json(rect.origin.y)
  fields["width"] = number_json(rect.size.width)
  fields["height"] = number_json(rect.size.height)
  Json::object(fields)
}

///|
fn rect_from_json(value : Json?) -> @core.Rect? {
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
  let width = match wire_number(fields.get("width")) {
    Some(value) => value
    None => return None
  }
  let height = match wire_number(fields.get("height")) {
    Some(value) => value
    None => return None
  }
  Some(@core.Rect::new(x~, y~, width~, height~))
}

///|
fn rounded_rect_json(rect : @core.RoundedRect) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["rect"] = rect_json(rect.rect)
  fields["radius"] = number_json(rect.radius)
  Json::object(fields)
}

///|
fn rounded_rect_from_json(value : Json?) -> @core.RoundedRect? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let rect = match rect_from_json(fields.get("rect")) {
    Some(rect) => rect
    None => return None
  }
  let radius = match wire_number(fields.get("radius")) {
    Some(value) => value
    None => return None
  }
  Some(@core.RoundedRect::{ rect, radius, })
}

///|
/// Copy a byte range handed over by another MoonBit runtime into a String.
/// The raw pointer has no local object header, so this function indexes the
/// bytes and decodes a local buffer instead of trusting cross-runtime layout.
pub fn bytes_to_string(data : Bytes, length : Int32) -> String? {
  if length < 0 {
    return None
  }
  let copied : Array[Byte] = []
  for index in 0..<length {
    copied.push(data[index])
  }
  Some(@utf8.decode_lossy(Bytes::from_array(copied)[:], ignore_bom=true))
}
