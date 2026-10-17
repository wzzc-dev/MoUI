///|
/// Conversation state: one bounded history per character.
///
/// Plain data (P13): the only thing that appends to a history is `update`. The
/// history is capped rather than truncated at request time only, because a
/// growing history leaks memory in a long session and makes prompt cost
/// unpredictable.

///|
/// Who said a line.
pub(all) enum Speaker {
  Player
  Character(String)
} derive(Eq, Debug, ToJson)

///|
pub extend Speaker with Debug::{to_repr}

///|
pub extend Speaker with Eq::{not_equal, equal}

///|
pub extend Speaker with ToJson::{to_json}

///|
fn speaker_role(speaker : Speaker) -> String {
  match speaker {
    Player => "user"
    Character(_) => "assistant"
  }
}

///|
// One line of dialogue.
pub struct ChatLine {
  speaker : Speaker
  text : String
} derive(Eq, Debug, ToJson)

///|
pub extend ChatLine with Debug::{to_repr}

///|
pub extend ChatLine with Eq::{not_equal, equal}

///|
pub extend ChatLine with ToJson::{to_json}

///|
pub fn ChatLine::player(text : String) -> ChatLine {
  { speaker: Player, text, }
}

///|
pub fn ChatLine::character(id : String, text : String) -> ChatLine {
  { speaker: Character(id), text, }
}

///|
pub fn ChatLine::speaker(self : ChatLine) -> Speaker {
  self.speaker
}

///|
pub fn ChatLine::text(self : ChatLine) -> String {
  self.text
}

///|
/// The role this line maps to on the wire. Player turns are `user` and every
/// character turn is `assistant`, which is what lets the transcript read as one
/// continuous exchange instead of a claim-by-witness list.
fn ChatLine::wire_role(self : ChatLine) -> String {
  speaker_role(self.speaker)
}

///|
/// Upper bound on retained lines per conversation.
pub let chat_history_limit : Int = 60

///|
/// One character's conversation.
pub struct Conversation {
  character_id : String
  lines : Array[ChatLine]
  /// Set while a reply is in flight, so the UI can show a pending state and a
  /// second request is not issued on top of the first.
  pending : Bool
  /// The compressed memory of everything that fell out of `lines` (the
  /// 60-line cap plus request-time budget trimming). Empty when none.
  summary : String
  /// How many lines had been appended in total when the summary last covered
  /// the history. Monotonic watermark against `appended`.
  summarized_upto : Int
  /// Monotonic count of appended lines, unaffected by the cap. Powers the
  /// compression trigger's "enough new lines" test.
  appended : Int
} derive(Eq, Debug)

///|
pub extend Conversation with Debug::{to_repr}

///|
pub extend Conversation with Eq::{not_equal, equal}

///|
pub fn Conversation::new(character_id~ : String) -> Conversation {
  {
    character_id,
    lines: [],
    pending: false,
    summary: "",
    summarized_upto: 0,
    appended: 0,
  }
}

///|
pub fn Conversation::character_id(self : Conversation) -> String {
  self.character_id
}

///|
pub fn Conversation::lines(self : Conversation) -> Array[ChatLine] {
  self.lines
}

///|
pub fn Conversation::pending(self : Conversation) -> Bool {
  self.pending
}

///|
/// Append one line, dropping the oldest past the cap.
pub fn Conversation::append(
  self : Conversation,
  line : ChatLine,
) -> Conversation {
  let lines : Array[ChatLine] = []
  for existing in self.lines {
    lines.push(existing)
  }
  lines.push(line)
  while lines.length() > chat_history_limit {
    ignore(lines.remove(0))
  }
  { ..self, lines, appended: self.appended + 1, }
}

///|
pub fn Conversation::with_pending(
  self : Conversation,
  pending : Bool,
) -> Conversation {
  { ..self, pending, }
}

///|
pub fn Conversation::summary(self : Conversation) -> String {
  self.summary
}

///|
pub fn Conversation::summarized_upto(self : Conversation) -> Int {
  self.summarized_upto
}

///|
pub fn Conversation::appended(self : Conversation) -> Int {
  self.appended
}

///|
/// Install a freshly compressed summary. `marker` records how many lines had
/// been appended in total, so the next compression waits for new material.
pub fn Conversation::with_summary(
  self : Conversation,
  summary : String,
  marker : Int,
) -> Conversation {
  { ..self, summary, summarized_upto: marker, }
}

///|
/// The transcript as `(role, text)` pairs, oldest first, ready for the wire.
pub fn Conversation::to_wire(self : Conversation) -> Array[(String, String)] {
  let wire : Array[(String, String)] = []
  for line in self.lines {
    wire.push((line.wire_role(), line.text))
  }
  wire
}

///|
/// Every conversation in the current scenario, keyed by character id.
pub struct ConversationBook {
  entries : Array[Conversation]
} derive(Eq, Debug)

///|
pub extend ConversationBook with Debug::{to_repr}

///|
pub extend ConversationBook with Eq::{not_equal, equal}

///|
pub fn ConversationBook::new() -> ConversationBook {
  { entries: [], }
}

///|
/// Get the conversation for a character, creating an empty one on first use.
pub fn ConversationBook::for_character(
  self : ConversationBook,
  id : String,
) -> Conversation {
  match self.find(id) {
    Some(conversation) => conversation
    None => Conversation::new(character_id=id)
  }
}

///|
pub fn ConversationBook::find(
  self : ConversationBook,
  id : String,
) -> Conversation? {
  for entry in self.entries {
    if entry.character_id == id {
      return Some(entry)
    }
  }
  None
}

///|
/// Store a conversation, replacing the one for the same character.
pub fn ConversationBook::set(
  self : ConversationBook,
  conversation : Conversation,
) -> Unit {
  let mut index = 0
  while index < self.entries.length() {
    if self.entries[index].character_id == conversation.character_id {
      self.entries[index] = conversation
      return
    }
    index += 1
  }
  self.entries.push(conversation)
}

///|
/// Drop every conversation. Used when the world itself is replaced: ids do
/// not survive a world swap, so neither should the histories.
pub fn ConversationBook::clear(self : ConversationBook) -> Unit {
  self.entries.clear()
}

///|
/// How many characters currently have a conversation with history.
pub fn ConversationBook::active_count(self : ConversationBook) -> Int {
  let mut count = 0
  for entry in self.entries {
    if !entry.lines().is_empty() {
      count += 1
    }
  }
  count
}
