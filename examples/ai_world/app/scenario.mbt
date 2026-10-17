///|
/// Scenario: a playable AI world as plain data.
///
/// A scenario is a *background* (tavern, city, cultivation estate, imperial
/// court, jianghu) plus the characters who inhabit it and the world book that
/// feeds background lore into the prompt. Everything here is plain data with a
/// hand-written JSON codec in `scenario_codec.mbt`: adding a background means
/// adding a JSON file, not writing code.
///
/// The character card shape follows the SillyTavern card convention closely
/// enough that an exported card can be pasted in: persona, appearance, secret,
/// goal, and voice are the fields that actually change what a model writes.

///|
/// One place in the scene. Rects are in scenario-map logical pixels.
pub struct ScenarioLocation {
  id : String
  name : String
  /// What the model is told about this place.
  description : String
  rect : @geometry.Rect
} derive(Eq, Debug)

///|
pub extend ScenarioLocation with Debug::{to_repr}

///|
pub extend ScenarioLocation with Eq::{not_equal, equal}

///|
pub fn ScenarioLocation::new(
  id~ : String,
  name~ : String,
  description~ : String,
  rect~ : @geometry.Rect,
) -> ScenarioLocation {
  { id, name, description, rect, }
}

///|
pub fn ScenarioLocation::id(self : ScenarioLocation) -> String {
  self.id
}

///|
pub fn ScenarioLocation::name(self : ScenarioLocation) -> String {
  self.name
}

///|
pub fn ScenarioLocation::description(self : ScenarioLocation) -> String {
  self.description
}

///|
pub fn ScenarioLocation::rect(self : ScenarioLocation) -> @geometry.Rect {
  self.rect
}

///|
/// One character card.
pub struct CharacterCard {
  id : String
  name : String
  /// Who they are: drives tone, vocabulary, and behaviour.
  persona : String
  /// How they look: only used when image generation is wired later.
  appearance : String
  /// What they will not volunteer; a good reason for the player to ask twice.
  secret : String
  /// What they want right now.
  goal : String
  /// How they talk: speech pattern, verbal tics, register.
  voice : String
  /// Where they stand on the map.
  location : String
  point : @geometry.Point
  /// Colour used for their map marker.
  color : @graphics.Color
} derive(Eq, Debug)

///|
pub extend CharacterCard with Debug::{to_repr}

///|
pub extend CharacterCard with Eq::{not_equal, equal}

///|
pub fn CharacterCard::new(
  id~ : String,
  name~ : String,
  persona~ : String,
  appearance? : String,
  secret? : String,
  goal? : String,
  voice? : String,
  location? : String,
  point? : @geometry.Point,
  color? : @graphics.Color,
) -> CharacterCard {
  {
    id,
    name,
    persona,
    appearance: appearance.unwrap_or(""),
    secret: secret.unwrap_or(""),
    goal: goal.unwrap_or(""),
    voice: voice.unwrap_or(""),
    location: location.unwrap_or(""),
    point: point.unwrap_or(@geometry.Point::new(x=0.0, y=0.0)),
    color: color.unwrap_or(@graphics.Color::rgba(r=0.78, g=0.62, b=0.36)),
  }
}

///|
pub fn CharacterCard::id(self : CharacterCard) -> String {
  self.id
}

///|
pub fn CharacterCard::name(self : CharacterCard) -> String {
  self.name
}

///|
pub fn CharacterCard::persona(self : CharacterCard) -> String {
  self.persona
}

///|
pub fn CharacterCard::appearance(self : CharacterCard) -> String {
  self.appearance
}

///|
pub fn CharacterCard::secret(self : CharacterCard) -> String {
  self.secret
}

///|
pub fn CharacterCard::goal(self : CharacterCard) -> String {
  self.goal
}

///|
pub fn CharacterCard::voice(self : CharacterCard) -> String {
  self.voice
}

///|
pub fn CharacterCard::location(self : CharacterCard) -> String {
  self.location
}

///|
pub fn CharacterCard::point(self : CharacterCard) -> @geometry.Point {
  self.point
}

