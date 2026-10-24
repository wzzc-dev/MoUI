///|
/// The folder database: one world = one subfolder of Markdown files.
///
///     <library>/<world>/
///       world.md            # H1 name, background prose, optional `## 地点`
///       characters/<名>.md   # one card per file, `## 人设/外貌/说话方式/目标/秘密/位置`
///       world_book.md       # list line `- 关键词 | 另一个: 内容`
///       conversations.json  # dialogue journal (journal.mbt)
///       events.json         # event log, newest first (journal.mbt)
///
/// The files ARE the database: the player edits them with any editor and the
/// world is re-read on the next open. Every parse is defensive — one damaged
/// file degrades to empty fields with a warning, and only a missing or nameless
/// `world.md` makes the folder "not a world" at all. A scenario's `id` is the
/// world folder's name, so paths never need bookkeeping in the model.

///|
/// Every file of one world folder, relative path plus content.
pub(all) struct WorldFiles {
  world_md : String
  book_md : String
  /// `(characters/<名>.md, content)` pairs in folder order.
  character_files : Array[(String, String)]
  /// `(characters/<名>.memory.md, content)` pairs — the per-character
  /// interaction memories, kept apart from the cards they belong to.
  memory_files : Array[(String, String)]
  /// Legacy aggregate history (`conversations.json`), `""` when absent.
  /// Worlds written by older builds keep every conversation here.
  conversations_json : String
  /// `(conversations/<名>.json, body)` pairs — the current per-character
  /// format, so a turn only rewrites the conversation it touched.
  conversation_files : Array[(String, String)]
  /// events.json body; `""` when the folder has none.
  events_json : String
  /// Portrait assets, `(file name, base64 bytes)`. Binary rides as base64
  /// because the host contract is text (`WorldHost::read_world` returns
  /// `Array[(String, String)]`); a portrait is a few hundred KB, so the
  /// encoding cost is irrelevant next to keeping one host contract.
  portraits : Array[(String, String)]
} derive(Eq, Debug)

///|
pub extend WorldFiles with Debug::{to_repr}

///|
pub extend WorldFiles with Eq::{not_equal, equal}

///|
/// A parsed world plus every fallback the parser had to take, so the UI can
/// tell the player which file degraded instead of failing silently.
pub struct WorldParse {
  scenario : Scenario
  /// Restored conversations, filtered to characters that still exist.
  conversations : Array[Conversation]
  /// The per-character interaction memories (empty when the folder has none).
  memories : MemoryBook
  /// Restored event log, newest first, as the model keeps it.
  events : Array[String]
  warnings : Array[String]
} derive(Eq, Debug)

///|
pub extend WorldParse with Debug::{to_repr}

///|
pub extend WorldParse with Eq::{not_equal, equal}

///|
/// Is this the name of a file the world folder owns?
///
/// The world is a folder of Markdown **plus** the JSON journal committed
/// beside it (`conversations.json`, `events.json`). This predicate is the
/// single source of truth for "what belongs to a world": hosts that filtered
/// to `.md` alone silently reset every conversation on reopen. The web host
/// mirrors the same rule in `index.html` (it cannot import MoonBit).
pub fn is_world_file_name(name : String) -> Bool {
  name.has_suffix(".md") || name.has_suffix(".json")
}

///|
/// Is this file a portrait asset of a world?
///
/// Portraits live beside the cards (`characters/<名>.png`), so the folder read
/// has to carry them: without this the UI silently loses every portrait when a
/// world is reopened from disk.
pub fn is_portrait_file_name(name : String) -> Bool {
  let lower = name.to_lower()
  lower.has_suffix(".png") ||
  lower.has_suffix(".jpg") ||
  lower.has_suffix(".jpeg") ||
  lower.has_suffix(".webp")
}

///|
/// The `data:` URI a portrait renders from, or `""` when there is no bytes.
pub fn portrait_data_uri(file_name : String, base64 : String) -> String {
  if base64 == "" {
    return ""
  }
  let mime = if file_name.to_lower().has_suffix(".png") {
    "image/png"
  } else if file_name.to_lower().has_suffix(".webp") {
    "image/webp"
  } else {
    "image/jpeg"
  }
  "data:" + mime + ";base64," + base64
}

///|
/// The portrait URI for one card, resolved against the world's assets.
pub fn portrait_uri(
  card : CharacterCard,
  portraits : Array[(String, String)],
) -> String {
  let wanted : String = card.portrait().trim().to_owned()
  if wanted == "" {
    return ""
  }
  for pair in portraits {
    let path : String = pair.0
    let suffix : String = "/" + wanted
    if path == wanted || path.has_suffix(suffix) {
      return portrait_data_uri(path, pair.1)
    }
  }
  ""
}

