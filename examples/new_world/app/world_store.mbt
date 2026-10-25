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
