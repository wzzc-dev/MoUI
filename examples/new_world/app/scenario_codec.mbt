///|
/// Scenario JSON codec.
///
/// Hand-written rather than derived. `@geometry.Rect`, `@geometry.Point`, and
/// `@graphics.Color` implement `ToJson` but not `FromJson`, so a derived codec
/// cannot read a scenario back. Writing the codec by hand also decouples the
/// persisted shape from framework internals: renaming a `core` field must not
/// silently change what a scenario file means.
///
/// Every decode is defensive. A missing or malformed field falls back to a
/// sensible default rather than rejecting the whole file, because one bad
/// character should not cost the player their world.

///|
/// Encode a scenario for persistence or export.
pub fn Scenario::to_json(self : Scenario) -> String {
  let root : Map[String, Json] = {
    "id": Json::string(self.id),
    "name": Json::string(self.name),
    "background": Json::string(self.background),
    "map_width": Json::number(self.map_width),
    "map_height": Json::number(self.map_height),
    "locations": Json::array(self.locations.map(place => location_json(place))),
    "characters": Json::array(self.characters.map(card => character_json(card))),
    "world_book": Json::array(
      self.world_book.map(entry => world_entry_json(entry)),
    ),
    "mood": mood_json(self.mood()),
  }
  @json.to_json(Json::object(root)).stringify()
}

///|
/// Decode a scenario. A malformed file falls back to the built-in default so a
/// bad import can never block startup.
pub fn Scenario::from_json(text : String) -> Scenario {
  Scenario::try_from_json(text).unwrap_or(default_scenario())
}

///|
fn decode_scenario(payload : Json) -> Scenario raise {
  let fields = match payload {
    Object(values) => values
    _ => raise Failure("scenario must be an object")
  }
  let locations = match fields.get("locations") {
    Some(Array(values)) => values
    _ => []
  }
  let characters = match fields.get("characters") {
    Some(Array(values)) => values
    _ => []
  }
  let world_book = match fields.get("world_book") {
    Some(Array(values)) => values
    _ => []
  }
  Scenario::new(
    id=json_string(fields.get("id"), "id"),
    name=json_string(fields.get("name"), "name"),
    background=json_string(fields.get("background"), "background"),
    map_width=json_double(fields.get("map_width"), 640.0),
    map_height=json_double(fields.get("map_height"), 420.0),
    locations=locations.map(value => decode_location(value)),
    characters=characters.map(value => decode_character(value)),
    world_book=world_book.map(value => decode_world_entry(value)),
    mood=match fields.get("mood") {
      Some(value) => decode_mood(value)
      None => SceneMood::empty()
    },
  )
}

///|
/// Decode a scene mood. Every field is optional; a malformed object yields
/// the empty mood rather than rejecting the scenario.
fn decode_mood(payload : Json) -> SceneMood {
  let fields = match payload {
    Object(values) => values
    _ => return SceneMood::empty()
  }
  let title = match fields.get("title") {
    Some(Json::String(text)) => text
    _ => ""
  }
  let time_label = match fields.get("time_label") {
    Some(Json::String(text)) => text
    _ => ""
  }
  let variant = match fields.get("variant") {
    Some(Json::String(text)) => mood_from_wire(text)
    _ => Calm
  }
  { title, time_label, variant, }
}

///|
fn decode_location(payload : Json) -> ScenarioLocation raise {
  let fields = match payload {
    Object(values) => values
    _ => raise Failure("location must be an object")
  }
  ScenarioLocation::new(
    id=json_string(fields.get("id"), "id"),
    name=json_string(fields.get("name"), "name"),
    description=json_string(fields.get("description"), "description"),
    rect=json_rect(fields.get("rect")),
  )
}

///|
fn decode_character(payload : Json) -> CharacterCard raise {
  let fields = match payload {
    Object(values) => values
    _ => raise Failure("character must be an object")
  }
  CharacterCard::new(
    id=json_string(fields.get("id"), "id"),
    name=json_string(fields.get("name"), "name"),
    persona=json_string(fields.get("persona"), "persona"),
    appearance=json_optional_string(fields.get("appearance")),
    portrait=json_optional_string(fields.get("portrait")),
    portrait_prompt=json_optional_string(fields.get("portrait_prompt")),
    principles=json_optional_string(fields.get("principles")),
    voice=json_optional_string(fields.get("voice")),
    examples=decode_string_array(fields.get("examples")),
    relationship=match fields.get("relationship") {
      Some(value) => decode_relationship(value)
      None => Relationship::empty()
    },
    setting=json_optional_string(fields.get("setting")),
    opening=json_optional_string(fields.get("opening")),
    secret=json_optional_string(fields.get("secret")),
    goal=json_optional_string(fields.get("goal")),
    memory_rules=json_optional_string(fields.get("memory_rules")),
    location=json_optional_string(fields.get("location")),
    point=json_point(fields.get("point")),
    color=json_color(fields.get("color")),
  )
}

