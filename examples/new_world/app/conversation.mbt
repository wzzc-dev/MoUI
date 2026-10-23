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
/// One line of dialogue.
///
/// `alternatives` holds the other replies the model produced for the same turn
/// plus where the player is looking right now — the "swipe" affordance every
/// chat product has. `text` is always the selected alternative, so every
/// existing reader (prompt assembly, transcript rendering, export) keeps
/// working unchanged; swiping only swaps `text` and `selected`.
pub struct ChatLine {
  speaker : Speaker
  text : String
  /// Other candidates for this turn (never includes `text` itself).
  alternatives : Array[String]
  /// Index into the logical list `[text] + alternatives`, so a swipe can move
  /// left/right without losing the original answer.
  selected : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend ChatLine with Debug::{to_repr}

///|
pub extend ChatLine with Eq::{not_equal, equal}

///|
pub extend ChatLine with ToJson::{to_json}

///|
pub fn ChatLine::player(text : String) -> ChatLine {
  { speaker: Player, text, alternatives: [], selected: 0, }
}

///|
/// How the player addressed the world. Borrowed from AI Dungeon: "say" is the
/// default line of dialogue, "do" is an action the world should react to, and
/// "story" is the player narrating instead of speaking.
///
/// The intent only changes how the line is framed in the prompt and how it is
/// shown in the transcript; it never changes what is stored (a `ChatLine` is
/// still just a speaker plus text), so an old journal keeps loading.
pub(all) enum InputIntent {
  /// Plain speech: `你：…`.
  Say
  /// An action: `你 *做了…*`, which the model is told to respond to rather
  /// than answer as dialogue.
  Do
  /// Narration by the player: `（旁白）…`, which the model continues instead
  /// of replying to.
  Story
} derive(Eq, Debug)

///|
pub extend InputIntent with Debug::{to_repr}

///|
pub extend InputIntent with Eq::{not_equal, equal}

///|
/// A one-word label for the composer toggle.
pub fn InputIntent::label(self : InputIntent) -> String {
  match self {
    Say => "说"
    Do => "做"
    Story => "旁白"
  }
}

///|
pub fn ChatLine::character(id : String, text : String) -> ChatLine {
  { speaker: Character(id), text, alternatives: [], selected: 0, }
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
/// The other candidates for this turn (not including the shown text).
///
/// Together with `selected` this is the swipe model: the logical candidate
/// list is `candidate_slots()`, and keeping the shown text out of
/// `alternatives` means every reader that only cares about "what was said"
/// keeps reading `text`.
pub fn ChatLine::alternatives(self : ChatLine) -> Array[String] {
  self.alternatives
}

///|
/// Which candidate is shown (`0` = the original reply).
pub fn ChatLine::selected(self : ChatLine) -> Int32 {
  self.selected
}

///|
/// How many candidates this line has (1 when it was never regenerated).
pub fn ChatLine::candidate_count(self : ChatLine) -> Int32 {
  1 + self.alternatives.length()
}

///|
/// True when this line can be swiped.
pub fn ChatLine::has_alternatives(self : ChatLine) -> Bool {
  !self.alternatives.is_empty()
}

///|
/// Candidates in logical order: index 0 is the first-ever reply.
fn ChatLine::candidate_slots(self : ChatLine) -> Array[String] {
  // `alternatives` stores candidates 1..n; candidate 0 is whatever text was
  // showing when it was regenerated, which is preserved as `alternatives[0]`
  // only while selected > 0. To stay stable under repeated regeneration, the
  // canonical order is: `alternatives` (in insertion order) with the shown
  // text substituted at `selected`.
  let slots : Array[String] = []
  let mut index = 0
  while index < self.candidate_count() {
    if index == self.selected {
      slots.push(self.text)
    } else {
      // Map logical index -> alternatives index. Slot 0 is reserved for the
      // original reply, so when selected != 0 nothing is stored for slot 0
      // beyond `alternatives[0]`.
      let alt_index = if index == 0 { 0 } else { index - 1 }
      if alt_index < self.alternatives.length() {
        slots.push(self.alternatives[alt_index])
      }
    }
    index += 1
  }
  slots
}

///|
/// Move to another candidate, keeping `text` in sync with `selected`.
pub fn ChatLine::with_candidate(self : ChatLine, index : Int32) -> ChatLine {
  let slots = self.candidate_slots()
  if index < 0 || index >= slots.length() {
    return self
  }
  let shown = slots[index]
  // Rebuild `alternatives` so the invariant `[text] + alternatives` holds and
  // the newly shown text is no longer duplicated inside it.
  let remaining : Array[String] = []
  for slot_index, candidate in slots {
    if slot_index != index {
      remaining.push(candidate)
    }
  }
  { ..self, text: shown, alternatives: remaining, selected: index, }
}

///|
/// Add a freshly regenerated reply as a candidate and select it.
///
/// The previous reply stays reachable: a swipe back returns to it, which is
/// what makes regenerating cheap to try. The shown reply simply moves into the
/// candidate list, so repeated regeneration grows it by one each time.
pub fn ChatLine::with_alternative(self : ChatLine, text : String) -> ChatLine {
  let slots = self.candidate_slots()
  let next : Array[String] = []
  for candidate in slots {
    next.push(candidate)
  }
  next.push(text)
  let selected = next.length() - 1
  let alternatives : Array[String] = []
  let mut index = 0
  while index < next.length() - 1 {
    alternatives.push(next[index])
    index += 1
  }
  { ..self, text, alternatives, selected, }
}

///|
/// Replace this line's shown text in place, keeping the candidate list
/// consistent (an edit changes only the candidate the player is looking at).
pub fn ChatLine::with_text(self : ChatLine, text : String) -> ChatLine {
  // Editing rewrites *the candidate currently shown* and leaves the others
  // alone, so the swipe history survives an edit: the player can still flip
  // back to an earlier version after fixing a typo. `text` is by definition the
  // selected slot, and the invariant `[text] + alternatives` still holds
  // because only that slot's content changes.
  { ..self, text, }
}

///|
/// Upper bound on retained lines per conversation.
pub let chat_history_limit : Int32 = 60

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
  summarized_upto : Int32
  /// Monotonic count of appended lines, unaffected by the cap. Powers the
  /// compression trigger's "enough new lines" test.
  appended : Int32
  /// This conversation's scene atmosphere, overriding the world default.
  /// `None` = use `Scenario::mood`. Session-level and optional on disk.
  mood : SceneMood?
} derive(Eq, Debug)

///|
pub extend Conversation with Debug::{to_repr}

///|
pub extend Conversation with Eq::{not_equal, equal}

///|
pub fn Conversation::new(character_id~ : String, mood? : SceneMood) -> Conversation {
  {
    character_id,
    lines: [],
    pending: false,
    summary: "",
    summarized_upto: 0,
    appended: 0,
    mood,
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
pub fn Conversation::summarized_upto(self : Conversation) -> Int32 {
  self.summarized_upto
}

///|
pub fn Conversation::appended(self : Conversation) -> Int32 {
  self.appended
}

///|
/// Install a freshly compressed summary. `marker` records how many lines had
/// been appended in total, so the next compression waits for new material.
pub fn Conversation::with_summary(
  self : Conversation,
  summary : String,
  marker : Int32,
) -> Conversation {
  { ..self, summary, summarized_upto: marker, }
}

///|
/// This conversation's scene atmosphere, overriding the world default.
pub fn Conversation::mood(self : Conversation) -> SceneMood? {
  self.mood
}

///|
/// Override (or clear, with `None`) the scene atmosphere of this conversation.
pub fn Conversation::with_mood(
  self : Conversation,
  mood : SceneMood?,
) -> Conversation {
  { ..self, mood, }
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
/// A book with its own entries array. `Conversation` values are immutable, so
/// copying the array is enough to make the two books independent.
pub fn ConversationBook::clone(self : ConversationBook) -> ConversationBook {
  let entries : Array[Conversation] = []
  for entry in self.entries {
    entries.push(entry)
  }
  { entries, }
}

///|
/// Drop every conversation. Used when the world itself is replaced: ids do
/// not survive a world swap, so neither should the histories.
pub fn ConversationBook::clear(self : ConversationBook) -> Unit {
  self.entries.clear()
}

///|
/// How many characters currently have a conversation with history.
pub fn ConversationBook::active_count(self : ConversationBook) -> Int32 {
  let mut count = 0
  for entry in self.entries {
    if !entry.lines().is_empty() {
      count += 1
    }
  }
  count
}