///|
/// Parse one world folder. `None` means "not a world": `world.md` missing, or
/// carrying no usable H1 name.
pub fn parse_world_files(files : WorldFiles) -> WorldParse? {
  let warnings : Array[String] = []
  let (name, background, locations, map_width, map_height) = parse_world_md(
    files.world_md,
    warnings,
  )
  if name == "" {
    return None
  }
  let characters : Array[CharacterCard] = []
  for pair in files.character_files {
    match parse_character_md(pair.1) {
      Some(card) => {
        let mut id = card.name()
        let mut count = 2
        while characters.filter(other => other.name() == id).length() > 0 {
          id = "\{card.name()} (\{count})"
          count += 1
        }
        characters.push(rename_card(card, id))
      }
      None => warnings.push("角色卡无法解析：\{pair.0}")
    }
  }
  // v2 worlds carry the format marker in world.md; its absence means the
  // cards were written by an older build, so the six-block fields came back
  // blank. Say so once, and say what fixes it — the editor's save upgrades
  // the folder to v2.
  if !files.world_md.contains(card_format_marker) && !characters.is_empty() {
    warnings.push(
      "这是旧版世界：角色卡缺少 行为原则/示例台词/与用户的关系/当前情境/开场白/记忆规则 等区块，已按空白载入；在角色编辑器补全并保存即升级为 v2。",
    )
  }
  // Per-character memories: `characters/<名>.memory.md`, matched to cards by
  // the sanitized name the writer produced (the same name rule the cards
  // themselves follow).
  let memories = MemoryBook::new()
  for pair in files.memory_files {
    let stem = match memory_file_stem(pair.0) {
      Some(stem) => stem
      None => continue
    }
    let mut owner = ""
    for card in characters {
      if world_folder_name(card.id()) == stem {
        owner = card.id()
        break
      }
    }
    if owner == "" {
      warnings.push("记忆文件指向已不存在的角色：\{stem}")
    } else {
      memories.set({ character_id: owner, entries: parse_memory_md(pair.1), })
    }
  }
  let entries : Array[WorldEntry] = []
  for line in file_lines(files.book_md) {
    let trimmed = line.trim().to_owned()
    if !trimmed.has_prefix("- ") {
      continue
    }
    match parse_world_book_line(line) {
      Some(entry) => entries.push(entry)
      None => warnings.push("世界书行无法解析：\{trimmed}")
    }
  }
  let journal = parse_conversations_json(files.conversations_json)
  // Per-character files ride beside the legacy aggregate. Both are read: a
  // world may have been written by either build, and a mixed folder is the
  // normal state during an upgrade.
  let per_character : Array[Conversation] = []
  let mut damaged_character_file = ""
  for pair in files.conversation_files {
    let parsed = parse_conversation_file(pair.1)
    if !parsed.valid && damaged_character_file == "" {
      damaged_character_file = pair.0
    }
    for conversation in parsed.conversations {
      per_character.push(conversation)
    }
  }
  // Per-character files win over the aggregate for the same character: they
  // are the newer copy. An id present in both is a folder mid-upgrade.
  let merged : Array[Conversation] = []
  for conversation in per_character {
    merged.push(conversation)
  }
  for conversation in journal.conversations {
    if merged
      .filter(other => other.character_id() == conversation.character_id())
      .length() ==
      0 {
      merged.push(conversation)
    }
  }
  let events = parse_events_json(files.events_json)
  // A conversation pointing at a character that no longer exists drops alone,
  // with a warning — the same degrade-one-file rule as a damaged card.
  let kept : Array[Conversation] = []
  for conversation in merged {
    let character = conversation.character_id()
    // The "orphaned conversation" rule only applies to a key that *names a
    // character*. Two kinds of key do not:
    //   - `scene:<地点>` — a multi-party transcript;
    //   - `<角色>~N`     — a branch of that character's history.
    // Both used to be dropped here, which silently deleted every scene and
    // every branch on reload. A branch survives as long as its base character
    // does, so it is resolved against its base, not against its full key.
    let anchor = match split_branch(character) {
      Some((base, _number)) => base
      None => character
    }
    let known_character = characters
      .filter(other => other.id() == anchor)
      .length() >
      0
    if is_scene_key(character) || known_character {
      kept.push(conversation)
    } else {
      warnings.push("对话记录指向已不存在的角色：\{character}")
    }
  }
  if !journal.valid {
    warnings.push("conversations.json 无法解析——对话从空白开始")
  }
  if damaged_character_file != "" {
    warnings.push("对话文件无法解析：\{damaged_character_file}")
  }
  if !events.valid {
    warnings.push("events.json 无法解析——事件从空白开始")
  }
  Some(WorldParse::{
    scenario: Scenario::new(
      id=name,
      name~,
      background~,
      map_width~,
      map_height~,
      locations~,
      characters~,
      world_book=entries,
      mood=parse_mood_section(files.world_md),
    ),
    conversations: kept,
    memories,
    events: events.events,
    warnings,
  })
}

///|
/// The format marker a v2 world.md carries. Its absence is what makes the
/// loader treat cards as legacy (blank six-block fields, one warning).
let card_format_marker : String = "- 卡档: v2"

