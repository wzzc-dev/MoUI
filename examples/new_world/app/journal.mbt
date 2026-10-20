///|
/// The journal: conversations and the event log persist as JSON beside the
/// Markdown files inside one world folder.
///
///     <library>/<world>/
///       conversations.json  # {"conversations":[{"character":"…","lines":[…]}]}
///       events.json         # {"events":["最新在前，…，最旧"]}
///
/// The shape is hand-owned rather than derived from the wire enums: a line's
/// speaker serializes to the chat roles (`user` / assistant) without the
/// character id, because the id lives on the conversation entry. Every parse
/// is defensive — a damaged file degrades to "no journal" with a `valid=false`
/// signal so the world feels empty instead of broken, matching the Markdown
/// codec's tolerance rules in `world_store.mbt`.

///|
/// The suffix a branched conversation gets on disk: `林掌柜~2.json`.
///
/// Branches are *siblings on disk*, not a tree in memory: the product promise is
/// "a world is a folder of readable files", and a nested JSON tree would break
/// that. Each branch is a normal conversation file with a numbered key, so any
/// editor shows it and the player can delete one without touching the others.
pub fn branched_key(base : String, branch : Int32) -> String {
  base + "~" + branch.to_string()
}

///|
/// Split a branched key back into `(base, branch)`, or `None` for a plain key.
pub fn split_branch(key : String) -> (String, Int32)? {
  let chars : Array[Char] = []
  for ch in key {
    chars.push(ch)
  }
  let mut index = chars.length()
  while index > 0 {
    index -= 1
    if chars[index] == '~' {
      let base = String::from_array(chars[0:index]).to_string()
      let digits = String::from_array(chars[index + 1:chars.length()]).to_string()
      let number = @string.parse_int(digits) catch { _ => return None }
      if base == "" {
        return None
      }
      return Some((base, number))
    }
  }
  None
}

///|
/// File name of the legacy single-book conversation file.
///
/// New worlds store one file per character under `conversations/`, so a turn
/// only rewrites the conversation it touched. This name is still *read*: a
/// world written by an older build has its history here, and dropping it would
/// silently reset those worlds.
pub let conversations_file : String = "conversations.json"

///|
/// Folder holding one conversation file per character (new format).
pub let conversations_dir : String = "conversations"

///|
/// File name of the persisted event log.
pub let events_file : String = "events.json"

///|
/// The manifest listing which `conversations/*.json` files belong to this
/// world. A world-scope commit rewrites it; reading uses it to ignore orphaned
/// files from a world that was replaced under the same folder name.
///
/// Deliberately *not* `conversations.json`: that name is the older aggregate
/// file, and overloading it would make the index indistinguishable from a
/// legacy history at a glance.
pub let conversation_index_file : String = "conversations/_index.json"

///|
/// Path of one character's conversation file, e.g. `conversations/林掌柜.json`.
///
/// The character id doubles as the file name (same rule as `characters/*.md`),
/// so it is passed through `world_folder_name` before it becomes a path.
pub fn conversation_path(character_id : String) -> String {
  conversations_dir + "/" + world_folder_name(character_id) + ".json"
}

///|
/// One parsed journal file: the restored content plus whether the text was
/// actually valid. `valid` stays true for an absent (`""`) or empty file, so
/// only real damage produces a warning.
pub(all) struct ConversationsFile {
  conversations : Array[Conversation]
  valid : Bool
} derive(Eq, Debug)

///|
/// One parsed events file, same contract as `ConversationsFile`.
pub(all) struct EventsFile {
  events : Array[String]
  valid : Bool
} derive(Eq, Debug)

///|
pub extend ConversationsFile with Debug::{to_repr}

///|
pub extend ConversationsFile with Eq::{not_equal, equal}

///|
pub extend EventsFile with Debug::{to_repr}

///|
pub extend EventsFile with Eq::{not_equal, equal}

