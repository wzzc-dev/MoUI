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
  /// conversations.json body; `""` when the folder has none.
  conversations_json : String
  /// events.json body; `""` when the folder has none.
  events_json : String
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
  /// Restored event log, newest first, as the model keeps it.
  events : Array[String]
  warnings : Array[String]
} derive(Eq, Debug)

///|
pub extend WorldParse with Debug::{to_repr}

///|
pub extend WorldParse with Eq::{not_equal, equal}

///|
/// Parse one world folder. `None` means "not a world": `world.md` missing, or
/// carrying no usable H1 name.
pub fn parse_world_files(files : WorldFiles) -> WorldParse? {
  let warnings : Array[String] = []
  let (name, background, locations) = parse_world_md(files.world_md, warnings)
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
  let events = parse_events_json(files.events_json)
  // A conversation pointing at a character that no longer exists drops alone,
  // with a warning — the same degrade-one-file rule as a damaged card.
  let kept : Array[Conversation] = []
  for conversation in journal.conversations {
    let character = conversation.character_id()
    if characters.filter(other => other.id() == character).length() > 0 {
      kept.push(conversation)
    } else {
      warnings.push("对话记录指向已不存在的角色：\{character}")
    }
  }
  if !journal.valid {
    warnings.push("conversations.json 无法解析——对话从空白开始")
  }
  if !events.valid {
    warnings.push("events.json 无法解析——事件从空白开始")
  }
  Some(WorldParse::{
    scenario: Scenario::new(
      id=name,
      name~,
      background~,
      locations~,
      characters~,
      world_book=entries,
    ),
    conversations: kept,
    events: events.events,
    warnings,
  })
}

///|
fn rename_card(card : CharacterCard, name : String) -> CharacterCard {
  CharacterCard::new(
    id=name,
    name~,
    persona=card.persona(),
    appearance=card.appearance(),
    voice=card.voice(),
    goal=card.goal(),
    secret=card.secret(),
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
) -> (String, String, Array[ScenarioLocation]) {
  let mut name = ""
  let background : Array[String] = []
  let locations : Array[ScenarioLocation] = []
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
  (name, background.join("\n"), locations)
}

///|
/// Parse one character card. A file with no usable H1 is rejected (the card
/// would have no stable identity); every section below it is optional.
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
      voice=section_text(sections, "说话方式"),
      goal=section_text(sections, "目标"),
      secret=section_text(sections, "秘密"),
      point=parse_point_line(section_text(sections, "位置")),
      color=character_color(name),
    ),
  )
}

///|
/// Parse one world-book line: `- 关键词 | 另一个: 内容`.
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
  let keys : Array[String] = []
  for part in head.split("|").to_array() {
    let key = part.trim().to_owned()
    if key != "" {
      keys.push(key)
    }
  }
  let content = rest.trim().to_owned()
  if keys.is_empty() || content == "" {
    return None
  }
  Some(WorldEntry::new(keys~, content~))
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
  let (name, rest) = match split_colon(body) {
    Some((name, rest)) => (name.trim().to_owned(), rest)
    None => return None
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
      id=name,
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
fn needle_length(needle : String) -> Int {
  let mut length = 0
  for _ch in needle {
    length += 1
  }
  length
}

///|
/// Start index of the first `needle` inside `text`, or `None`.
fn find_substring(text : String, needle : String) -> Int? {
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
/// A file name safe to store inside the library on any host.
fn md_safe_name(name : String) -> String {
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
      ch == '\n' {
      safe.push('_')
    } else {
      safe.push(ch)
    }
  }
  let text = String::from_array(safe).trim().to_owned()
  if text == "" {
    "未命名"
  } else {
    text
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
    let file = md_safe_name(card.name())
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
  if !self.locations().is_empty() {
    out.push("## 地点")
    out.push("")
    for place in self.locations() {
      let rect = place.rect()
      out.push(
        "- \{place.name()}: x=\{rect.origin.x} y=\{rect.origin.y} w=\{rect.size.width} h=\{rect.size.height}",
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
  let optional : Array[(String, String)] = [
    ("外貌", self.appearance()),
    ("说话方式", self.voice()),
    ("目标", self.goal()),
    ("秘密", self.secret()),
  ]
  for section in optional {
    if section.1 != "" {
      out.push("## " + section.0)
      out.push("")
      out.push(section.1)
      out.push("")
    }
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
    out.push("- \{entry.keys().join(" | ")}: \{entry.content()}")
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