///|
/// The world's default scene mood, read from world.md's `## 氛围` section:
///
///     ## 氛围
///     - 标题: 酒馆·夜话
///     - 时间: 夜深
///     - 心绪: calm
///
/// Every line is optional; a missing section yields the empty mood (no
/// override — the world name shows in the header instead).
fn parse_mood_section(world_md : String) -> SceneMood {
  let lines = file_lines(world_md)
  let sections = md_parse_sections(lines)
  let text = section_text(sections, "氛围")
  if text == "" {
    return SceneMood::empty()
  }
  let mut mood = SceneMood::empty()
  for raw in file_lines(text) {
    let line = raw.trim().to_owned()
    let (key, value) = match split_colon(line) {
      Some((key, value)) => (key, value.trim().to_owned())
      None => continue
    }
    if key == "标题" {
      mood = { ..mood, title: value, }
    } else if key == "时间" {
      mood = { ..mood, time_label: value, }
    } else if key == "心绪" {
      mood = { ..mood, variant: mood_from_wire(value), }
    }
  }
  mood
}

///|
/// The character-name stem of a `characters/<名>.memory.md` path, or `None`
/// for anything else. The suffix is checked before the prefix so a card
/// named "x.memory" cannot be mistaken for a memory file.
fn memory_file_stem(path : String) -> String? {
  let prefix = "characters/"
  let suffix = ".memory.md"
  if !path.has_prefix(prefix) || !path.has_suffix(suffix) {
    return None
  }
  let inner : String = path[prefix.length():path.length() - suffix.length()].to_owned()
  if inner == "" {
    None
  } else {
    Some(inner)
  }
}

///|

///|
/// Rebuild a card under a de-duplicated id.
///
/// Every field has to be copied explicitly, which is exactly why this is easy to
/// get wrong: a field added to `CharacterCard` but forgotten here is silently
/// dropped on *every* world load. `portrait_prompt` was lost that way; the v2
/// fields follow the same rule.
fn rename_card(card : CharacterCard, name : String) -> CharacterCard {
  CharacterCard::new(
    id=name,
    name~,
    persona=card.persona(),
    appearance=card.appearance(),
    portrait=card.portrait(),
    portrait_prompt=card.portrait_prompt(),
    principles=card.principles(),
    voice=card.voice(),
    examples=card.examples(),
    relationship=card.relationship(),
    setting=card.setting(),
    opening=card.opening(),
    secret=card.secret(),
    goal=card.goal(),
    memory_rules=card.memory_rules(),
    location=card.location(),
    point=card.point(),
    color=card.color(),
  )
}

///|
/// Parse `world.md`: the H1 is the name, prose until the first `##` is the
/// background (paragraph breaks kept), `## 地点` lines are
/// `- 名称: x=.. y=.. w=.. h=..`.
fn parse_world_md(
  content : String,
  warnings : Array[String],
) -> (String, String, Array[ScenarioLocation], Double, Double) {
  let mut name = ""
  let background : Array[String] = []
  let locations : Array[ScenarioLocation] = []
  let mut map_width = 640.0
  let mut map_height = 420.0
  let mut section = ""
  for raw in file_lines(content) {
    let trimmed = raw.trim().to_owned()
    if trimmed == "" {
      // Blank lines separate paragraphs; keep the marker so multi-paragraph
      // prose survives into the system prompt.
      if background.length() > 0 && background[background.length() - 1] != "" {
        background.push("")
      }
      continue
    }
    if trimmed.has_prefix("# ") && !trimmed.has_prefix("## ") {
      if name == "" {
        name = md_clean_section_header(trimmed)
      }
      section = ""
      continue
    }
    if trimmed.has_prefix("## ") {
      section = md_clean_section_header(trimmed)
      while background.length() > 0 && background[background.length() - 1] == "" {
        ignore(background.pop())
      }
      continue
    }
    if trimmed.has_prefix("#") {
      background.push("")
      continue
    }
    if section == "版本" {
      // The format marker is metadata about the file, not world prose: it
      // must never leak into the background every character remembers.
      continue
    }
    if section == "氛围" {
      // Parsed separately by `parse_mood_section`; same rule as 版本.
      continue
    }
    if section == "地图" {
      // `- 尺寸: w=640 h=420`; unparseable values keep the defaults rather than
      // collapsing the map to zero.
      if trimmed.has_prefix("- ") {
        let body : String = trimmed[2:].trim().to_owned()
        let rest = match split_colon(body) {
          Some((_head, value)) => value
          None => body
        }
        for token in rest.split(" ").to_array() {
          let token : String = token.trim().to_owned()
          if token.has_prefix("w=") {
            map_width = parse_double(token[2:].to_owned(), map_width)
          } else if token.has_prefix("h=") {
            map_height = parse_double(token[2:].to_owned(), map_height)
          }
        }
      }
      continue
    }
    if section == "地点" {
      match parse_location_line(trimmed) {
        Some(place) => locations.push(place)
        None => warnings.push("地点行无法解析：\{trimmed}")
      }
      continue
    }
    // Prose, and sections the engine does not model (the player's own notes)
    // all feed the background the characters get to remember.
    background.push(trimmed)
  }
  while background.length() > 0 && background[background.length() - 1] == "" {
    ignore(background.pop())
  }
  (name, background.join("\n"), locations, map_width, map_height)
}

