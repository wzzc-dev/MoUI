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
/// File name of the persisted conversation book.
pub let conversations_file : String = "conversations.json"

///|
/// File name of the persisted event log.
pub let events_file : String = "events.json"

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
fn json_object_of(value : Json?) -> Map[String, Json] {
  match value {
    Some(Json::Object(fields)) => fields
    _ => Map([])
  }
}

///|
/// Serialize the whole conversation book. Entries with no lines are skipped so
/// a world that only opened a character keeps a small file.
pub fn ConversationBook::to_json_text(self : ConversationBook) -> String {
  let entries : Array[Json] = []
  for conversation in self.entries {
    if conversation.lines().is_empty() {
      continue
    }
    let lines : Array[Json] = []
    for line in conversation.lines() {
      let role = match line.speaker() {
        Player => "user"
        Character(_) => "assistant"
      }
      let line_fields : Map[String, Json] = {
        "speaker": Json::string(role),
        "text": Json::string(line.text()),
      }
      lines.push(Json::object(line_fields))
    }
    let entry_fields : Map[String, Json] = {
      "character": Json::string(conversation.character_id()),
      "lines": Json::array(lines),
      // Optional and only written when present, so hand-edited files without
      // it keep loading.
      "summary": Json::string(conversation.summary()),
    }
    entries.push(Json::object(entry_fields))
  }
  let root : Map[String, Json] = { "conversations": Json::array(entries) }
  Json::object(root).stringify()
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
      match json_string_of(line_fields.get("speaker")) {
        // Assistant lines belong to the owning conversation, so the id comes
        // from the entry, not the file.
        Some("assistant") =>
          conversation = conversation.append(
            ChatLine::character(character, text),
          )
        Some("user") =>
          conversation = conversation.append(ChatLine::player(text))
        _ => continue
      }
    }
    // A restored conversation re-derives its counters: `appended` is the
    // loaded line count, and an existing summary is treated as covering all
    // of it (the compression trigger then waits for new material).
    if !conversation.lines().is_empty() {
      let summary = json_string_of(fields.get("summary")).unwrap_or("")
      let covered = if summary == "" {
        0
      } else {
        conversation.lines().length()
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
/// Serialize the event log. `WorldModel::log` is newest-first and so is the
/// file, which keeps save → load a pure round trip.
pub fn events_json_text(log : Array[String]) -> String {
  let items : Array[Json] = []
  for line in log {
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
