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

///|
/// A ready-made archetype the creator can fill in with one click.
///
/// The point of a creation wizard (and the reason Character.AI opens with
/// suggestions rather than a blank form) is that most players freeze at an
/// empty persona box. An archetype seeds every field with something coherent
/// that the player then edits, instead of asking them to author a character
/// from nothing.
pub(all) struct CharacterArchetype {
  label : String
  name : String
  persona : String
  voice : String
  goal : String
  secret : String
} derive(Eq, Debug)

///|
pub extend CharacterArchetype with Debug::{to_repr}

///|
pub extend CharacterArchetype with Eq::{not_equal, equal}

///|
/// The built-in archetypes. Deliberately few and generic enough to fit any
/// world the player might have generated: a shopkeeper, a wanderer, an
/// authority figure, and a mystery.
pub fn creator_archetypes() -> Array[CharacterArchetype] {
  [
    CharacterArchetype::{
      label: "掌柜",
      name: "掌柜",
      persona: "在这里做了很多年生意，见过太多人，话不多但看人极准。",
      voice: "简短、沉稳，常用反问把问题推回去。",
      goal: "撑过今晚，别惹麻烦。",
      secret: "柜子底下压着一件不能见光的东西。",
    },
    CharacterArchetype::{
      label: "旅人",
      name: "旅人",
      persona: "从很远的地方来，身上有风尘味，对这里的一切都好奇。",
      voice: "直来直去，偶尔冒出一句听不懂的方言。",
      goal: "找到某个人，或者某个答案。",
      secret: "他不是第一次来这里。",
    },
    CharacterArchetype::{
      label: "官差",
      name: "官差",
      persona: "按规矩办事，问话有条理，不轻易相信任何人。",
      voice: "公事公办，句尾常带官腔。",
      goal: "把差事办完，回去交差。",
      secret: "这桩差事，他自己也心虚。",
    },
    CharacterArchetype::{
      label: "陌生人",
      name: "陌生人",
      persona: "没人知道他是谁、从哪来，只知道他一直在角落看着。",
      voice: "慢，轻，答非所问。",
      goal: "等一个信号。",
      secret: "他认识在座的某个人。",
    },
  ]
}

///|
/// Apply an archetype to a draft, keeping any name the player already typed.
pub fn CharacterDraft::with_archetype(
  self : CharacterDraft,
  archetype : CharacterArchetype,
) -> CharacterDraft {
  let name = if self.name.trim() == "" { archetype.name } else { self.name }
  {
    name,
    persona: archetype.persona,
    voice: archetype.voice,
    goal: archetype.goal,
    secret: archetype.secret,
    appearance: self.appearance,
  }
}

///|
/// The prompt pair for "describe a character in one line, get a filled card".
///
/// This is the wizard's second half: the archetypes cover "I don't know what to
/// make", this covers "I know what I want but don't want to write six fields".
pub fn character_idea_prompt(
  idea : String,
  world_name : String,
) -> (String, String) {
  let system = [
    "你是互动世界的角色设定师。根据一句话描述和一个世界名，写出一个角色。",
    "只输出一个 JSON 对象：{\"name\":\"名字\",\"persona\":\"约80字人设\",\"voice\":\"说话方式\",\"goal\":\"当前目标\",\"secret\":\"不主动说出的秘密\"}。",
    "不要输出 JSON 以外的任何文字。所有文本用中文。",
  ].join("\n")
  (system, "世界：" + world_name + "\n角色：" + idea)
}

///|
/// Parse a generated character card. Defensive like every other decoder: a
/// malformed reply yields `None` and the creator keeps what the player typed.
pub fn parse_generated_character(text : String) -> CharacterDraft? {
  let json = match extract_json_object(text) {
    Some(value) => value
    None => return None
  }
  let parsed = @json.parse(json) catch { _ => return None }
  let fields = match parsed {
    Object(values) => values
    _ => return None
  }
  let read = (key : String) => {
    match fields.get(key) {
      Some(String(value)) => value
      _ => ""
    }
  }
  let name = read("name")
  let persona = read("persona")
  if name == "" || persona == "" {
    return None
  }
  Some(CharacterDraft::{
    name,
    persona,
    appearance: read("appearance"),
    voice: read("voice"),
    goal: read("goal"),
    secret: read("secret"),
  })
}