///|
/// Parse one character card. A file with no usable H1 is rejected (the card
/// would have no stable identity); every section below it is optional.
///
/// v2 sections, in file order: 人设 / 行为原则 / 外貌 / 立绘 / 立绘提示词 /
/// 说话方式 / 示例台词 / 与用户的关系 / 当前情境 / 开场白 / 目标 / 秘密 /
/// 记忆规则 / 所在 / 位置. Sections an older build never wrote are simply
/// absent and read as blank — that is the v1 tolerance path.
pub fn parse_character_md(content : String) -> CharacterCard? {
  let lines = file_lines(content)
  let mut name = ""
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("# ") && !trimmed.has_prefix("## ") {
      name = md_clean_section_header(trimmed)
      break
    }
  }
  if name == "" {
    return None
  }
  let sections = md_parse_sections(lines)
  Some(
    CharacterCard::new(
      id=name,
      name~,
      persona=section_text(sections, "人设"),
      appearance=section_text(sections, "外貌"),
      portrait=section_text(sections, "立绘"),
      portrait_prompt=section_text(sections, "立绘提示词"),
      principles=section_text(sections, "行为原则"),
      voice=section_text(sections, "说话方式"),
      examples=parse_examples_section(section_text(sections, "示例台词")),
      relationship=parse_relationship_section(
        section_text(sections, "与用户的关系"),
      ),
      setting=section_text(sections, "当前情境"),
      opening=section_text(sections, "开场白"),
      goal=section_text(sections, "目标"),
      secret=section_text(sections, "秘密"),
      memory_rules=section_text(sections, "记忆规则"),
      location=section_text(sections, "所在"),
      point=parse_point_line(section_text(sections, "位置")),
      color=character_color(name),
    ),
  )
}

///|
/// Parse the `## 示例台词` body: every non-empty line is one example line, in
/// order. Blank lines and indentation are noise; the order is the voice.
fn parse_examples_section(text : String) -> Array[String] {
  let examples : Array[String] = []
  if text.trim() == "" {
    return examples
  }
  for raw in file_lines(text) {
    let line = raw.trim().to_owned()
    if line != "" && !line.has_prefix("<!--") {
      examples.push(line)
    }
  }
  examples
}

///|
/// Parse the `## 与用户的关系` body: `- 玩家身份：…` style lines, one per
/// relationship field. Unknown keys are ignored rather than failing the card;
/// a missing key simply stays empty.
fn parse_relationship_section(text : String) -> Relationship {
  if text.trim() == "" {
    return Relationship::empty()
  }
  let mut relationship = Relationship::empty()
  for raw in file_lines(text) {
    let line = raw.trim().to_owned()
    if !line.has_prefix("- ") {
      continue
    }
    let body : String = line[2:].trim().to_owned()
    let (key, value) = match split_colon(body) {
      Some((key, value)) => (key.trim().to_owned(), value.trim().to_owned())
      None => continue
    }
    if value == "" {
      continue
    }
    if key == "玩家身份" {
      relationship = { ..relationship, user_identity: value, }
    } else if key == "玩家称呼" {
      relationship = { ..relationship, user_name: value, }
    } else if key == "边界" {
      relationship = { ..relationship, boundary: value, }
    }
  }
  relationship
}

///|
/// Parse one world-book line.
///
/// Base form (still the common case, and what a hand-written file uses):
///
///     - 关键词 | 另一个: 内容
///
/// Optional modifiers sit between the keys and the colon, so the line stays one
/// readable Markdown bullet:
///
///     - 酒 | 花雕 [priority=10] [position=before] [recursion=2] [probability=60]: 内容
///
/// Every modifier is optional and order-independent; an unknown one is ignored
/// rather than rejecting the entry (a typo must not cost the player their lore).
pub fn parse_world_book_line(line : String) -> WorldEntry? {
  let trimmed = line.trim().to_owned()
  if !trimmed.has_prefix("- ") {
    return None
  }
  let body : String = trimmed[2:].trim().to_owned()
  let (head, rest) = match split_colon(body) {
    Some((head, rest)) => (head, rest)
    None => return None
  }
  let (key_text, modifiers) = strip_lore_modifiers(head)
  let keys : Array[String] = []
  for part in key_text.split("|").to_array() {
    let key = part.trim().to_owned()
    if key != "" {
      keys.push(key)
    }
  }
  let content = rest.trim().to_owned()
  if keys.is_empty() || content == "" {
    return None
  }
  let priority = lore_int(modifiers, "priority", 0)
  // A negative priority is meaningless (it would sort below "no priority" in a
  // way no author expects), so it floors at 0.
  let position = match lore_text(modifiers, "position") {
    "before" => Before
    _ => After
  }
  let recursion = lore_int(modifiers, "recursion", 0)
  let probability = lore_int(modifiers, "probability", 100)
  Some(
    WorldEntry::new(
      keys~,
      content~,
      priority=if priority < 0 { 0 } else { priority },
      position~,
      recursion=if recursion < 0 { 0 } else { recursion },
      probability=if probability < 0 {
        0
      } else if probability > 100 {
        100
      } else {
        probability
      },
    ),
  )
}

