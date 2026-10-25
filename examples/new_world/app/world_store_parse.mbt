///|
/// Markdown and folder-name primitives for the world-folder codec.
/// They read and sanitize what `world_store.mbt` parses and writes.

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
