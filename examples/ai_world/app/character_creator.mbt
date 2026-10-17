///|
/// The character being composed in the creator panel, kept as plain data.
///
/// The draft never touches the world until `update` accepts it, so a half-
/// typed card costs the model nothing. Persistence is the folder database's
/// job: the card joins the world and is committed with every other file.

///|
pub(all) struct CharacterDraft {
  name : String
  persona : String
  appearance : String
  voice : String
  goal : String
  secret : String
} derive(Eq, Debug)

///|
pub extend CharacterDraft with Debug::{to_repr}

///|
pub extend CharacterDraft with Eq::{not_equal, equal}

///|
pub fn CharacterDraft::new() -> CharacterDraft {
  { name: "", persona: "", appearance: "", voice: "", goal: "", secret: "", }
}

///|
pub fn CharacterDraft::with_name(
  self : CharacterDraft,
  name : String,
) -> CharacterDraft {
  { ..self, name, }
}

///|
pub fn CharacterDraft::with_persona(
  self : CharacterDraft,
  persona : String,
) -> CharacterDraft {
  { ..self, persona, }
}

///|
pub fn CharacterDraft::with_appearance(
  self : CharacterDraft,
  appearance : String,
) -> CharacterDraft {
  { ..self, appearance, }
}

///|
pub fn CharacterDraft::with_voice(
  self : CharacterDraft,
  voice : String,
) -> CharacterDraft {
  { ..self, voice, }
}

///|
pub fn CharacterDraft::with_goal(
  self : CharacterDraft,
  goal : String,
) -> CharacterDraft {
  { ..self, goal, }
}

///|
pub fn CharacterDraft::with_secret(
  self : CharacterDraft,
  secret : String,
) -> CharacterDraft {
  { ..self, secret, }
}

///|
/// Turn the draft into a live card: identity is the card name (the folder
/// database stores one file per name), the marker colour is derived from that
/// name, and `point` comes from the free-spot helper.
pub fn CharacterDraft::to_card(
  self : CharacterDraft,
  point~ : @geometry.Point,
) -> CharacterCard {
  CharacterCard::new(
    id=self.name,
    name=self.name,
    persona=self.persona,
    appearance=self.appearance,
    voice=self.voice,
    goal=self.goal,
    secret=self.secret,
    point~,
    color=character_color(self.name),
  )
}

///|
/// A tabular free spot on the map for a newcomer: columns first, then rows,
/// so three characters never stack on the same marker.
pub fn first_free_spot(scenario : Scenario) -> @geometry.Point {
  let count = scenario.characters().length()
  let column = count % 6
  let row = count / 6
  @geometry.Point::new(
    x=60.0 + (column * 96).to_double(),
    y=70.0 + (row * 84).to_double(),
  )
}