///|
/// Split `关键词 | 另一个 [priority=10]` into the key text and the `[k=v]`
/// modifiers, in either order and with any whitespace.
fn strip_lore_modifiers(head : String) -> (String, Array[(String, String)]) {
  let modifiers : Array[(String, String)] = []
  let kept : Array[String] = []
  let chars : Array[Char] = []
  for ch in head {
    chars.push(ch)
  }
  let mut index = 0
  let current : Array[Char] = []
  while index < chars.length() {
    if chars[index] == '[' {
      // Collect until the closing bracket; an unterminated one is literal text
      // rather than swallowing the rest of the line.
      let mut close = index + 1
      let mut found = false
      while close < chars.length() {
        if chars[close] == ']' {
          found = true
          break
        }
        close += 1
      }
      if found {
        let inner = String::from_array(chars[index + 1:close]).to_string()
        match split_equals(inner) {
          Some((key, value)) => modifiers.push((key, value))
          None =>
            kept.push(String::from_array(chars[index:close + 1]).to_string())
        }
        index = close + 1
        continue
      }
    }
    current.push(chars[index])
    index += 1
  }
  if !current.is_empty() {
    kept.push(String::from_array(current).to_string())
  }
  (kept.join(""), modifiers)
}

///|
fn split_equals(text : String) -> (String, String)? {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '=' {
      let key = String::from_array(chars[0:index]).to_string()
      let value = String::from_array(chars[index + 1:chars.length()]).to_string()
      let key_norm : String = key.trim().to_owned().to_lower()
      let value_norm : String = value.trim().to_owned().to_lower()
      return Some((key_norm, value_norm))
    }
    index += 1
  }
  None
}

///|
fn lore_text(modifiers : Array[(String, String)], key : String) -> String {
  for pair in modifiers {
    if pair.0 == key {
      return pair.1
    }
  }
  ""
}

///|
fn lore_int(
  modifiers : Array[(String, String)],
  key : String,
  fallback : Int32,
) -> Int32 {
  for pair in modifiers {
    if pair.0 == key {
      return @string.parse_int(pair.1) catch { _ => return fallback }
    }
  }
  fallback
}

///|
/// `- 名称: x=40 y=300 w=180 h=80：一段描述`. Bad numbers mean the rect
/// cannot be placed on the map, so the line is rejected and warned upstream.
fn parse_location_line(line : String) -> ScenarioLocation? {
  let trimmed = line.trim().to_owned()
  if !trimmed.has_prefix("- ") {
    return None
  }
  let body : String = trimmed[2:].trim().to_owned()
  let (head, rest) = match split_colon(body) {
    Some((name, rest)) => (name.trim().to_owned(), rest)
    None => return None
  }
  if head == "" {
    return None
  }
  // `吧台 id=bar` keeps a slug id that characters reference. Hand-written
  // files normally omit it, in which case the id is the display name.
  let (name, id) = match find_substring(head, " id=") {
    Some(at) => {
      let name : String = head[0:at].trim().to_owned()
      let id : String = head[at + 4:head.length()].trim().to_owned()
      if name == "" || id == "" {
        (head, head)
      } else {
        (name, id)
      }
    }
    None => (head, head)
  }
  if name == "" {
    return None
  }
  let (rect_text, description) = match split_colon(rest) {
    Some((rect_text, description)) => (rect_text, description.trim().to_owned())
    None => (rest, "")
  }
  let x = md_number_field(rect_text, "x")
  let y = md_number_field(rect_text, "y")
  let w = md_number_field(rect_text, "w")
  let h = md_number_field(rect_text, "h")
  if w <= 0.0 || h <= 0.0 {
    return None
  }
  Some(
    ScenarioLocation::new(
      id~,
      name~,
      description~,
      rect=@geometry.Rect::new(x~, y~, width=w, height=h),
    ),
  )
}

///|
/// Parse `x=320 y=210`; a missing or invalid line parks the card at the map
/// origin, which layout treats as "no spot recorded".
fn parse_point_line(line : String) -> @geometry.Point {
  @geometry.Point::new(
    x=md_number_field(line, "x"),
    y=md_number_field(line, "y"),
  )
}

///|
/// Hand-rolled numeric field reader for `x=40 y=300 w=180 h=80` style text.
/// A missing or unparseable field reads as `0.0`.
fn md_number_field(text : String, field : String) -> Double {
  let needle = field + "="
  let from = match find_substring(text, needle) {
    Some(from) => from
    None => return 0.0
  }
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  let digits : Array[Char] = []
  let mut cursor = from + needle_length(needle)
  while cursor < chars.length() {
    let ch = chars[cursor]
    if ch.is_ascii_digit() || ch == '.' || ch == '-' {
      digits.push(ch)
      cursor += 1
    } else {
      break
    }
  }
  if digits.is_empty() {
    0.0
  } else {
    @string.parse_double(String::from_array(digits).to_string()) catch {
      _ => 0.0
    }
  }
}

