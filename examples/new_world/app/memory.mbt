///|
/// Character memories: what a character and the player have lived through,
/// kept apart from the card that defines who the character *is*.
///
/// The split is the product's core rule for long-running roleplay: the card
/// (`characters/<名>.md`) is the character's identity and must not drift with
/// one conversation, while the memory file (`characters/<名>.memory.md`) is
/// the shared history — editable, pinnable, deletable by the player, and only
/// ever *proposed* by the model (every proposal waits for an explicit adopt).
///
///     <library>/<world>/characters/<名>.memory.md
///
///       - 狸奴怕打雷，那夜靠我很近
///       - [固定] 答应过教她御剑，不能忘
///       - [来源:AI] 她说想去看海 ——那是她娘亲的故乡
///
/// `[固定]` marks a pinned entry (always injected into the prompt);
/// `[来源:AI]` marks a model-proposed entry the player adopted. Both markers
/// are optional on read: an unknown line is still a memory, never damage.

///|
/// Where a memory came from. `Authored` lines are written by the player (or
/// hand-edited in the file); `Adopted` lines were proposed by the model and
/// explicitly kept by the player.
pub(all) enum MemorySource {
  Authored
  Adopted
} derive(Eq, Debug)

///|
pub extend MemorySource with Debug::{to_repr}

///|
pub extend MemorySource with Eq::{not_equal, equal}

///|
/// One remembered fact about the shared history.
pub struct MemoryEntry {
  content : String
  /// Pinned entries are always injected into the prompt; the rest are pulled
  /// in by keyword relevance (`select_memories`).
  pinned : Bool
  source : MemorySource
  /// A hidden entry stays in the file and in the drawer but never reaches the
  /// model. The player writes it for themselves (or withholds it on purpose);
  /// the prompt is not the only place a memory may live.
  hidden : Bool
  /// The progression topic of this entry ("" = not a progression).
  ///
  /// A topic groups a fact that changes over time — where the apprentice
  /// lives, how badly the arm is hurt, who the character trusts now. Only the
  /// latest entry of a topic reaches the prompt; the earlier ones stay in the
  /// file as history.
  topic : String
} derive(Eq, Debug)

///|
pub extend MemoryEntry with Debug::{to_repr}

///|
pub extend MemoryEntry with Eq::{not_equal, equal}

///|
pub fn MemoryEntry::authored(content : String) -> MemoryEntry {
  { content, pinned: false, source: Authored, hidden: false, topic: "", }
}

///|
pub fn MemoryEntry::proposed(content : String) -> MemoryEntry {
  { content, pinned: false, source: Adopted, hidden: false, topic: "", }
}

///|
pub fn MemoryEntry::content(self : MemoryEntry) -> String {
  self.content
}

///|
pub fn MemoryEntry::pinned(self : MemoryEntry) -> Bool {
  self.pinned
}

///|
pub fn MemoryEntry::source(self : MemoryEntry) -> MemorySource {
  self.source
}

///|
pub fn MemoryEntry::with_pinned(
  self : MemoryEntry,
  pinned : Bool,
) -> MemoryEntry {
  { ..self, pinned, }
}

///|
/// Does this entry stay out of the prompt?
pub fn MemoryEntry::hidden(self : MemoryEntry) -> Bool {
  self.hidden
}

///|
/// Keep this entry out of the prompt (or let it back in).
pub fn MemoryEntry::with_hidden(
  self : MemoryEntry,
  hidden : Bool,
) -> MemoryEntry {
  { ..self, hidden, }
}

///|
/// The progression topic of this entry ("" = not a progression).
pub fn MemoryEntry::topic(self : MemoryEntry) -> String {
  self.topic
}

///|
/// Give this entry a progression topic.
pub fn MemoryEntry::with_topic(self : MemoryEntry, topic : String) -> MemoryEntry {
  { ..self, topic, }
}

///|
/// The memories of one character.
pub struct CharacterMemories {
  character_id : String
  entries : Array[MemoryEntry]
} derive(Eq, Debug)

///|
pub extend CharacterMemories with Debug::{to_repr}

///|
pub extend CharacterMemories with Eq::{not_equal, equal}

