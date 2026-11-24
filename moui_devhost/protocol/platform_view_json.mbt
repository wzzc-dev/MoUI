///|
fn platform_view_property_json(property : @core.PlatformViewProperty) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["key"] = string_json(property.key)
  fields["value"] = string_json(property.value)
  Json::object(fields)
}

///|
fn platform_view_property_from_json(
  value : Json,
) -> @core.PlatformViewProperty? {
  let fields = match wire_object(Some(value)) {
    Some(fields) => fields
    None => return None
  }
  let key = match wire_string(fields.get("key")) {
    Some(value) => value
    None => return None
  }
  let value = match wire_string(fields.get("value")) {
    Some(value) => value
    None => return None
  }
  Some(@core.PlatformViewProperty::new(key~, value~))
}

///|
fn platform_view_placement_json(
  placement : @core.PlatformViewPlacement,
) -> Json {
  let properties : Array[Json] = []
  for property in placement.properties {
    properties.push(platform_view_property_json(property))
  }
  let fields : Map[String, Json] = Map([])
  fields["id"] = string_json(placement.id)
  fields["kind"] = string_json(placement.kind)
  fields["frame"] = rect_json(placement.frame)
  fields["clip"] = match placement.clip {
    Some(rect) => rect_json(rect)
    None => Json::null()
  }
  fields["properties"] = Json::array(properties)
  Json::object(fields)
}

///|
fn platform_view_placement_from_json(
  value : Json,
) -> @core.PlatformViewPlacement? {
  let fields = match wire_object(Some(value)) {
    Some(fields) => fields
    None => return None
  }
  let id = match wire_string(fields.get("id")) {
    Some(value) => value
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(value) => value
    None => return None
  }
  let frame = match rect_from_json(fields.get("frame")) {
    Some(value) => value
    None => return None
  }
  let clip = match fields.get("clip") {
    Some(Json::Null) | None => None
    Some(value) =>
      match rect_from_json(Some(value)) {
        Some(rect) => Some(rect)
        None => return None
      }
  }
  let properties : Array[@core.PlatformViewProperty] = []
  let items = match fields.get("properties") {
    Some(Json::Null) | None => []
    Some(Json::Array(items)) => items
    Some(_) => return None
  }
  for item in items {
    match platform_view_property_from_json(item) {
      Some(property) => properties.push(property)
      None => return None
    }
  }
  Some(@core.PlatformViewPlacement::new(id~, kind~, frame~, clip~, properties~))
}

///|
/// Decode an ordered platform-view placement list carried by a bridge frame.
fn platform_view_placements_from_json(
  value : Json?,
) -> Array[@core.PlatformViewPlacement]? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let placements : Array[@core.PlatformViewPlacement] = []
  for item in items {
    match platform_view_placement_from_json(item) {
      Some(placement) => placements.push(placement)
      None => return None
    }
  }
  Some(placements)
}

///|
fn platform_view_placements_to_json(
  placements : Array[@core.PlatformViewPlacement],
) -> Json {
  Json::array(placements.map(platform_view_placement_json))
}