///|
pub fn CharacterCard::color(self : CharacterCard) -> @graphics.Color {
  self.color
}

///|
/// One world-book entry: when any of its keys appears in the conversation, its
/// content is injected into the prompt. This is the SillyTavern "world info"
/// mechanism, and it is how a scenario stays small while still reacting to what
/// the player actually says.
pub struct WorldEntry {
  /// Trigger keywords, matched case-insensitively as substrings.
  keys : Array[String]
  content : String
} derive(Eq, Debug)

///|
pub extend WorldEntry with Debug::{to_repr}

///|
pub extend WorldEntry with Eq::{not_equal, equal}

///|
pub fn WorldEntry::new(keys~ : Array[String], content~ : String) -> WorldEntry {
  { keys, content, }
}

///|
pub fn WorldEntry::keys(self : WorldEntry) -> Array[String] {
  self.keys
}

///|
pub fn WorldEntry::content(self : WorldEntry) -> String {
  self.content
}

///|
/// A whole world.
pub struct Scenario {
  id : String
  name : String
  /// The world's shared background, always included in the system prompt.
  background : String
  /// Map size in logical pixels.
  map_width : Double
  map_height : Double
  locations : Array[ScenarioLocation]
  characters : Array[CharacterCard]
  world_book : Array[WorldEntry]
} derive(Eq, Debug)

///|
pub extend Scenario with Debug::{to_repr}

///|
pub extend Scenario with Eq::{not_equal, equal}

///|
pub fn Scenario::new(
  id~ : String,
  name~ : String,
  background~ : String,
  map_width? : Double,
  map_height? : Double,
  locations? : Array[ScenarioLocation],
  characters? : Array[CharacterCard],
  world_book? : Array[WorldEntry],
) -> Scenario {
  {
    id,
    name,
    background,
    map_width: map_width.unwrap_or(640.0),
    map_height: map_height.unwrap_or(420.0),
    locations: locations.unwrap_or([]),
    characters: characters.unwrap_or([]),
    world_book: world_book.unwrap_or([]),
  }
}

///|
pub fn Scenario::id(self : Scenario) -> String {
  self.id
}

///|
pub fn Scenario::name(self : Scenario) -> String {
  self.name
}

///|
pub fn Scenario::background(self : Scenario) -> String {
  self.background
}

///|
pub fn Scenario::map_width(self : Scenario) -> Double {
  self.map_width
}

///|
pub fn Scenario::map_height(self : Scenario) -> Double {
  self.map_height
}

///|
pub fn Scenario::locations(self : Scenario) -> Array[ScenarioLocation] {
  self.locations
}

///|
pub fn Scenario::characters(self : Scenario) -> Array[CharacterCard] {
  self.characters
}

///|
pub fn Scenario::world_book(self : Scenario) -> Array[WorldEntry] {
  self.world_book
}

///|
pub fn Scenario::character(self : Scenario, id : String) -> CharacterCard? {
  for card in self.characters {
    if card.id == id {
      return Some(card)
    }
  }
  None
}

///|
pub fn Scenario::location(self : Scenario, id : String) -> ScenarioLocation? {
  for place in self.locations {
    if place.id == id {
      return Some(place)
    }
  }
  None
}

///|
/// Where a character stands: their own point when they have one, otherwise the
/// centre of the location they belong to.
pub fn Scenario::character_point(
  self : Scenario,
  id : String,
) -> @geometry.Point? {
  match self.character(id) {
    Some(card) =>
      if card.point.x != 0.0 || card.point.y != 0.0 {
        Some(card.point)
      } else {
        match self.location(card.location) {
          Some(place) => Some(rect_center(place.rect()))
          None => None
        }
      }
    None => None
  }
}

///|
/// Centre of a rect, used to place a character whose card names a location but
/// carries no explicit point.
fn rect_center(rect : @geometry.Rect) -> @geometry.Point {
  @geometry.Point::new(
    x=rect.origin.x + rect.size.width / 2.0,
    y=rect.origin.y + rect.size.height / 2.0,
  )
}