///|
fn needle_length(needle : String) -> Int32 {
  let mut length = 0
  for _ch in needle {
    length += 1
  }
  length
}

///|
/// Start index of the first `needle` inside `text`, or `None`.
fn find_substring(text : String, needle : String) -> Int32? {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  let pattern : Array[Char] = []
  for ch in needle {
    pattern.push(ch)
  }
  if pattern.is_empty() || chars.length() < pattern.length() {
    return None
  }
  let mut start = 0
  while start <= chars.length() - pattern.length() {
    let mut matched = true
    let mut probe = 0
    while probe < pattern.length() {
      if chars[start + probe] != pattern[probe] {
        matched = false
        break
      }
      probe += 1
    }
    if matched {
      return Some(start)
    }
    start += 1
  }
  None
}

///|
/// Split at the first full-width or ASCII colon.
fn split_colon(text : String) -> (String, String)? {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '：' || chars[index] == ':' {
      let left = String::from_array(chars[0:index])
      let right = String::from_array(chars[index + 1:chars.length()])
      return Some((left.trim().to_owned(), right))
    }
    index += 1
  }
  None
}

///|
/// Index `## 标题` sections of a card file as `(title, joined text)` pairs.
/// Paragraph breaks inside a section are kept; blank edges are trimmed.
fn md_parse_sections(lines : Array[String]) -> Array[(String, String)] {
  let sections : Array[(String, String)] = []
  let mut current = ""
  let body : Array[String] = []
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("## ") {
      if current != "" {
        sections.push((current, md_join_body(body)))
        body.clear()
      }
      current = md_clean_section_header(trimmed)
      continue
    }
    if current != "" && !trimmed.has_prefix("# ") {
      body.push(trimmed)
    }
  }
  if current != "" {
    sections.push((current, md_join_body(body)))
  }
  sections
}

///|
/// Join a section body, dropping blank lines at both edges but keeping the
/// paragraph breaks inside it.
fn md_join_body(body : Array[String]) -> String {
  let mut start = 0
  let mut end = body.length()
  while start < end && body[start] == "" {
    start += 1
  }
  while end > start && body[end - 1] == "" {
    end -= 1
  }
  let kept : Array[String] = []
  for index in start..<end {
    kept.push(body[index])
  }
  kept.join("\n")
}

///|
/// Read one `## 标题` section's text.
fn section_text(sections : Array[(String, String)], title : String) -> String {
  for section in sections {
    if section.0 == title {
      return section.1
    }
  }
  ""
}

///|
/// Drop the leading `#`/`## ` marker and trim.
fn md_clean_section_header(line : String) -> String {
  let trimmed = line.trim().to_owned()
  if trimmed.has_prefix("## ") {
    trimmed[3:].trim().to_owned()
  } else if trimmed.has_prefix("# ") {
    trimmed[2:].trim().to_owned()
  } else {
    trimmed
  }
}

///|
/// All lines of one file, whitespace-trimmed.
fn file_lines(content : String) -> Array[String] {
  content.split("\n").to_array().map(line => line.trim().to_owned())
}

///|
/// Deterministic marker colour for a name: same name → same marker.
pub fn character_color(name : String) -> @graphics.Color {
  let palette = [
    @graphics.Color::rgba(r=0.78, g=0.62, b=0.36),
    @graphics.Color::rgba(r=0.45, g=0.65, b=0.78),
    @graphics.Color::rgba(r=0.72, g=0.55, b=0.7),
    @graphics.Color::rgba(r=0.55, g=0.72, b=0.55),
    @graphics.Color::rgba(r=0.8, g=0.56, b=0.48),
    @graphics.Color::rgba(r=0.62, g=0.62, b=0.74),
  ]
  let mut hash = 5381
  for ch in name {
    hash = (hash * 33 + ch.to_int()) % 1000003
  }
  palette[hash % palette.length()]
}

///|
/// A single path component safe to store inside the library on any host.
///
/// A world folder name comes straight from player input (and, on the offline
/// path, from the one-line idea), and it is concatenated into a native path by
/// the macOS host. Anything that can escape the library root must therefore be
/// neutralised here: path separators, drive/ADS colons, the Windows reserved
/// characters, control characters, and the `..` / `.` components themselves.
/// Every world folder name goes through this before it reaches a `WorldHost`.
pub fn world_folder_name(name : String) -> String {
  let safe : Array[Char] = []
  for ch in name {
    if ch == '/' ||
      ch == '\\' ||
      ch == ':' ||
      ch == '*' ||
      ch == '?' ||
      ch == '"' ||
      ch == '<' ||
      ch == '>' ||
      ch == '|' ||
      ch == '\n' ||
      ch == '\r' ||
      ch == '\t' ||
      ch == '\u{0}' {
      safe.push('_')
    } else {
      safe.push(ch)
    }
  }
  let text = String::from_array(safe).trim().to_owned()
  // `.` and `..` are path components, not names: a world called ".." would
  // write over the library's parent. Leading dots would also hide the folder.
  let guarded = if text == "" || text == "." || text == ".." {
    "未命名"
  } else if text.has_prefix(".") {
    "_" + text
  } else {
    text
  }
  clip_folder_name(guarded)
}

