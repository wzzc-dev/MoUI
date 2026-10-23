///|
/// The character being composed in the creator panel, kept as plain data.
///
/// The draft never touches the world until `update` accepts it, so a half-
/// typed card costs the model nothing. Persistence is the folder database's
/// job: the card joins the world and is committed with every other file.
///
/// v2 mirrors the six blocks of the card; the relationship's three fields
/// stay flat strings here because the editor edits them one at a time.

///|
pub(all) struct CharacterDraft {
  name : String
  persona : String
  appearance : String
  voice : String
  goal : String
  secret : String
  principles : String
  /// One example line per entry, in voice order.
  examples : Array[String]
  /// Portrait file name relative to the world folder (empty = none).
  portrait : String
  /// A ready-to-paste prompt for an image model.
  portrait_prompt : String
  /// Who the player is in this story.
  user_identity : String
  /// What the character calls the player.
  user_name : String
  /// The line the relationship does not cross.
  boundary : String
  setting : String
  opening : String
  memory_rules : String
} derive(Eq, Debug)

///|
pub extend CharacterDraft with Debug::{to_repr}

///|
pub extend CharacterDraft with Eq::{not_equal, equal}

///|
pub fn CharacterDraft::new() -> CharacterDraft {
  {
    name: "",
    persona: "",
    appearance: "",
    voice: "",
    goal: "",
    secret: "",
    principles: "",
    examples: [],
    portrait: "",
    portrait_prompt: "",
    user_identity: "",
    user_name: "",
    boundary: "",
    setting: "",
    opening: "",
    memory_rules: "",
  }
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
pub fn CharacterDraft::with_portrait(
  self : CharacterDraft,
  portrait : String,
) -> CharacterDraft {
  { ..self, portrait, }
}

///|
pub fn CharacterDraft::with_portrait_prompt(
  self : CharacterDraft,
  portrait_prompt : String,
) -> CharacterDraft {
  { ..self, portrait_prompt, }
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
pub fn CharacterDraft::with_principles(
  self : CharacterDraft,
  principles : String,
) -> CharacterDraft {
  { ..self, principles, }
}

///|
pub fn CharacterDraft::with_examples(
  self : CharacterDraft,
  examples : Array[String],
) -> CharacterDraft {
  { ..self, examples, }
}

///|
pub fn CharacterDraft::with_user_identity(
  self : CharacterDraft,
  user_identity : String,
) -> CharacterDraft {
  { ..self, user_identity, }
}

///|
pub fn CharacterDraft::with_user_name(
  self : CharacterDraft,
  user_name : String,
) -> CharacterDraft {
  { ..self, user_name, }
}

///|
pub fn CharacterDraft::with_boundary(
  self : CharacterDraft,
  boundary : String,
) -> CharacterDraft {
  { ..self, boundary, }
}

///|
pub fn CharacterDraft::with_setting(
  self : CharacterDraft,
  setting : String,
) -> CharacterDraft {
  { ..self, setting, }
}

///|
pub fn CharacterDraft::with_opening(
  self : CharacterDraft,
  opening : String,
) -> CharacterDraft {
  { ..self, opening, }
}

///|
pub fn CharacterDraft::with_memory_rules(
  self : CharacterDraft,
  memory_rules : String,
) -> CharacterDraft {
  { ..self, memory_rules, }
}

///|
/// A draft that starts from an existing card (the editor's on-ramp): every
/// field round-trips, so opening the editor and saving without edits is a
/// no-op on disk.
pub fn CharacterDraft::from_card(card : CharacterCard) -> CharacterDraft {
  let relationship = card.relationship()
  {
    name: card.name(),
    persona: card.persona(),
    appearance: card.appearance(),
    voice: card.voice(),
    goal: card.goal(),
    secret: card.secret(),
    principles: card.principles(),
    examples: card.examples(),
    portrait: card.portrait(),
    portrait_prompt: card.portrait_prompt(),
    user_identity: relationship.user_identity(),
    user_name: relationship.user_name(),
    boundary: relationship.boundary(),
    setting: card.setting(),
    opening: card.opening(),
    memory_rules: card.memory_rules(),
  }
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
    portrait=self.portrait,
    portrait_prompt=self.portrait_prompt,
    voice=self.voice,
    goal=self.goal,
    secret=self.secret,
    principles=self.principles,
    examples=self.examples,
    relationship={
      user_identity: self.user_identity,
      user_name: self.user_name,
      boundary: self.boundary,
    },
    setting=self.setting,
    opening=self.opening,
    memory_rules=self.memory_rules,
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
  principles : String
  examples : Array[String]
  user_identity : String
  user_name : String
  boundary : String
  setting : String
  opening : String
  memory_rules : String
} derive(Eq, Debug)

///|
pub extend CharacterArchetype with Debug::{to_repr}

///|
pub extend CharacterArchetype with Eq::{not_equal, equal}

///|
/// The built-in archetypes. Deliberately few and generic enough to fit any
/// world the player might have generated: a shopkeeper, a wanderer, a master,
/// an authority figure, and a mystery. Each seeds the six blocks, so a
/// one-click start is already a complete card.
pub fn creator_archetypes() -> Array[CharacterArchetype] {
  [
    CharacterArchetype::{
      label: "掌柜",
      name: "掌柜",
      persona: "在这里做了很多年生意，见过太多人，话不多但看人极准。",
      voice: "简短、沉稳，常用反问把问题推回去。",
      goal: "撑过今晚，别惹麻烦。",
      secret: "柜子底下压着一件不能见光的东西。",
      principles: "不问不说；先算账后说话。",
      examples: ["嗯，知道了。", "（把东西推过来）自己看。"],
      user_identity: "过路人",
      user_name: "客官",
      boundary: "不外借账本，不过夜留人。",
      setting: "铺子里只剩一盏灯，外头风声很紧。",
      opening: "（抬头看了你一眼）……这个点儿，买点什么？",
      memory_rules: "答应过的事必须记得；老主顾的忌讳不许忘。",
    },
    CharacterArchetype::{
      label: "旅人",
      name: "旅人",
      persona: "从很远的地方来，身上有风尘味，对这里的一切都好奇。",
      voice: "直来直去，偶尔冒出一句听不懂的方言。",
      goal: "找到某个人，或者某个答案。",
      secret: "他不是第一次来这里。",
      principles: "认路不问路；不欠人情；天黑前找到住处。",
      examples: ["我走了三十天，就为问一句话。", "（笑了）你们这儿的风都是咸的。"],
      user_identity: "同路的人",
      user_name: "朋友",
      boundary: "不喝酒，不谈钱。",
      setting: "刚在篝火旁坐下，包袱还没解开。",
      opening: "（往火里添了根柴）你也还没睡？",
      memory_rules: "走过的路、问过的人，都要记在心头。",
    },
    CharacterArchetype::{
      label: "师父",
      name: "师父",
      persona: "清心寡欲的散仙，温润如玉，冷静自持。对外人疏离，对徒弟有不轻易外露的牵挂。",
      voice: "舒缓、克制，讲道理多于讲情绪，从不提高声量。",
      goal: "护徒弟走完这一关，看她自己的心。",
      secret: "他早已算出自己命里有一劫，从没打算告诉任何人。",
      principles: "感情藏在细节里：多留一盏灯，把茶盏推近一点，却不说出口。",
      examples: [
        "此事不必急于求解。待你真正看清自己的心，再来与为师论道。",
        "（搁下书卷，抬眸看你）既来了，便坐吧。",
      ],
      user_identity: "徒弟",
      user_name: "狸奴",
      boundary: "修为上的事知无不言；自己的事一概不提。",
      setting: "夜深，清虚洞府，殿外风铃轻响，案上茶还温着。",
      opening: "温衍搁下手中的书卷，抬眸看向殿外。檐下的风铃轻轻响了两声。“这么晚了，还不歇息？”他看了你片刻，又将案上的茶盏往你面前推了推。",
      memory_rules: "答应过的事必须记得；徒弟的名字与忌口不许记错。",
    },
    CharacterArchetype::{
      label: "官差",
      name: "官差",
      persona: "按规矩办事，问话有条理，不轻易相信任何人。",
      voice: "公事公办，句尾常带官腔。",
      goal: "把差事办完，回去交差。",
      secret: "这桩差事，他自己也心虚。",
      principles: "先问后判；没有证据不动手。",
      examples: ["姓名。", "（翻开簿子）昨夜亥时，你在何处？"],
      user_identity: "当事一方的证人",
      user_name: "你",
      boundary: "规矩之外的事，一律不说。",
      setting: "公堂上灯火通明，堂外围着看热闹的人。",
      opening: "（惊堂木一响）堂下之人，报上名来。",
      memory_rules: "卷宗记过的，一句都不能差。",
    },
    CharacterArchetype::{
      label: "陌生人",
      name: "陌生人",
      persona: "没人知道他是谁、从哪来，只知道他一直在角落看着。",
      voice: "慢，轻，答非所问。",
      goal: "等一个信号。",
      secret: "他认识在座的某个人。",
      principles: "只在被问时开口；每句话都留半句。",
      examples: ["……你终于来了。", "（摇头）我不知道。"],
      user_identity: "被等待的人",
      user_name: "你",
      boundary: "不问来历，不问去处。",
      setting: "角落的光照不到他，只看得见一双很静的眼睛。",
      opening: "（他一直在角落看着，见你望过去，轻轻摇了摇头）",
      memory_rules: "等的人、等的事，一天都不能忘。",
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
    principles: archetype.principles,
    examples: archetype.examples,
    portrait: self.portrait,
    portrait_prompt: self.portrait_prompt,
    user_identity: archetype.user_identity,
    user_name: archetype.user_name,
    boundary: archetype.boundary,
    setting: archetype.setting,
    opening: archetype.opening,
    memory_rules: archetype.memory_rules,
  }
}

///|
/// The prompt pair for "describe a character in one line, get a filled card".
///
/// This is the wizard's second half: the archetypes cover "I don't know what to
/// make", this covers "I know what I want but don't want to write every field".
/// The schema mirrors the v2 card: identity, principles, voice with examples,
/// the relationship with the player, the opening situation, and the memory
/// rule the character should keep.
pub fn character_idea_prompt(
  idea : String,
  world_name : String,
) -> (String, String) {
  let system = [
    "你是互动世界的角色设定师。根据一句话描述和一个世界名，写出一个角色。",
    "只输出一个 JSON 对象：{\"name\":\"名字\",\"persona\":\"约80字人设\",\"appearance\":\"约40字外貌\",\"principles\":\"约40字行为原则\",\"voice\":\"说话方式\",\"examples\":[\"示例台词1\",\"示例台词2\"],\"relationship\":{\"user_identity\":\"玩家身份\",\"user_name\":\"角色对玩家的称呼\",\"boundary\":\"关系边界\"},\"setting\":\"当前情境\",\"opening\":\"约60字开场白\",\"goal\":\"当前目标\",\"secret\":\"不主动说出的秘密\",\"memory_rules\":\"长久记忆规则\"}。",
    "示例台词必须像角色本人说出口的话，带动作或神态也可以；开场白要能直接作为第一句对话。",
    "不要输出 JSON 以外的任何文字。所有文本用中文。",
  ].join("\n")
  (system, "世界：" + world_name + "\n角色：" + idea)
}

///|
/// Parse a generated character card. Defensive like every other decoder: a
/// malformed reply yields `None` and the creator keeps what the player typed.
/// Missing v2 keys read as empty, so an older prompt's reply still loads.
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
  let examples : Array[String] = []
  match fields.get("examples") {
    Some(Array(values)) =>
      for value in values {
        match value {
          String(line) => if line.trim() != "" { examples.push(line) }
          _ => ()
        }
      }
    _ => ()
  }
  // The relationship object is optional; a missing or wrongly-typed one
  // reads as three empty fields rather than failing the whole card.
  let rel_fields = match fields.get("relationship") {
    Some(Object(values)) => values
    _ => Map([])
  }
  fn rel_at(key : String) -> String {
    match rel_fields.get(key) {
      Some(String(value)) => value
      _ => ""
    }
  }
  Some(
    CharacterDraft::{
      name,
      persona,
      appearance: read("appearance"),
      voice: read("voice"),
      goal: read("goal"),
      secret: read("secret"),
      principles: read("principles"),
      examples,
      portrait: read("portrait"),
      portrait_prompt: read("portrait_prompt"),
      user_identity: rel_at("user_identity"),
      user_name: rel_at("user_name"),
      boundary: rel_at("boundary"),
      setting: read("setting"),
      opening: read("opening"),
      memory_rules: read("memory_rules"),
    },
  )
}