///|
/// Decode a relationship object. Absent or wrongly-typed fields stay empty,
/// so a v1 character JSON still loads.
fn decode_relationship(payload : Json) -> Relationship {
  let fields = match payload {
    Object(values) => values
    _ => return Relationship::empty()
  }
  {
    user_identity: match fields.get("user_identity") {
      Some(Json::String(text)) => text
      _ => ""
    },
    user_name: match fields.get("user_name") {
      Some(Json::String(text)) => text
      _ => ""
    },
    boundary: match fields.get("boundary") {
      Some(Json::String(text)) => text
      _ => ""
    },
  }
}

///|
/// Decode a JSON array of strings, dropping anything that is not one.
fn decode_string_array(value : Json?) -> Array[String] {
  let items : Array[String] = []
  match value {
    Some(Json::Array(values)) =>
      for entry in values {
        match entry {
          Json::String(text) => items.push(text)
          _ => ()
        }
      }
    _ => ()
  }
  items
}

///|
fn decode_world_entry(payload : Json) -> WorldEntry raise {
  let fields = match payload {
    Object(values) => values
    _ => raise Failure("world entry must be an object")
  }
  let keys = match fields.get("keys") {
    Some(Array(values)) => values.map(value => json_string(Some(value), "key"))
    _ => []
  }
  // The modifiers are optional; a world written before they existed decodes to
  // the same defaults the constructor uses.
  let priority = match fields.get("priority") {
    Some(Number(value, ..)) => value.to_int()
    _ => 0
  }
  let position = match fields.get("position") {
    Some(String(value)) => if value == "before" { Before } else { After }
    _ => After
  }
  let recursion = match fields.get("recursion") {
    Some(Number(value, ..)) => value.to_int()
    _ => 0
  }
  let probability = match fields.get("probability") {
    Some(Number(value, ..)) => value.to_int()
    _ => 100
  }
  WorldEntry::new(
    keys~,
    content=json_string(fields.get("content"), "content"),
    priority~,
    position~,
    recursion~,
    probability~,
  )
}

// ---------------------------------------------------------------------------
// Encoders
// ---------------------------------------------------------------------------

///|
fn location_json(place : ScenarioLocation) -> Json {
  let rect = place.rect()
  let origin : Map[String, Json] = {
    "x": Json::number(rect.origin.x),
    "y": Json::number(rect.origin.y),
  }
  let size : Map[String, Json] = {
    "width": Json::number(rect.size.width),
    "height": Json::number(rect.size.height),
  }
  let rect_json : Map[String, Json] = {
    "origin": Json::object(origin),
    "size": Json::object(size),
  }
  let root : Map[String, Json] = {
    "id": Json::string(place.id()),
    "name": Json::string(place.name()),
    "description": Json::string(place.description()),
    "rect": Json::object(rect_json),
  }
  Json::object(root)
}

///|
fn character_json(card : CharacterCard) -> Json {
  let point = card.point()
  let color = card.color()
  let point_json : Map[String, Json] = {
    "x": Json::number(point.x),
    "y": Json::number(point.y),
  }
  let color_json : Map[String, Json] = {
    "r": Json::number(color.r),
    "g": Json::number(color.g),
    "b": Json::number(color.b),
    "a": Json::number(color.a),
  }
  let relationship = card.relationship()
  let relationship_json : Map[String, Json] = {
    "user_identity": Json::string(relationship.user_identity()),
    "user_name": Json::string(relationship.user_name()),
    "boundary": Json::string(relationship.boundary()),
  }
  let root : Map[String, Json] = {
    "id": Json::string(card.id()),
    "name": Json::string(card.name()),
    "persona": Json::string(card.persona()),
    "appearance": Json::string(card.appearance()),
    "portrait": Json::string(card.portrait()),
    "portrait_prompt": Json::string(card.portrait_prompt()),
    "principles": Json::string(card.principles()),
    "voice": Json::string(card.voice()),
    "examples": Json::array(card.examples().map(line => Json::string(line))),
    "relationship": Json::object(relationship_json),
    "setting": Json::string(card.setting()),
    "opening": Json::string(card.opening()),
    "secret": Json::string(card.secret()),
    "goal": Json::string(card.goal()),
    "memory_rules": Json::string(card.memory_rules()),
    "location": Json::string(card.location()),
    "point": Json::object(point_json),
    "color": Json::object(color_json),
  }
  Json::object(root)
}

