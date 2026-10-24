///|
/// Tavern character cards: the format the rest of the roleplay world speaks.
///
/// A Tavern card (the SillyTavern "character card" spec, v2) is a small JSON
/// document describing one character: who they are, how they talk, how the
/// scene starts, and a few example lines. SillyTavern, RisuAI, Agnai and
/// Chub all read it, and the community has tens of thousands of them.
///
/// New World's own card is richer in one way (the six blocks, the world book
/// and the portrait live in the world folder) and compatible in another: a card
/// can be exported as Tavern v2 and imported back, so a character is not
/// locked inside this app.
///
/// The spec, in short:
///
///     {
///       "spec": "chara_card_v2",
///       "spec_version": "2.0",
///       "data": {
///         "name": "…", "description": "…", "personality": "…",
///         "scenario": "…", "first_mes": "…", "mes_example": "…",
///         "creator_notes": "…", "system_prompt": "…",
///         "alternate_greetings": ["…"], "tags": ["…"]
///       }
///     }
///
/// A card is also shipped as a PNG: the same JSON sits in a `tEXt` chunk named
/// `chara`, so the picture and the card travel together.

///|
/// The name of the JSON chunk a PNG card keeps its data in.
pub let tavern_card_chunk : String = "chara"

///|
/// Export a card as a Tavern v2 JSON document.
///
/// The six blocks map onto the spec's fields: 人设 → description, 行为原则 →
/// personality, 当前情境 → scenario, 开场白 → first_mes, 示例台词 →
/// mes_example, 秘密 → creator_notes. The fields the spec has and this app
/// does not (the world book, the portrait) are left out; the ones this app
/// has and the spec does not (说话方式, 与用户的关系, 记忆规则) ride along in
/// `extensions`, so a round trip through the spec loses nothing.
pub fn tavern_v2_json(card : CharacterCard) -> String {
  let relationship = card.relationship()
  let extensions : Map[String, Json] = {
    "voice": Json::string(card.voice()),
    "user_identity": Json::string(relationship.user_identity()),
    "user_name": Json::string(relationship.user_name()),
    "boundary": Json::string(relationship.boundary()),
    "memory_rules": Json::string(card.memory_rules()),
    "appearance": Json::string(card.appearance()),
    "goal": Json::string(card.goal()),
  }
  let data : Map[String, Json] = {
    "name": Json::string(card.name()),
    "description": Json::string(card.persona()),
    "personality": Json::string(card.principles()),
    "scenario": Json::string(card.setting()),
    "first_mes": Json::string(card.opening()),
    "mes_example": Json::string(card.examples().join("\n")),
    "creator_notes": Json::string(card.secret()),
    "system_prompt": Json::string(""),
    "alternate_greetings": Json::array([]),
    "tags": Json::array([]),
    "character_version": Json::string(""),
    "extensions": Json::object(extensions),
  }
  let root : Map[String, Json] = {
    "spec": Json::string("chara_card_v2"),
    "spec_version": Json::string("2.0"),
    "data": Json::object(data),
  }
  Json::object(root).stringify()
}

///|
/// Read a Tavern card from a JSON document.
///
/// Both the v2 shape (`data` holds the fields) and the older flat shape (the
/// fields sit at the top) are accepted: half the cards in the wild are one or
/// the other, and refusing a card over its shape would be rude.
pub fn tavern_card_from_json(text : String) -> CharacterCard? {
  let payload = @json.parse(text) catch { _ => return None }
  let fields = match payload {
    Object(values) => values
    _ => return None
  }
  // v2 nests the fields under `data`; v1 keeps them at the top.
  let data = match fields.get("data") {
    Some(Object(nested)) => nested
    _ => fields
  }
  let name = json_text(data, "name")
  if name == "" {
    return None
  }
  let extensions = match data.get("extensions") {
    Some(Object(values)) => values
    _ => Map([])
  }
  let relationship = {
    user_identity: json_text(extensions, "user_identity"),
    user_name: json_text(extensions, "user_name"),
    boundary: json_text(extensions, "boundary"),
  }
  Some(
    CharacterCard::new(
      id=name,
      name=name,
      persona=json_text(data, "description"),
      principles=json_text(data, "personality"),
      setting=json_text(data, "scenario"),
      opening=json_text(data, "first_mes"),
      examples=split_examples(json_text(data, "mes_example")),
      secret=json_text(data, "creator_notes"),
      voice=json_text(extensions, "voice"),
      memory_rules=json_text(extensions, "memory_rules"),
      appearance=json_text(extensions, "appearance"),
      goal=json_text(extensions, "goal"),
      relationship~,
    ),
  )
}

///|
/// Read a Tavern card from a PNG file.
///
/// A PNG card is an ordinary PNG with one extra `tEXt` chunk: the JSON sits
/// in a chunk named `chara`. Only the chunk structure is read — the picture
/// itself is never decoded.
pub fn tavern_card_from_png(bytes : Bytes) -> CharacterCard? {
  let text = png_text_chunk(bytes, tavern_card_chunk)
  match text {
    Some(json) => tavern_card_from_json(json)
    None => None
  }
}

///|
/// The value of a `tEXt` chunk, or `None` when the file has no such chunk.
pub fn png_text_chunk(bytes : Bytes, name : String) -> String? {
  // The PNG signature: 89 50 4E 47 0D 0A 1A 0A.
  if bytes.length() < 8 {
    return None
  }
  let signature = [137, 80, 78, 71, 13, 10, 26, 10]
  let mut at = 0
  while at < 8 {
    if bytes[at].to_int() != signature[at] {
      return None
    }
    at += 1
  }
  // The chunks follow, each with a length, a type and a payload.
  let mut offset = 8
  while offset + 8 <= bytes.length() {
    let length = png_u32(bytes, offset)
    let chunk_type = png_chunk_type(bytes, offset + 4)
    let data_start = offset + 8
    let data_end = data_start + length
    if data_end > bytes.length() {
      return None
    }
    if chunk_type == "tEXt" {
      // The payload is the keyword, a zero byte, then the text.
      let mut at = data_start
      while at < data_end && bytes[at] != 0 {
        at += 1
      }
      if at < data_end {
        let keyword = png_text(bytes, data_start, at)
        if keyword == name {
          return Some(png_text(bytes, at + 1, data_end))
        }
      }
    }
    offset = data_end + 4
  }
  None
}

///|
/// A 32-bit big-endian number in a PNG chunk header.
fn png_u32(bytes : Bytes, at : Int) -> Int {
  (bytes[at].to_int() << 24) + (bytes[at + 1].to_int() << 16) +
  (bytes[at + 2].to_int() << 8) + bytes[at + 3].to_int()
}

///|
/// A PNG chunk's four-character type.
fn png_chunk_type(bytes : Bytes, at : Int) -> String {
  let mut out = ""
  for index in 0..<4 {
    out += bytes[at + index].to_int().to_char().to_string()
  }
  out
}

///|
/// A piece of a PNG chunk as text (the keyword and the payload are ASCII).
fn png_text(bytes : Bytes, from : Int, to : Int) -> String {
  let mut out = ""
  let mut at = from
  while at < to {
    let code = bytes[at].to_int()
    if code < 128 {
      out += code.to_char().to_string()
    }
    at += 1
  }
  out
}

///|
/// A string field of a JSON object, or `""`.
fn json_text(fields : Map[String, Json], key : String) -> String {
  match fields.get(key) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
/// The example lines of a card: one per line, the empty ones dropped.
fn split_examples(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed != "" {
      lines.push(trimmed)
    }
  }
  lines
}