///|
fn json_string_of(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_array_of(value : Json?) -> Array[Json] {
  match value {
    Some(Json::Array(items)) => items
    _ => []
  }
}

///|
fn json_number_of(value : Json?) -> Double? {
  match value {
    Some(Number(number, ..)) => Some(number)
    _ => None
  }
}

///|
fn json_object_of(value : Json?) -> Map[String, Json] {
  match value {
    Some(Json::Object(fields)) => fields
    _ => Map([])
  }
}

///|
/// Serialize the whole conversation book. Entries with no lines are skipped so
/// a world that only opened a character keeps a small file.
///
/// This is the legacy aggregate format. New commits write one file per
/// character (`Conversation::to_json_text`); the aggregate stays for export
/// and for reading worlds written by older builds.
pub fn ConversationBook::to_json_text(self : ConversationBook) -> String {
  let entries : Array[Json] = []
  for conversation in self.entries {
    if conversation.lines().is_empty() {
      continue
    }
    entries.push(conversation.to_json())
  }
  let root : Map[String, Json] = { "conversations": Json::array(entries) }
  Json::object(root).stringify()
}

///|
/// Serialize one conversation, the shape stored in `conversations/<角色>.json`.
pub fn Conversation::to_json_text(self : Conversation) -> String {
  Json::object({ "conversations": Json::array([self.to_json()]) }).stringify()
}

///|
/// The JSON object for one conversation entry.
fn Conversation::to_json(self : Conversation) -> Json {
  let lines : Array[Json] = []
  for line in self.lines() {
    let role = match line.speaker() {
      Player => "user"
      Character(_) => "assistant"
    }
    let alternatives : Array[Json] = []
    for alternative in line.alternatives() {
      alternatives.push(Json::string(alternative))
    }
    let line_fields : Map[String, Json] = {
      "speaker": Json::string(role),
      "text": Json::string(line.text()),
      // Only written when the player regenerated: keeping the plain
      // `{"speaker","text"}` shape for ordinary lines keeps hand-edited files
      // readable and diffs small.
      "alternatives": Json::array(alternatives),
      "selected": Json::number(line.selected().to_double()),
    }
    lines.push(Json::object(line_fields))
  }
  let entry_fields : Map[String, Json] = {
    "character": Json::string(self.character_id()),
    "lines": Json::array(lines),
    // Optional and only written when present, so hand-edited files without
    // it keep loading.
    "summary": Json::string(self.summary()),
    // How many appended lines the summary actually covers. Without this the
    // reader had to guess, and guessing "all of them" made a partial summary
    // claim the whole history: compression then never ran again and the stale
    // summary silently stood in for lines that were never summarised.
    "summarized_upto": Json::number(self.summarized_upto().to_double()),
  }
  Json::object(entry_fields)
}

///|
/// Parse a conversations.json body. Unknown shapes, damaged entries, and
/// missing fields drop that piece alone; character ids are *not* filtered
/// here (the store knows which cards exist and warns there).
pub fn parse_conversations_json(text : String) -> ConversationsFile {
  if text.trim() == "" {
    return { conversations: [], valid: true, }
  }
  let parsed : Json = @json.parse(text) catch {
    _ => return { conversations: [], valid: false, }
  }
  let root = json_object_of(Some(parsed))
  let result : Array[Conversation] = []
  for entry in json_array_of(root.get("conversations")) {
    let fields = json_object_of(Some(entry))
    let character = match json_string_of(fields.get("character")) {
      Some(name) => name
      None => continue
    }
    let mut conversation = Conversation::new(character_id=character)
    for line_entry in json_array_of(fields.get("lines")) {
      let line_fields = json_object_of(Some(line_entry))
      let text = json_string_of(line_fields.get("text")).unwrap_or("")
      let alternatives : Array[String] = []
      for alternative in json_array_of(line_fields.get("alternatives")) {
        match json_string_of(Some(alternative)) {
          Some(value) => alternatives.push(value)
          None => ()
        }
      }
      let selected = match line_fields.get("selected") {
        Some(Number(value, ..)) => value.to_int()
        _ => 0
      }
      match json_string_of(line_fields.get("speaker")) {
        // Assistant lines belong to the owning conversation, so the id comes
        // from the entry, not the file.
        Some("assistant") =>
          conversation = conversation.append(
            restore_line(
              ChatLine::character(character, text),
              alternatives,
              selected,
            ),
          )
        Some("user") =>
          conversation = conversation.append(
            restore_line(ChatLine::player(text), alternatives, selected),
          )
        _ => continue
      }
    }
    // A restored conversation re-derives its counters: `appended` is the
    // loaded line count, and an existing summary is treated as covering all
    // of it (the compression trigger then waits for new material).
    if !conversation.lines().is_empty() {
      let summary = json_string_of(fields.get("summary")).unwrap_or("")
      let line_count = conversation.lines().length()
      let covered = if summary == "" {
        0
      } else {
        // Trust the file when it says how far the summary reaches; clamp to the
        // loaded line count so a hand-edited or truncated file cannot claim
        // coverage of lines that do not exist. Files written before this field
        // existed fall back to "covers everything loaded", which is the old
        // behaviour and the only thing they can mean.
        let recorded = match json_number_of(fields.get("summarized_upto")) {
          Some(value) => value.to_int()
          None => line_count
        }
        if recorded < 0 {
          0
        } else if recorded > line_count {
          line_count
        } else {
          recorded
        }
      }
      conversation = {
        ..conversation,
        summary,
        summarized_upto: covered,
        appended: conversation.lines().length(),
      }
      result.push(conversation)
    }
  }
  { conversations: result, valid: true, }
}

///|
/// Parse one `conversations/<角色>.json` body. Same tolerance as the aggregate
/// file: a damaged character conversation degrades alone.
pub fn parse_conversation_file(text : String) -> ConversationsFile {
  parse_conversations_json(text)
}

///|
/// Serialize the event log. `WorldModel::log` is newest-first and so is the
/// file, which keeps save → load a pure round trip.

///|
/// Is this line session chatter rather than world history?
///
/// The event log is shown *and* persisted, but "已载入「…」" and parse warnings
/// describe the act of opening the file, not something that happened in the
/// world. They stay in the UI and are filtered out of `events.json`; otherwise
/// every reload permanently appends an identical line to the player's story.
pub fn is_transient_log_line(line : String) -> Bool {
  line.has_prefix("已载入「") || line.has_prefix("世界书提示：")
}

///|
pub fn events_json_text(log : Array[String]) -> String {
  let items : Array[Json] = []
  for line in log {
    if is_transient_log_line(line) {
      continue
    }
    items.push(Json::string(line))
  }
  let root : Map[String, Json] = { "events": Json::array(items) }
  Json::object(root).stringify()
}

///|
/// Parse an events.json body.
pub fn parse_events_json(text : String) -> EventsFile {
  if text.trim() == "" {
    return { events: [], valid: true, }
  }
  let parsed : Json = @json.parse(text) catch {
    _ => return { events: [], valid: false, }
  }
  let root = json_object_of(Some(parsed))
  let result : Array[String] = []
  for item in json_array_of(root.get("events")) {
    match json_string_of(Some(item)) {
      Some(line) => result.push(line)
      None => continue
    }
  }
  { events: result, valid: true, }
}

///|
/// Re-attach persisted candidates to a line. `selected` is clamped: a file
/// hand-edited to point past the end falls back to the shown text rather than
/// trapping a swipe.
fn restore_line(
  line : ChatLine,
  alternatives : Array[String],
  selected : Int32,
) -> ChatLine {
  if alternatives.is_empty() {
    line
  } else {
    let safe = if selected < 0 || selected > alternatives.length() {
      0
    } else {
      selected
    }
    { ..line, alternatives, selected: safe, }
  }
}