///|
/// The longest folder name we will create, in UTF-8 bytes.
///
/// Most file systems cap a single path component at 255 bytes, and CJK
/// characters cost 3 bytes each, so a 500-character name would fail at write
/// time with a bare "invalid argument" the player cannot act on. Truncating
/// here keeps the failure impossible instead of surprising. 120 leaves room for
/// the `~N` disambiguation suffix and the path separator.
let folder_name_max_bytes : Int32 = 120

///|
/// The UTF-8 length of one character, so a budget in bytes can be spent
/// exactly instead of assuming the worst case for ASCII.
fn utf8_width(ch : Char) -> Int32 {
  let code = ch.to_int()
  if code < 0x80 {
    1
  } else if code < 0x800 {
    2
  } else if code < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// Truncate to a whole number of characters within the byte budget.
///
/// Cutting by *characters* rather than bytes matters: a cut mid-character would
/// produce invalid UTF-8 and a name the file system rejects anyway.
fn clip_folder_name(name : String) -> String {
  let mut bytes = 0
  let mut over = false
  for ch in name {
    bytes += utf8_width(ch)
    if bytes > folder_name_max_bytes {
      over = true
      break
    }
  }
  if !over {
    return name
  }
  let kept : Array[Char] = []
  let mut used = 0
  for ch in name {
    let width = utf8_width(ch)
    if used + width > folder_name_max_bytes {
      break
    }
    kept.push(ch)
    used += width
  }
  let clipped = String::from_array(kept)
  if clipped == "" {
    "未命名"
  } else {
    clipped
  }
}

// ---------------------------------------------------------------------------
// Writers: a world serializes back to exactly the files it is read from.
// ---------------------------------------------------------------------------

///|
/// Serialize a whole world folder. The output mirrors `parse_world_files`, so
/// save → load is lossless for every field the model owns.
pub fn Scenario::world_files(self : Scenario) -> Array[(String, String)] {
  let files : Array[(String, String)] = []
  files.push(("world.md", self.world_md()))
  for card in self.characters() {
    let file = world_folder_name(card.name())
    files.push(("characters/\{file}.md", card.character_md_text()))
  }
  files.push(("world_book.md", self.world_book_md()))
  files
}

///|
fn Scenario::world_md(self : Scenario) -> String {
  let out : Array[String] = []
  out.push("# " + self.name())
  out.push("")
  if self.background() != "" {
    out.push(self.background())
    out.push("")
  }
  // The format marker: its presence is what makes the loader read cards as
  // v2 without warning. Older worlds simply lack it.
  out.push("## 版本")
  out.push("")
  out.push(card_format_marker)
  out.push("")
  // The map size is world state, not a UI preference: without it every reload
  // resets the canvas to its default and silently shrinks a custom map.
  out.push("## 地图")
  out.push("")
  out.push("- 尺寸: w=\{self.map_width()} h=\{self.map_height()}")
  out.push("")
  // The world's default scene atmosphere, editable by hand. Only written
  // when the player actually set one, so a plain world keeps its plain shape.
  let mood = self.mood()
  if mood.title() != "" || mood.time_label() != "" {
    out.push("## 氛围")
    out.push("")
    if mood.title() != "" {
      out.push("- 标题: \{mood.title()}")
    }
    if mood.time_label() != "" {
      out.push("- 时间: \{mood.time_label()}")
    }
    if mood.title() != "" || mood.time_label() != "" {
      out.push("- 心绪: \{mood.variant().wire()}")
    }
    out.push("")
  }
  if !self.locations().is_empty() {
    out.push("## 地点")
    out.push("")
    for place in self.locations() {
      let rect = place.rect()
      out.push(
        // The description follows a second colon, which the parser already
        // understands. It was never written, so every place the player
        // described came back undescribed.
        // `id=…` is written only when the id is not simply the display name.
        // Characters reference a place by id, so dropping a slug id would leave
        // every `location` pointing at a name that no longer exists — and the
        // scene's cast silently empties on reload.
        "- \{place.name()}" +
        (if place.id() == place.name() { "" } else { " id=\{place.id()}" }) +
        ": x=\{rect.origin.x} y=\{rect.origin.y} w=\{rect.size.width} h=\{rect.size.height}" +
        (if place.description() == "" {
          ""
        } else {
          ": " + place.description()
        }),
      )
    }
    out.push("")
  }
  out.join("\n")
}

///|
pub fn CharacterCard::character_md_text(self : CharacterCard) -> String {
  let out : Array[String] = []
  out.push("# " + self.name())
  out.push("")
  out.push("## 人设")
  out.push("")
  out.push(
    if self.persona() == "" {
      "（未填写）"
    } else {
      self.persona()
    },
  )
  out.push("")
  // ② then ③ then ④⑤⑥: the file reads in the same six-block order the
  // creator form edits, so a hand-edited card and the editor agree.
  let optional : Array[(String, String)] = [
    ("行为原则", self.principles()),
    ("外貌", self.appearance()),
    // `location` is what `cast_at` uses to decide who is in a scene. Without it
    // in the file, a character whose point is outside every rect silently drops
    // out of their scene after a reload.
    ("所在", self.location()),
    ("立绘", self.portrait()),
    ("立绘提示词", self.portrait_prompt()),
    ("说话方式", self.voice()),
    ("目标", self.goal()),
    ("秘密", self.secret()),
    ("当前情境", self.setting()),
    ("开场白", self.opening()),
    ("记忆规则", self.memory_rules()),
  ]
  for section in optional {
    if section.1 != "" {
      out.push("## " + section.0)
      out.push("")
      out.push(section.1)
      out.push("")
    }
  }
  // ③ Example lines: one per line, order preserved.
  if !self.examples().is_empty() {
    out.push("## 示例台词")
    out.push("")
    for example in self.examples() {
      out.push(example)
    }
    out.push("")
  }
  // ④ Relationship: three labelled lines, written only when non-empty.
  let relationship = self.relationship()
  let relationship_lines : Array[String] = []
  if relationship.user_identity().trim() != "" {
    relationship_lines.push("- 玩家身份: \{relationship.user_identity()}")
  }
  if relationship.user_name().trim() != "" {
    relationship_lines.push("- 玩家称呼: \{relationship.user_name()}")
  }
  if relationship.boundary().trim() != "" {
    relationship_lines.push("- 边界: \{relationship.boundary()}")
  }
  if !relationship_lines.is_empty() {
    out.push("## 与用户的关系")
    out.push("")
    for line in relationship_lines {
      out.push(line)
    }
    out.push("")
  }
  if self.point().x != 0.0 || self.point().y != 0.0 {
    out.push("## 位置")
    out.push("")
    out.push("x=\{self.point().x} y=\{self.point().y}")
    out.push("")
  }
  out.join("\n")
}

///|
fn Scenario::world_book_md(self : Scenario) -> String {
  let out : Array[String] = []
  out.push("# 世界书")
  out.push("")
  if self.world_book().is_empty() {
    out.push(
      "<!-- 一行一个条目：- 关键词 | 另一个: 命中后注入上下文的内容 -->",
    )
  }
  for entry in self.world_book() {
    let keys = entry.keys().join(" | ")
    out.push("- " + keys + lore_modifier_text(entry) + ": " + entry.content())
  }
  out.push("")
  out.join("\n")
}

///|
/// The starting world a new folder gets: a name, a guiding background stub,
/// and a world book carrying its format hint as a comment.
pub fn blank_world(name : String) -> Scenario {
  Scenario::new(
    id=name,
    name~,
    background="（写下你的世界：它在哪里，正在发生什么。这几行会进入每个角色的记忆。）",
  )
}

///|
/// The `[key=value]` suffix for a world-book entry, or `""` when every field is
/// at its default. Only non-defaults are written, so an ordinary entry keeps
/// the exact one-line form it always had (and hand-edited files stay readable).
fn lore_modifier_text(entry : WorldEntry) -> String {
  let parts : Array[String] = []
  if entry.priority() != 0 {
    parts.push("[priority=" + entry.priority().to_string() + "]")
  }
  if entry.position() is Before {
    parts.push("[position=before]")
  }
  if entry.recursion() != 0 {
    parts.push("[recursion=" + entry.recursion().to_string() + "]")
  }
  if entry.probability() != 100 {
    parts.push("[probability=" + entry.probability().to_string() + "]")
  }
  if parts.is_empty() {
    ""
  } else {
    " " + parts.join(" ")
  }
}

///|
/// The folder-relative path a portrait asset is stored at.
///
/// Portraits live beside their card (`characters/<名>.png`). The read side already
/// hands back that path, so this normalises rather than re-derives: an incoming
/// path keeps its directory when it has one, and a bare file name is placed under
/// `characters/`.
pub fn portrait_world_path(path : String) -> String {
  if path.has_prefix("characters/") {
    return path
  }
  let name = world_folder_name(path)
  if is_portrait_file_name(name) {
    "characters/" + name
  } else {
    "characters/" + name + ".png"
  }
}

///|
/// Which kind of file a `characters/` path holds.
///
/// A card, its memory file, and its portrait share the directory, so the
/// prefix alone cannot separate them: a `.png` under `characters/` must reach
/// the portrait list and a `.memory.md` the memory list, or the asset is lost
/// on every world-scope write.
pub(all) enum CharacterAssetKind {
  Card
  Portrait
  Memory
  Other
}

///|
pub fn is_card_or_portrait_path(path : String) -> CharacterAssetKind {
  if !path.has_prefix("characters/") {
    return Other
  }
  if is_portrait_file_name(path) {
    Portrait
  } else if path.has_suffix(".memory.md") {
    Memory
  } else {
    Card
  }
}