///|
/// Every character's memories for the current world. Mirrors
/// `ConversationBook`'s API so both books read the same way.
pub struct MemoryBook {
  entries : Array[CharacterMemories]
} derive(Eq, Debug)

///|
pub extend MemoryBook with Debug::{to_repr}

///|
pub extend MemoryBook with Eq::{not_equal, equal}

///|
pub fn MemoryBook::new() -> MemoryBook {
  { entries: [], }
}

///|
/// The memories for a character, creating an empty record on first use.
pub fn MemoryBook::for_character(
  self : MemoryBook,
  id : String,
) -> CharacterMemories {
  match self.find(id) {
    Some(memories) => memories
    None => { character_id: id, entries: [], }
  }
}

///|
pub fn MemoryBook::find(
  self : MemoryBook,
  id : String,
) -> CharacterMemories? {
  for entry in self.entries {
    if entry.character_id == id {
      return Some(entry)
    }
  }
  None
}

///|
/// Store one character's memories, replacing the record for the same id.
pub fn MemoryBook::set(self : MemoryBook, memories : CharacterMemories) -> Unit {
  let mut index = 0
  while index < self.entries.length() {
    if self.entries[index].character_id == memories.character_id {
      self.entries[index] = memories
      return
    }
    index += 1
  }
  self.entries.push(memories)
}

///|
/// A book with its own entries array. Entries are immutable values, so
/// copying the array is enough to make the two books independent.
pub fn MemoryBook::clone(self : MemoryBook) -> MemoryBook {
  let entries : Array[CharacterMemories] = []
  for entry in self.entries {
    entries.push(entry)
  }
  { entries, }
}

///|
/// Drop every memory. Used when the world itself is replaced: character ids
/// do not survive a world swap, so neither should their histories.
pub fn MemoryBook::clear(self : MemoryBook) -> Unit {
  self.entries.clear()
}

///|
/// The entries of one character's memories.
pub fn CharacterMemories::entries(self : CharacterMemories) -> Array[MemoryEntry] {
  self.entries
}

///|
pub fn CharacterMemories::character_id(
  self : CharacterMemories,
) -> String {
  self.character_id
}

// ---------------------------------------------------------------------------
// Selection: which memories ride in the next prompt.
// ---------------------------------------------------------------------------

///|
/// How many relevance-matched memories may ride in one prompt (pinned ones
/// are always in and do not count against this).
pub let memory_inject_limit : Int32 = 6

///|
/// The memories for one turn: every pinned entry first (in stored order),
/// then keyword hits (in stored order) up to `limit`. A hit is a ≥2-character
/// shared substring between the memory and what the player just said — the
/// same cheap, deterministic matching the world book uses.
///
/// Deliberately not fuzzy: the player can pin what matters, and relevance
/// only ever *adds* candidates, never replaces the pinned set.
pub fn select_memories(
  all : Array[MemoryEntry],
  player_text : String,
  limit~ : Int32 = memory_inject_limit,
) -> Array[MemoryEntry] {
  let said = player_text.trim().to_owned()
  // A progression topic keeps only its latest state: the character must
  // answer as the world is now, not as it was. The older entries stay in the
  // file (and in the drawer) as history.
  let current = latest_per_topic(all)
  let picked : Array[MemoryEntry] = []
  for entry in all {
    if entry.hidden() {
      continue
    }
    if entry.pinned() {
      picked.push(entry)
    }
  }
  if said == "" {
    return picked
  }
  let mut matched = 0
  for entry in all {
    if entry.pinned() || entry.hidden() {
      continue
    }
    if entry.topic() != "" && !current.contains(entry) {
      continue
    }
    if matched >= limit {
      break
    }
    if memory_hits(entry.content(), said) {
      picked.push(entry)
      matched += 1
    }
  }
  picked
}

///|
/// The latest entry of every progression topic (the file is time-ordered, so
/// the last one wins).
pub fn latest_per_topic(all : Array[MemoryEntry]) -> Array[MemoryEntry] {
  let latest : Array[MemoryEntry] = []
  for entry in all {
    if entry.topic() == "" {
      continue
    }
    let mut replaced = false
    for candidate in latest {
      if candidate.topic() == entry.topic() {
        replaced = true
      }
    }
    if replaced {
      // The newer entry of this topic wins: drop the older one.
      let kept : Array[MemoryEntry] = []
      for candidate in latest {
        if candidate.topic() != entry.topic() {
          kept.push(candidate)
        }
      }
      latest.clear()
      for candidate in kept {
        latest.push(candidate)
      }
    }
    latest.push(entry)
  }
  latest
}