///|
fn world_entry_json(entry : WorldEntry) -> Json {
  // Only non-default modifiers are written, mirroring the Markdown writer, so a
  // plain entry keeps its plain shape.
  let root : Map[String, Json] = {
    "keys": Json::array(entry.keys().map(key => Json::string(key))),
    "content": Json::string(entry.content()),
  }
  if entry.priority() != 0 {
    root["priority"] = Json::number(entry.priority().to_double())
  }
  if entry.position() is Before {
    root["position"] = Json::string("before")
  }
  if entry.recursion() != 0 {
    root["recursion"] = Json::number(entry.recursion().to_double())
  }
  if entry.probability() != 100 {
    root["probability"] = Json::number(entry.probability().to_double())
  }
  Json::object(root)
}

// ---------------------------------------------------------------------------
// Defensive field readers
// ---------------------------------------------------------------------------

///|
/// Read a JSON file as a usable scenario, or `None` when it is not one.
/// `from_json` uses this with the built-in default as its fallback; the AI
/// generation flow uses it directly because a failed generation must be
/// reported, never silently replaced by the reference world.
pub fn Scenario::try_from_json(text : String) -> Scenario? {
  let parsed = @json.parse(text) catch { _ => return None }
  let scenario = decode_scenario(parsed) catch { _ => return None }
  Some(scenario)
}

///|
/// Read a string, raising when the field is missing or wrongly typed so the
/// caller's `catch` falls back to the default scenario.
fn json_string(value : Json?, label : String) -> String raise {
  match value {
    Some(Json::String(text)) => text
    _ => raise Failure(label + " must be a string")
  }
}

///|

///|
/// Read an optional string: absent or wrongly-typed yields `""` rather than
/// rejecting the file, because a card with only a name and a persona is still
/// a usable card.
fn json_optional_string(value : Json?) -> String {
  match value {
    Some(Json::String(text)) => text
    _ => ""
  }
}

///|
fn json_double(value : Json?, fallback : Double) -> Double {
  match value {
    Some(Json::Number(number, repr=_)) => number
    _ => fallback
  }
}

///|
fn json_point(payload : Json?) -> @geometry.Point {
  let fields = match payload {
    Some(Json::Object(values)) => values
    _ => return @geometry.Point::new(x=0.0, y=0.0)
  }
  @geometry.Point::new(
    x=json_double(fields.get("x"), 0.0),
    y=json_double(fields.get("y"), 0.0),
  )
}

///|
fn json_rect(payload : Json?) -> @geometry.Rect raise {
  let fields = match payload {
    Some(Json::Object(values)) => values
    _ => return @geometry.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)
  }
  let origin = match fields.get("origin") {
    Some(Json::Object(values)) => values
    _ => raise Failure("rect.origin must be an object")
  }
  let size = match fields.get("size") {
    Some(Json::Object(values)) => values
    _ => raise Failure("rect.size must be an object")
  }
  @geometry.Rect::new(
    x=json_double(origin.get("x"), 0.0),
    y=json_double(origin.get("y"), 0.0),
    width=json_double(size.get("width"), 0.0),
    height=json_double(size.get("height"), 0.0),
  )
}

///|
fn json_color(payload : Json?) -> @graphics.Color {
  let fields = match payload {
    Some(Json::Object(values)) => values
    _ => return @graphics.Color::rgba(r=0.78, g=0.62, b=0.36)
  }
  @graphics.Color::rgba(
    r=json_double(fields.get("r"), 0.78),
    g=json_double(fields.get("g"), 0.62),
    b=json_double(fields.get("b"), 0.36),
    a=json_double(fields.get("a"), 1.0),
  )
}