///|
/// Does the memory share a ≥2-character slice with what the player said? The
/// memory walks its own slices and looks for them in the player's line — the
/// same cheap, deterministic matching the world book uses.
fn memory_hits(memory : String, said : String) -> Bool {
  if memory.trim() == "" {
    return false
  }
  has_shared_slice(memory, said, 2)
}

///|
/// True when both texts share a ≥2-character substring. Walks the shorter
/// text's slices; memories are short, so this stays cheap.
fn has_shared_slice(left : String, right : String, size : Int32) -> Bool {
  let chars : Array[Char] = []
  for ch in left {
    chars.push(ch)
  }
  let other : Array[Char] = []
  for ch in right {
    other.push(ch)
  }
  if chars.length() < size || other.length() < size {
    return false
  }
  let mut start = 0
  while start + size <= chars.length() {
    let needle = String::from_array(chars[start:start + size]).to_string()
    match find_substring(right, needle) {
      Some(_) => return true
      None => ()
    }
    start += 1
  }
  false
}

// ---------------------------------------------------------------------------
// Markdown codec: `characters/<名>.memory.md`.
// ---------------------------------------------------------------------------

///|
/// The folder-relative path of one character's memory file.
pub fn memory_path(character_id : String) -> String {
  "characters/" + world_folder_name(character_id) + ".memory.md"
}

///|
/// Serialize memories back to their Markdown file. The output mirrors
/// `parse_memory_md`, so save → load is lossless for every entry.
pub fn memory_md_text(entries : Array[MemoryEntry]) -> String {
  let out : Array[String] = []
  out.push("# 记忆")
  out.push("")
  if entries.is_empty() {
    out.push("<!-- 一行一条：- 内容；[固定] 表示常驻上下文 -->")
  }
  for entry in entries {
    let mut line = "- "
    if entry.pinned() {
      line += "[固定] "
    }
    if entry.source() is Adopted {
      line += "[来源:AI] "
    }
    if entry.hidden() {
      line += "[不进上下文] "
    }
    if entry.topic() != "" {
      line += "[进展:" + entry.topic() + "] "
    }
    line += entry.content()
    out.push(line)
  }
  out.push("")
  out.join("\n")
}

///|
/// Parse a memory file. Every non-empty, non-comment line is one entry;
/// unknown markers are literal text rather than damage. An empty body is a
/// valid empty memory list.
pub fn parse_memory_md(content : String) -> Array[MemoryEntry] {
  let entries : Array[MemoryEntry] = []
  for raw in file_lines(content) {
    let trimmed = raw.trim().to_owned()
    if trimmed == "" || trimmed.has_prefix("<!--") || trimmed.has_prefix("#") {
      continue
    }
    if !trimmed.has_prefix("- ") {
      continue
    }
    let mut body : String = trimmed[2:].trim().to_owned()
    let mut pinned = false
    let mut source = Authored
    let mut hidden = false
    let mut topic = ""
    // Markers may stack in either order; each is stripped once.
    let mut scanning = true
    while scanning {
      if body.has_prefix("[固定]") {
        pinned = true
        body = body[4:].trim().to_owned()
      } else if body.has_prefix("[来源:AI]") {
        source = Adopted
        body = body[7:].trim().to_owned()
      } else if body.has_prefix("[不进上下文]") {
        hidden = true
        body = body[7:].trim().to_owned()
      } else if body.has_prefix("[进展:") {
        // The topic runs to the closing bracket: `[进展:住处]`.
        let rest = body[4:].trim_start().to_owned()
        match rest.find("]") {
          Some(at) => {
            topic = rest[0:at].trim().to_owned()
            body = rest[at + 1:].trim().to_owned()
          }
          None => {
            // A broken marker stays literal text rather than eating the line.
            scanning = false
          }
        }
      } else {
        scanning = false
      }
    }
    if body != "" {
      entries.push({ content: body, pinned, source, hidden, topic, })
    }
  }
  entries
}
