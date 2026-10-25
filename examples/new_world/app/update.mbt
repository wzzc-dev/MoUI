///|
/// Message handling.
///
/// Every state change happens here and only here (P13). A world lives in one
/// folder of the player's library; all folder IO is injected through
/// `WorldHost`, all provider IO through `TurnRunner` — `update` only prepares
/// requests and consumes typed results, so a failed turn or a failed save is a
/// cosmetic event rather than a corrupted world.

///|
pub struct WorldModel {
  scenario : Scenario
  conversations : ConversationBook
  /// Per-character interaction memories (the shared history), kept apart
  /// from the cards. Saved as `characters/<名>.memory.md` beside them.
  memories : MemoryBook
  config : ModelConfig
  /// The character the player is currently talking to.
  selected : String?
  /// The composer's three fields (说 / 做 / 旁白). Each field frames its own
  /// line, and one send composes the non-empty ones in order. Session UI state:
  /// switching characters or scenes starts a fresh turn.
  say_draft : String
  do_draft : String
  story_draft : String
  /// The composer's beat field: the note of what happens next in the scene.
  beat_draft : String
  /// A Tavern character card the player pasted in, waiting to be read.
  card_import_text : String
  /// The world book's working copy: the entries the player is editing.
  ///
  /// The world book is a file of its own (`world_book.md`), and until the
  /// player saves, the edits live here and nowhere else.
  world_book_draft : Array[WorldEntry]
  /// Which entry of the world book is open in the editor (-1 = none).
  world_book_edit : Int32
  /// How many transcript lines the stage shows at once. The transcript is
  /// windowed so a long run costs the same as a short one; the player reveals
  /// older lines when they want them.
  transcript_window : Int32
  /// The composer's active intent: the single input field writes into the
  /// matching draft, and the collapsed composer sends that intent only.
  composer_mode : InputIntent
  /// Whether the composer is expanded into the three-field (combined) form.
  /// Collapsed is the default: one field, one intent, one line at the foot of
  /// the stage.
  composer_expanded : Bool
  /// Whether the composer's intent menu is open.
  composer_menu : Bool
  /// Newest-first log of provider/host events, so a failed turn is diagnosable.
  log : Array[String]
  /// World folders discovered in the library.
  worlds : Array[String]
  /// The world folder currently on stage.
  current : String?
  /// Which generation of the world is on stage. Every provider request
  /// captures the value it was issued under; a completion from an older world
  /// is dropped instead of landing in the new one (character ids and scene
  /// keys are only meaningful within one generation).
  world_epoch : Int32
  /// The host told us there is no library yet (no folder picked).
  library_missing : Bool
  /// The new-world name being typed.
  world_name : String
  /// The character being composed.
  creator_open : Bool
  creator_draft : CharacterDraft
  /// The one-line idea for AI world generation.
  idea : String
  generating : Bool
  /// Which top-level page is on stage.
  page : Page
  /// Which side drawer is open (`None` = none). Session UI state: the drawer
  /// is a way of *looking* at the world, never a way of changing it silently.
  drawer : DrawerKind?
  /// Which history line's "more" menu is open (`None` = none). Session UI
  /// state, like the drawer.
  message_menu : Int32?
  /// Whether the character rail is visible on medium/compact layouts, where
  /// it cannot sit beside the stage permanently.
  rail_open : Bool
  /// Whether the full-screen atmosphere view (the scenario map as backdrop)
  /// is on stage.
  atmosphere : Bool
  /// Whether the low-interference map backdrop paints behind the transcript.
  backdrop : Bool
  /// The six-block character editor. `editor_target` is the card being
  /// edited (`None` = closed); the draft and the example-lines buffer are
  /// the editor's own working copy — nothing reaches the card without
  /// `SaveCharacter`.
  editor_open : Bool
  editor_target : String?
  editor_draft : CharacterDraft
  editor_tab : Int32
  editor_examples : String
  /// The library config.json applied at least once (so the one-time read
  /// rides on the library listing arriving, past the boot race).
  config_file_loaded : Bool
  /// Long-term-memory entries proposed by the provider, awaiting the
  /// player's accept / discard decision. Nothing reaches the world book
  /// without that decision — the curated lore file stays the author's.
  memory_drafts : Array[WorldEntry]
  /// Whether the settings page shows the API key in clear text. Session UI
  /// state only; the key itself is never persisted either way.
  api_key_revealed : Bool
  /// The history line being edited (`None` = not editing), plus its buffer.
  /// Transient UI state: an edit only reaches the world on commit.
  editing_line : Int32?
  edit_buffer : String
  /// The one-line character idea in the creation wizard.
  character_idea : String
  /// The "要记住的事" input in the memory drawer. Session UI state: an
  /// uncommitted line costs nothing.
  memory_input : String
  /// The progression topic of the memory being written ("" = a plain fact).
  ///
  /// Two memories with the same topic are two states of the same thing; only
  /// the newer one reaches the prompt, so a fact can change over time.
  memory_topic_input : String
  /// Portrait assets of the current world: `(file name, base64)` as read from
  /// the folder. Cached in the model because rendering must not do IO.
  portraits : Array[(String, String)]
  /// The location whose scene is on stage (`None` = private chat mode).
  ///
  /// A scene reuses the conversation book under `scene:<地点>` and keeps
  /// `selected` as "who answers next", so switching modes never rewrites a
  /// private chat.
  scene_location : String?
} derive(Eq, Debug)

///|
pub extend WorldModel with Debug::{to_repr}

///|
pub extend WorldModel with Eq::{not_equal, equal}

///|
pub fn WorldModel::new() -> WorldModel {
  {
    scenario: blank_world("新世界"),
    conversations: ConversationBook::new(),
    memories: MemoryBook::new(),
    config: ModelConfig::new(),
    selected: None,
    say_draft: "",
    do_draft: "",
    story_draft: "",
    beat_draft: "",
    transcript_window: transcript_window_default,
    card_import_text: "",
    world_book_draft: [],
    world_book_edit: -1,
    composer_mode: Say,
    composer_expanded: false,
    composer_menu: false,
    log: [],
    worlds: [],
    current: None,
    world_epoch: 0,
    library_missing: false,
    world_name: "",
    creator_open: false,
    creator_draft: CharacterDraft::new(),
    idea: "",
    generating: false,
    page: Main,
    drawer: None,
    message_menu: None,
    rail_open: false,
    atmosphere: false,
    backdrop: false,
    editor_open: false,
    editor_target: None,
    editor_draft: CharacterDraft::new(),
    editor_tab: 0,
    editor_examples: "",
    config_file_loaded: false,
    memory_drafts: [],
    api_key_revealed: false,
    editing_line: None,
    edit_buffer: "",
    character_idea: "",
    memory_input: "",
    memory_topic_input: "",
    portraits: [],
    scene_location: None,
  }
}

///|
pub fn WorldModel::scenario(self : WorldModel) -> Scenario {
  self.scenario
}

///|

///|
pub fn WorldModel::config(self : WorldModel) -> ModelConfig {
  self.config
}

///|
/// The character the player is currently talking to, if any.
pub fn WorldModel::selected(self : WorldModel) -> String? {
  self.selected
}

///|
pub fn WorldModel::log(self : WorldModel) -> Array[String] {
  self.log
}

///|
/// World folder names discovered in the library.
pub fn WorldModel::worlds(self : WorldModel) -> Array[String] {
  self.worlds
}

///|
/// The world folder currently on stage.
pub fn WorldModel::current(self : WorldModel) -> String? {
  self.current
}

///|
/// Which generation of the world is on stage. Bumped every time the stage is
/// replaced (open, create, import, regenerate the whole world).
pub fn WorldModel::world_epoch(self : WorldModel) -> Int32 {
  self.world_epoch
}

///|
/// True when the host reports no library root at all.
pub fn WorldModel::library_missing(self : WorldModel) -> Bool {
  self.library_missing
}

///|
/// The world folder the world was opened from matches `id` on every save.
pub fn WorldModel::creator_open(self : WorldModel) -> Bool {
  self.creator_open
}

///|
pub fn WorldModel::creator_draft(self : WorldModel) -> CharacterDraft {
  self.creator_draft
}

///|
pub fn WorldModel::idea(self : WorldModel) -> String {
  self.idea
}

///|
pub fn WorldModel::generating(self : WorldModel) -> Bool {
  self.generating
}

///|
/// Memory entries proposed by the provider, pending a decision.
pub fn WorldModel::memory_drafts(self : WorldModel) -> Array[WorldEntry] {
  self.memory_drafts
}

///|
/// Whether the settings page renders the key in clear text.
pub fn WorldModel::api_key_revealed(self : WorldModel) -> Bool {
  self.api_key_revealed
}

///|
/// The location whose scene is on stage, if any.
pub fn WorldModel::scene_location(self : WorldModel) -> String? {
  self.scene_location
}

///|
/// Is the stage showing a multi-character scene?
pub fn WorldModel::in_scene(self : WorldModel) -> Bool {
  self.scene_location is Some(_)
}

///|
/// The cast of the current scene (empty when not in a scene).
pub fn WorldModel::scene_cast(self : WorldModel) -> Array[CharacterCard] {
  match self.scene_location {
    Some(location) => cast_at(self.scenario, location)
    None => []
  }
}

///|
/// The conversation the composer targets: the scene transcript in scene mode,
/// otherwise the selected character's private chat.
pub fn WorldModel::active_conversation_key(self : WorldModel) -> String? {
  match self.scene_location {
    Some(location) => Some(scene_key(location))
    None => self.selected
  }
}

///|
/// Portrait assets of the current world.
pub fn WorldModel::portraits(self : WorldModel) -> Array[(String, String)] {
  self.portraits
}

///|
/// The portrait `data:` URI for one card, or `""` when it has none.
pub fn WorldModel::portrait_for(
  self : WorldModel,
  card : CharacterCard,
) -> String {
  portrait_uri(card, self.portraits)
}

///|
/// The one-line character idea in the creation wizard.
pub fn WorldModel::character_idea(self : WorldModel) -> String {
  self.character_idea
}

///|
/// The composer's 说【】 field.
pub fn WorldModel::say_draft(self : WorldModel) -> String {
  self.say_draft
}

///|
/// The composer's 做【】 field.
pub fn WorldModel::do_draft(self : WorldModel) -> String {
  self.do_draft
}

///|
/// The composer's 旁白【】 field.
pub fn WorldModel::story_draft(self : WorldModel) -> String {
  self.story_draft
}

///|
/// The composer's beat field (the note of what happens next in the scene).
pub fn WorldModel::beat_draft(self : WorldModel) -> String {
  self.beat_draft
}

///|
/// How many transcript lines the stage shows at once.
pub fn WorldModel::transcript_window(self : WorldModel) -> Int32 {
  self.transcript_window
}

///|
/// Can the composer send right now? Any non-empty field counts as content.
pub fn WorldModel::composer_ready(self : WorldModel) -> Bool {
  composer_has_content(self.say_draft, self.do_draft, self.story_draft)
}

///|
/// The composer's active intent (the collapsed form's one field).
pub fn WorldModel::composer_mode(self : WorldModel) -> InputIntent {
  self.composer_mode
}

///|
/// Whether the composer is in the three-field (combined) form.
pub fn WorldModel::composer_expanded(self : WorldModel) -> Bool {
  self.composer_expanded
}

///|
/// Whether the composer's intent menu is open.
pub fn WorldModel::composer_menu(self : WorldModel) -> Bool {
  self.composer_menu
}

///|
/// The history line being edited, if any.
pub fn WorldModel::editing_line(self : WorldModel) -> Int32? {
  self.editing_line
}

///|
/// The text currently in the inline editor.
pub fn WorldModel::edit_buffer(self : WorldModel) -> String {
  self.edit_buffer
}

///|
/// Replace the whole conversation for one character with a new line list.
///
/// Editing a history line re-derives the conversation from its line array; a
/// helper keeps that inside the app (the book is keyed by character id, and a
/// stale key must never create a second entry).
fn set_lines(
  model : WorldModel,
  character_id : String,
  lines : Array[ChatLine],
) -> Unit {
  let current = model.conversations.for_character(character_id)
  let mut rebuilt = Conversation::new(character_id~)
  for line in lines {
    rebuilt = rebuilt.append(line)
  }
  model.conversations.set({
    ..current,
    lines: rebuilt.lines(),
    // Editing history does not change the rolling-summary watermark; only
    // the line list (and its appended counter) is re-derived.
    appended: rebuilt.appended(),
    pending: false,
  })
}

///|
/// The generated reply for a turn: the line to regenerate, if the last line of
/// the conversation is a character line.
fn last_reply_index(conversation : Conversation) -> Int32? {
  let lines = conversation.lines()
  if lines.is_empty() {
    return None
  }
  let index = lines.length() - 1
  match lines[index].speaker() {
    Character(_) => Some(index)
    Player => None
  }
}

///|
pub fn WorldModel::world_name(self : WorldModel) -> String {
  self.world_name
}

///|
/// Which top-level page is on stage.
pub fn WorldModel::page(self : WorldModel) -> Page {
  self.page
}

///|
/// Which side drawer is open, if any.
pub fn WorldModel::drawer(self : WorldModel) -> DrawerKind? {
  self.drawer
}

///|
/// Which history line's "more" menu is open, if any.
pub fn WorldModel::message_menu(self : WorldModel) -> Int32? {
  self.message_menu
}

///|
/// Whether the character rail is visible (medium/compact only).
pub fn WorldModel::rail_open(self : WorldModel) -> Bool {
  self.rail_open
}

///|
/// Whether the full-screen atmosphere view is on stage.
pub fn WorldModel::atmosphere(self : WorldModel) -> Bool {
  self.atmosphere
}

///|
/// Whether the map backdrop paints behind the transcript.
pub fn WorldModel::backdrop(self : WorldModel) -> Bool {
  self.backdrop
}

///|
/// Whether the character editor is open.
pub fn WorldModel::editor_open(self : WorldModel) -> Bool {
  self.editor_open
}

///|
/// Which card the editor is working on (`None` = closed).
pub fn WorldModel::editor_target(self : WorldModel) -> String? {
  self.editor_target
}

///|
/// The editor's working draft.
pub fn WorldModel::editor_draft(self : WorldModel) -> CharacterDraft {
  self.editor_draft
}

///|
/// Which block of the editor is visible.
pub fn WorldModel::editor_tab(self : WorldModel) -> Int32 {
  self.editor_tab
}

///|
/// The example-lines buffer (one line per example).
pub fn WorldModel::editor_examples(self : WorldModel) -> String {
  self.editor_examples
}

///|
/// The memory drawer's input line.

///|
/// Does the editor's draft still differ from the card it was opened on?
pub fn WorldModel::editor_dirty(self : WorldModel) -> Bool {
  match self.editor_target {
    None => false
    Some(id) =>
      match self.scenario.character(id) {
        None => false
        Some(card) => self.editor_draft.differs_from(card)
      }
  }
}

///|
/// A Tavern character card the player pasted in, waiting to be read.
pub fn WorldModel::card_import_text(self : WorldModel) -> String {
  self.card_import_text
}

///|
/// The world book's working copy: the entries being edited.
pub fn WorldModel::world_book_draft(self : WorldModel) -> Array[WorldEntry] {
  self.world_book_draft
}

///|
/// Which world-book entry is open in the editor (-1 = none).
pub fn WorldModel::world_book_edit(self : WorldModel) -> Int32 {
  self.world_book_edit
}

///|
/// The progression topic of the memory being written ("" = a plain fact).
pub fn WorldModel::memory_topic_input(self : WorldModel) -> String {
  self.memory_topic_input
}

///|
pub fn WorldModel::memory_input(self : WorldModel) -> String {
  self.memory_input
}

///|
/// Performs one provider turn: the request plus a completion callback.
///
/// The platform entrypoint injects the native/web worker here. Without one, no
/// turn is ever started, which is exactly the behaviour a test build needs.
pub type TurnRunner = (LlmRequest, (String?) -> Unit, (String) -> Unit) -> Unit

///|
/// Host capability for the folder database (the player's library). Same
/// injection style as `TurnRunner`: the platform entrypoint owns the IO.
///
/// The file set a host must return from `read_world` is a contract, not a
/// detail: `world.md`, `characters/<名>.md`, `world_book.md`, and the journal
/// (`conversations.json`, `events.json`) when present. Hosts that filter to
/// `*.md` alone look correct but silently reset every conversation on reopen,
/// so both entrypoints read the JSON files too.
pub(all) struct WorldHost {
  /// Non-interactive listing of the world folders in the library.
  list_worlds : ((Array[String]) -> Unit) -> Unit
  /// Interactive root selection (web directory picker, native path chooser).
  pick_root : ((Array[String]) -> Unit) -> Unit
  /// Read every file of one world folder; `false` means the folder or the
  /// library could not be read.
  read_world : (String, (Bool, Array[(String, String)]) -> Unit) -> Unit
  /// Write every file of one world folder, creating it when missing.
  write_world : (String, Array[(String, String)], (Bool) -> Unit) -> Unit
  /// Read a file at the library root (`config.json`); `None` when missing
  /// or the library is not available yet.
  read_config : ((String?) -> Unit) -> Unit
  /// Write a file at the library root.
  write_config : (String, (Bool) -> Unit) -> Unit
  /// Export one world as a single self-contained bundle file the player picks
  /// a home for. `(suggested file name, bundle text)`: the app owns the
  /// format, the host only chooses a path and writes the text.
  /// `false` means the player cancelled or the write failed.
  export_world : (String, String, (Bool) -> Unit) -> Unit
  /// Ask the player for a bundle file and hand back its raw text. Decoding is
  /// the app's job, so every host reads the same format; extracting and
  /// writing the world's files reuses `write_world`.
  import_world : ((Bool, String) -> Unit) -> Unit
  /// Put text on the clipboard, so the prompt preview can be carried to
  /// another tool.
  copy_to_clipboard : (String) -> Unit
} derive(Debug)

///|
pub extend WorldHost with Debug::{to_repr}

///|
/// Append one log line, newest first, capped so the panel stays bounded.
pub fn WorldModel::push_log(self : WorldModel, line : String) -> Unit {
  self.log.insert(0, line)
  while self.log.length() > world_log_limit {
    ignore(self.log.pop())
  }
}

///|
/// Maximum retained log lines.
pub let world_log_limit : Int32 = 40

///|
/// Start a new model value whose mutable containers are **not** shared with
/// the previous one.
///
/// `{ ..model, }` copies the record but keeps the same `Array` references, so
/// `push_log` / `ConversationBook::set` / `memory_drafts.push` would mutate
/// the model that was passed in. `update` is supposed to be a pure
/// `(Model, Msg) -> (Model, Effect)`, and tests that keep both values would
/// otherwise observe edits "through" the old one. The runtime happens not to
/// diff models today, which is exactly why this must not be load-bearing:
/// every branch that mutates a container starts from `model.fork()`.
pub fn WorldModel::fork(self : WorldModel) -> WorldModel {
  {
    ..self,
    log: self.log.copy(),
    worlds: self.worlds.copy(),
    memory_drafts: self.memory_drafts.copy(),
    portraits: self.portraits.copy(),
    conversations: self.conversations.clone(),
    memories: self.memories.clone(),
  }
}

///|
/// Append the player's line to a conversation, returning the updated state.
fn append_player(
  model : WorldModel,
  character_id : String,
  text : String,
) -> Unit {
  let conversation = model.conversations.for_character(character_id)
  model.conversations.set(conversation.append(ChatLine::player(text)))
}

///|
/// Append a character's line to a conversation.
fn append_reply(
  model : WorldModel,
  character_id : String,
  text : String,
) -> Unit {
  let conversation = model.conversations.for_character(character_id)
  model.conversations.set(
    conversation
    .append(ChatLine::character(character_id, text))
    .with_pending(false)
    // The finished line replaces the streamed text.
    .with_streaming(""),
  )
}

///|
/// Append a scene reply spoken by `respondent_id`.
///
/// The line's `Speaker::Character` carries the actual speaker, so a scene
/// transcript can mix voices while still being one conversation.
fn append_scene_reply(
  model : WorldModel,
  key : String,
  respondent_id : String,
  text : String,
) -> Unit {
  let conversation = model.conversations.for_character(key)
  model.conversations.set(
    conversation
    .append(ChatLine::character(respondent_id, text))
    .with_pending(false)
    .with_streaming(""),
  )
}

///|
/// Fold one streamed piece into a conversation that is still waiting for it.
///
/// Deltas are provider callbacks: by the time one lands the turn may have
/// finished (the full reply arrived first), the character may be gone, or the
/// world may have been replaced. None of those may create a conversation or
/// edit the model the caller still holds, so the guard runs before `fork()`.
fn append_reply_delta(
  model : WorldModel,
  key : String,
  delta : String,
  scene~ : Bool,
) -> (WorldModel, @moui.Effect[Msg]) {
  // The private and scene channels stay separate: a delta addressed to a
  // character id must not land in a scene transcript, or vice versa.
  if is_scene_key(key) != scene {
    return (model, @moui.Effect::none())
  }
  let waiting = match model.conversations.find(key) {
    Some(conversation) =>
      conversation.pending() && reply_target_exists(model, key)
    None => false
  }
  if !waiting {
    return (model, @moui.Effect::none())
  }
  let conversation = model.conversations.for_character(key)
  let next = model.fork()
  next.conversations.set(
    conversation.with_streaming(conversation.streaming() + delta),
  )
  (next, @moui.Effect::none())
}

///|
/// Parse a user-entered number, falling back to the current value when the
/// text is not a finite positive number. Configuration must never become NaN.
fn parse_double(text : String, fallback : Double) -> Double {
  let parsed = @string.parse_double(text) catch { _ => return fallback }
  if parsed.is_nan() || parsed <= 0.0 {
    fallback
  } else {
    parsed
  }
}

///|
/// Sort an incoming world-folder file set into the codec shape. Journal files
/// (`conversations.json` / `events.json`) ride beside the Markdown files and
/// degrade alone when missing.
fn world_files_from_paths(files : Array[(String, String)]) -> WorldFiles {
  let mut world_md = ""
  let mut book_md = ""
  let mut conversations_json = ""
  let mut events_json = ""
  let cards : Array[(String, String)] = []
  let memories : Array[(String, String)] = []
  let conversations : Array[(String, String)] = []
  let portraits : Array[(String, String)] = []
  for pair in files {
    let path = pair.0.trim().to_owned()
    if path == "world.md" || path.has_suffix("/world.md") {
      world_md = pair.1
    } else if path == "world_book.md" || path.has_suffix("/world_book.md") {
      book_md = pair.1
    } else if is_card_or_portrait_path(path) is Portrait {
      // Portraits live beside their cards (`characters/<名>.png`), so the prefix
      // alone cannot tell them apart. See `is_card_or_portrait_path`.
      portraits.push(pair)
    } else if is_card_or_portrait_path(path) is Memory {
      // `characters/<名>.memory.md`: the interaction memories, parsed into
      // the memory book by `parse_world_files`.
      memories.push(pair)
    } else if path.has_prefix("characters/") {
      cards.push(pair)
    } else if is_portrait_file_name(path) {
      // Portrait assets ride as base64 beside the cards. They are not parsed
      // by the world codec; the UI resolves them through `portrait_uri`.
      portraits.push(pair)
    } else if path.has_prefix(conversations_dir + "/") {
      // `conversations/<名>.json` per-character history, plus the index that
      // lists which of them belong to this world. The index is bookkeeping,
      // not a conversation.
      if path != conversation_index_file {
        conversations.push(pair)
      }
    } else if path == conversations_file ||
      path.has_suffix("/\{conversations_file}") {
      conversations_json = pair.1
    } else if path == events_file || path.has_suffix("/\{events_file}") {
      events_json = pair.1
    } else {
      // Unrelated files in the folder simply do not reach the model.
      ()
    }
  }
  WorldFiles::{
    world_md,
    book_md,
    character_files: cards,
    memory_files: memories,
    conversations_json,
    conversation_files: conversations,
    events_json,
    portraits,
  }
}

///|
/// The folder payload and the host effects that write it live in `effect.mbt`;
/// this file only decides when to emit them.

///|
/// Apply a world message with an optional host; shared by the constructor so
/// every entrypoint gets the same defaults.
pub fn update(
  model : WorldModel,
  msg : Msg,
  turn_runner? : TurnRunner,
  world_host? : WorldHost,
) -> (WorldModel, @moui.Effect[Msg]) {
  let runner = match turn_runner {
    Some(runner) => runner
    None => (_request, _on_reply, _on_delta) => ()
  }
  let host : WorldHost? = world_host
  match msg {
    InWorld(epoch, inner) =>
      if epoch == model.world_epoch {
        update(model, inner, turn_runner=runner, world_host?=host)
      } else {
        // The request was issued in a world that has since been replaced. Its
        // ids mean something else here (or nothing), so the completion is
        // dropped whole — no log line, because the stale world's notices would
        // be noise in the world the player is actually in.
        (model, @moui.Effect::none())
      }
    Select(id) =>
      // Re-selecting the same character (a map tap on the selected marker, a
      // drag that ends in a click) must not discard a half-written line, and
      // must not re-insert the opening either.
      // A selection made from the atmosphere view also leaves it: tapping a
      // face means "I want to talk to them", not "keep looking at the map".
      if model.selected == id {
        (model, @moui.Effect::none())
      } else {
        let next = {
          ..model.fork(),
          selected: id,
          atmosphere: false,
          say_draft: "",
          do_draft: "",
          story_draft: "",
        }
        // The opening: a card's first line lands as a real message the first
        // time the player selects the character — no provider call, nothing
        // invented. Idempotent: once stored it is an ordinary first message
        // and never re-inserted, on reselect or after a reload.
        let opening : @moui.Effect[Msg] = match id {
          Some(new_id) =>
            match next.scenario.character(new_id) {
              Some(card) if card.opening() != "" => {
                let conversation = next.conversations.for_character(new_id)
                if conversation.lines().is_empty() {
                  append_reply(next, new_id, card.opening())
                  commit_effect(next, host, Conversation(new_id))
                } else {
                  @moui.Effect::none()
                }
              }
              _ => @moui.Effect::none()
            }
          None => @moui.Effect::none()
        }
        (next, opening)
      }
    EnterScene(location) =>
      if model.scenario.location(location) is None {
        (model, @moui.Effect::none())
      } else {
        let cast = cast_at(model.scenario, location)
        if cast.is_empty() {
          let next = model.fork()
          next.push_log("「\{location}」没有人在场")
          (next, @moui.Effect::none())
        } else {
          let next = {
            ..model.fork(),
            scene_location: Some(location),
            atmosphere: false,
            say_draft: "",
            do_draft: "",
            story_draft: "",
          }
          let names : Array[String] = []
          for card in cast {
            names.push(card.name())
          }
          next.push_log("进入场景「\{location}」：\{names.join("、")}")
          (next, @moui.Effect::none())
        }
      }
    LeaveScene => {
      let next = {
        ..model.fork(),
        scene_location: None,
        say_draft: "",
        do_draft: "",
        story_draft: "",
      }
      (next, @moui.Effect::none())
    }
    PanMap => (model, @moui.Effect::none())
    SayDraftChanged(value) =>
      ({ ..model, say_draft: value, }, @moui.Effect::none())
    DoDraftChanged(value) =>
      ({ ..model, do_draft: value, }, @moui.Effect::none())
    StoryDraftChanged(value) =>
      ({ ..model, story_draft: value, }, @moui.Effect::none())
    BeatDraftChanged(value) =>
      ({ ..model, beat_draft: value, }, @moui.Effect::none())
    // Tavern cards: in and out of the editor.
    CardImportTextChanged(text) =>
      ({ ..model, card_import_text: text, }, @moui.Effect::none())
    CopyCharacterCard => update_editor(model, CopyCharacterCard, host)
    ImportCharacterCard => update_editor(model, ImportCharacterCard, host)
    // The world book: the world's own lore, edited in the app.
    WorldBookOpened => update_world_book(model, WorldBookOpened, host)
    WorldBookEdit(index) => update_world_book(model, WorldBookEdit(index), host)
    WorldBookKeysChanged(text) =>
      update_world_book(model, WorldBookKeysChanged(text), host)
    WorldBookContentChanged(text) =>
      update_world_book(model, WorldBookContentChanged(text), host)
    WorldBookAdd => update_world_book(model, WorldBookAdd, host)
    WorldBookDelete(index) =>
      update_world_book(model, WorldBookDelete(index), host)
    WorldBookSave => update_world_book(model, WorldBookSave, host)
    // Reveal more of the transcript: the window grows, the reader stays where
    // they are.
    ExtendTranscript(step) =>
      (
        { ..model, transcript_window: model.transcript_window() + step, },
        @moui.Effect::none(),
      )
    ComposerModeChanged(intent) =>
      update_composer(model, ComposerModeChanged(intent), runner, host)
    ComposerMenuChanged(open) =>
      update_composer(model, ComposerMenuChanged(open), runner, host)
    ToggleComposerExpanded =>
      update_composer(model, ToggleComposerExpanded, runner, host)
    Send(text) => update_composer(model, Send(text), runner, host)
    SendComposer => update_composer(model, SendComposer, runner, host)
    SceneReply(key, respondent_id, text) =>
      match text {
        Some(_reply) if !is_scene_key(key) => {
          let next = model.fork()
          next.push_log(
            "这个场景已经不存在了，这条回复被丢弃。",
          )
          (next, @moui.Effect::none())
        }
        Some(reply) => {
          let next = model.fork()
          let name = character_name(next.scenario, respondent_id)
          let cleaned = llm_clean_reply(reply, name)
          // A provider that returns only whitespace (or only its own name
          // prefix) cleans down to "". Appending that would leave a blank
          // bubble the player cannot edit away, so treat it as a failed turn.
          if cleaned == "" {
            let conversation = next.conversations.for_character(key)
            next.conversations.set(conversation.with_pending(false))
            next.push_log(
              "\{name} 没有回应（回复为空）。可以再发一次。",
            )
            (next, commit_effect(next, host, Conversation(key)))
          } else {
            append_scene_reply(next, key, respondent_id, cleaned)
            next.push_log("\{name}: \{cleaned}")
            (next, commit_effect(next, host, Conversation(key)))
          }
        }
        None => {
          let next = model.fork()
          let conversation = next.conversations.for_character(key)
          next.conversations.set(conversation.with_pending(false))
          next.push_log("场景中没有收到回复——可以重试")
          (next, @moui.Effect::none())
        }
      }
    // A piece of the reply, while the provider is still writing: the stage
    // shows the text as it lands instead of waiting for the whole thing.
    ReplyDelta(character_id, delta) =>
      append_reply_delta(model, character_id, delta, scene=false)
    SceneReplyDelta(key, _speaker, delta) =>
      append_reply_delta(model, key, delta, scene=true)
    Reply(character_id, text) =>
      match text {
        Some(_reply) if !reply_target_exists(model, character_id) =>
          drop_late_reply(
            model, "这个角色已经不在世界里了，这条回复被丢弃。",
          )
        Some(reply) => {
          let next = model.fork()
          let cleaned = llm_clean_reply(
            reply,
            character_name(next.scenario, character_id),
          )
          // Same rule as the scene path: an empty cleaned reply is a failed
          // turn, not an empty message.
          if cleaned == "" {
            let conversation = next.conversations.for_character(character_id)
            next.conversations.set(conversation.with_pending(false))
            next.push_log(
              "\{character_name(next.scenario, character_id)} 没有回应（回复为空）。可以再发一次。",
            )
            return (next, commit_effect(next, host, Conversation(character_id)))
          }
          append_reply(next, character_id, cleaned)
          next.push_log(
            "\{character_name(next.scenario, character_id)}: \{cleaned}",
          )
          let effects : Array[@moui.Effect[Msg]] = [
            commit_effect(next, host, Conversation(character_id)),
          ]
          // Every N appends, ask the provider to distill long-term memories.
          // Drafts wait for an explicit accept; nothing writes itself.
          let conversation = next.conversations.for_character(character_id)
          if next.config.llm_enabled() &&
            next.memory_drafts.is_empty() &&
            conversation.appended() % memory_proposal_every == 0 {
            let (propose_system, propose_user) = propose_memory_prompt(
              character_name=character_name(next.scenario, character_id),
              lines=conversation.lines(),
            )
            let propose_request = LlmRequest::single_shot(
              character_id="!memory",
              endpoint=next.config.endpoint(),
              api_key=next.config.api_key(),
              model=next.config.model(),
              temperature=next.config.temperature(),
              system=propose_system,
              user=propose_user,
            )
            let epoch = next.world_epoch()
            effects.push(
              @moui.Effect::run(
                key="new-world:memory",
                kind="provider",
                label="Extract memories",
                run=dispatch => {
                  runner(
                    propose_request,
                    reply => {
                      dispatch(InWorld(epoch, MemoryProposalsArrived(reply)))
                    },
                    _delta => (),
                  )
                },
              ),
            )
          }
          (next, pack_effects(effects))
        }
        None => {
          // The provider failed. The conversation stays intact and the pending
          // flag clears, so the player can retry without losing context.
          let next = model.fork()
          let conversation = next.conversations.for_character(character_id)
          next.conversations.set(conversation.with_pending(false))
          let name = character_name(next.scenario, character_id)
          // Speak the UI's language: every other notice is Chinese, and an
          // English line here reads like an internal error leaking out.
          next.push_log(
            "\{name} 没有回应（请求失败）。可以再发一次。",
          )
          (next, commit_effect(next, host, Conversation(character_id)))
        }
      }
    EndpointChanged(value) =>
      update_settings(model, EndpointChanged(value), host)
    ModelChanged(value) => update_settings(model, ModelChanged(value), host)
    ApiKeyChanged(value) => update_settings(model, ApiKeyChanged(value), host)
    TemperatureChanged(value) =>
      update_settings(model, TemperatureChanged(value), host)
    SetAppearance(value) => update_settings(model, SetAppearance(value), host)
    SaveConfig => update_settings(model, SaveConfig, host)
    OpenDrawer(kind) =>
      // Opening the world book loads its working copy, so the panel shows
      // the world's own entries and the edits land on them.
      match kind {
        WorldBook => {
          let (next, effect) = update_ui(model, OpenDrawer(kind))
          let (loaded, loaded_effect) = update_world_book(
            next,
            WorldBookOpened,
            host,
          )
          (loaded, pack_effects([effect, loaded_effect]))
        }
        _ => update_ui(model, OpenDrawer(kind))
      }
    CloseDrawer => update_ui(model, CloseDrawer)
    OpenMessageMenu(index) => update_ui(model, OpenMessageMenu(index))
    CloseMessageMenu => update_ui(model, CloseMessageMenu)
    ToggleRail => update_ui(model, ToggleRail)
    ToggleAtmosphere => update_ui(model, ToggleAtmosphere)
    SetBackdrop(on) => update_ui(model, SetBackdrop(on))
    SetMood(variant) => {
      // The world's default mood flips variant; title and time stay. This is
      // world state (the mood rides in world.md), so it commits the world.
      let mood = { ..model.scenario.mood(), variant, }
      let scenario = model.scenario.with_mood(mood)
      let next = { ..model.fork(), scenario, }
      next.push_log("氛围已切换：\{variant.wire()}")
      match (next.current, host) {
        (Some(folder), Some(h)) =>
          (next, commit_world_effect(h, folder, commit_files(next, World)))
        _ => (next, @moui.Effect::none())
      }
    }
    EditCharacter(id) => update_editor(model, EditCharacter(id), host)
    CloseEditor => update_editor(model, CloseEditor, host)
    EditorTabChanged(code) => update_editor(model, EditorTabChanged(code), host)
    EditorChanged(draft) => update_editor(model, EditorChanged(draft), host)
    EditorExamplesChanged(text) =>
      update_editor(model, EditorExamplesChanged(text), host)
    SaveCharacter => update_editor(model, SaveCharacter, host)
    MemoryDraftChanged(text) =>
      update_memory(model, MemoryDraftChanged(text), host)
    MemoryTopicDraftChanged(text) =>
      update_memory(model, MemoryTopicDraftChanged(text), host)
    ToggleMemoryHidden(index) =>
      update_memory(model, ToggleMemoryHidden(index), host)
    // Copy the prompt preview: the player takes what the app would send and
    // carries it to another tool.
    CopyPromptPreview =>
      match host {
        Some(h) =>
          (
            model,
            copy_prompt_effect(h, prompt_preview_text(model, model.say_draft())),
          )
        None => (model, @moui.Effect::none())
      }
    AddMemory => update_memory(model, AddMemory, host)
    ToggleMemoryPin(index) => update_memory(model, ToggleMemoryPin(index), host)
    DeleteMemory(index) => update_memory(model, DeleteMemory(index), host)
    OpenSettings =>
      match host {
        Some(h) => ({ ..model, page: Settings, }, read_config_effect(h))
        None => ({ ..model, page: Settings, }, @moui.Effect::none())
      }
    CloseSettings => ({ ..model, page: Main, }, @moui.Effect::none())
    ConfigFileLoaded(text) =>
      match text {
        Some(json) =>
          if json.trim() == "" {
            (model, @moui.Effect::none())
          } else {
            let next = {
              ..model.fork(),
              config: ModelConfig::from_json(json),
              config_file_loaded: true,
            }
            next.push_log("已从世界库 config.json 载入模型设置")
            (next, @moui.Effect::none())
          }
        None => (model, @moui.Effect::none())
      }
    SettingsSaved(ok) => {
      let next = model.fork()
      if ok {
        next.push_log(
          "设置已保存到世界库 config.json（key 属于你自己的数据文件夹）",
        )
      } else {
        next.push_log(
          "设置写入失败——世界库还没有就绪，稍后再试",
        )
      }
      (next, @moui.Effect::none())
    }
    // ---- world management ----
    // World library: listing, opening, creating, committing. Moved to
    // `library.mbt` to keep this file under the source-file limit.
    SyncLibrary => update_library(model, SyncLibrary, host)
    PickWorldRoot => update_library(model, PickWorldRoot, host)
    WorldListArrived(names) =>
      update_library(model, WorldListArrived(names), host)
    OpenWorld(folder) => update_library(model, OpenWorld(folder), host)
    WorldFilesArrived(folder, ok, files) =>
      update_library(model, WorldFilesArrived(folder, ok, files), host)
    WorldNameChanged(value) =>
      update_library(model, WorldNameChanged(value), host)
    NewWorld => update_library(model, NewWorld, host)
    WorldCommitted(folder, ok) =>
      update_library(model, WorldCommitted(folder, ok), host)
    WorldPortraitsRefreshed(portraits) =>
      ({ ..model, portraits, }, @moui.Effect::none())
    // ---- character creation ----
    // Creation and generation: one cohesive feature (compose a character,
    // generate a world), implemented in `creation.mbt`. Each arm keeps its own
    // payload binding here; the bodies live there.
    ToggleCreator => update_creation(model, ToggleCreator, runner, host)
    CreatorChanged(draft) =>
      update_creation(model, CreatorChanged(draft), runner, host)
    CharacterCreated => update_creation(model, CharacterCreated, runner, host)
    UseArchetype(index) =>
      update_creation(model, UseArchetype(index), runner, host)
    CharacterIdeaChanged(value) =>
      update_creation(model, CharacterIdeaChanged(value), runner, host)
    DraftCharacter => update_creation(model, DraftCharacter, runner, host)
    CharacterDrafted(reply) =>
      update_creation(model, CharacterDrafted(reply), runner, host)
    WorldIdeaChanged(value) =>
      update_creation(model, WorldIdeaChanged(value), runner, host)
    GenerateWorld => update_creation(model, GenerateWorld, runner, host)
    WorldGenerated(reply) =>
      update_creation(model, WorldGenerated(reply), runner, host)
    ContextChanged(value) =>
      (
        { ..model, config: model.config.with_context_preset(value), },
        @moui.Effect::none(),
      )
    SummaryArrived(character_id, marker, text) =>
      match text {
        Some(reply) => {
          let next = model.fork()
          let conversation = next.conversations.for_character(character_id)
          let summary = clip_chars(llm_clean_reply(reply, ""), 600)
          next.conversations.set(conversation.with_summary(summary, marker))
          next.push_log(
            "已压缩 \{character_name(next.scenario, character_id)} 的记忆笔记",
          )
          // The summary is conversation state, so it has to reach the file.
          // Computing it and only keeping it in memory meant a reload restored
          // the lines but not the compression, and the work was redone (or the
          // summary silently lost) on the next launch.
          (next, commit_effect(next, host, Conversation(character_id)))
        }
        None =>
          // A failed compression costs nothing: the next overflowing turn
          // retries with fresh material.
          (model, @moui.Effect::none())
      }
    MemoryProposalsArrived(reply) =>
      match reply {
        None => (model, @moui.Effect::none())
        Some(text) => {
          let next = model.fork()
          let known : Array[String] = []
          match model.selected {
            Some(id) =>
              for entry in model.memories.for_character(id).entries() {
                known.push(entry.content())
              }
            None => ()
          }
          let proposed = parse_memory_proposals(
            text,
            next.scenario.world_book(),
            next.memory_drafts,
            known,
          )
          if proposed.is_empty() {
            next.push_log("AI 没有找到值得长期记忆的新事实")
            (next, @moui.Effect::none())
          } else {
            for entry in proposed {
              next.memory_drafts.push(entry)
            }
            next.push_log(
              "AI 提议记住 \{proposed.length()} 条记忆——见右侧，可采纳或忽略",
            )
            (next, @moui.Effect::none())
          }
        }
      }
    AcceptMemory(index) => update_memory(model, AcceptMemory(index), host)
    DiscardMemory(index) => update_memory(model, DiscardMemory(index), host)
    ToggleApiKeyReveal =>
      (
        { ..model, api_key_revealed: !model.api_key_revealed, },
        @moui.Effect::none(),
      )
    // ---- conversation editing ----
    // History editing (regenerate / swipe / edit / delete / branch / clear)
    // lives in `editing.mbt`: one cohesive feature that was pushing this file
    // past the repository's source-file hard limit.
    AdvanceTime => {
      let location = model.scene_location
      let present = match location {
        Some(place) => cast_at(model.scenario, place)
        None => model.scenario.characters()
      }
      let next = model.fork()
      if !next.config.llm_enabled() {
        // No provider: a deterministic note still advances the log, so the
        // action is never a dead button offline.
        let stamp = next.log.length() + 1
        next.push_log(
          "（这段时间）世界安静了一阵。再过一会儿，第 \{stamp} 段小事发生。",
        )
        return (next, commit_effect(next, host, World))
      }
      let (system, user) = advance_time_prompt(
        model.scenario,
        location,
        present,
      )
      let request = LlmRequest::single_shot(
        character_id="!time",
        endpoint=next.config.endpoint(),
        api_key=next.config.api_key(),
        model=next.config.model(),
        temperature=next.config.temperature(),
        system~,
        user~,
      )
      next.push_log("正在推进时间线…")
      let epoch = next.world_epoch()
      (
        next,
        @moui.Effect::run(
          key="new-world:advance-time",
          kind="provider",
          label="Advance time",
          run=dispatch => {
            runner(
              request,
              reply => dispatch(InWorld(epoch, TimeAdvanced(reply))),
              _delta => (),
            )
          },
        ),
      )
    }
    TimeAdvanced(reply) => {
      let next = model.fork()
      match reply {
        Some(text) => {
          let event = time_advanced_event(text)
          if event == "" {
            next.push_log("没有明显的事发生")
          } else {
            next.push_log(event)
          }
        }
        None => next.push_log("推进时间失败——可以再试一次")
      }
      (next, commit_effect(next, host, World))
    }
    // ---- portability ----
    RegenerateReply => update_editing(model, RegenerateReply, runner, host)
    Regenerated(id, reply) =>
      update_editing(model, Regenerated(id, reply), runner, host)
    SwipeReply(line_index, direction) =>
      update_editing(model, SwipeReply(line_index, direction), runner, host)
    EditLine(line_index) =>
      update_editing(model, EditLine(line_index), runner, host)
    EditLineChanged(value) =>
      update_editing(model, EditLineChanged(value), runner, host)
    EditLineCommit => update_editing(model, EditLineCommit, runner, host)
    EditLineCancel => update_editing(model, EditLineCancel, runner, host)
    DeleteLine(line_index) =>
      update_editing(model, DeleteLine(line_index), runner, host)
    BranchAt(line_index) =>
      update_editing(model, BranchAt(line_index), runner, host)
    ClearConversation => update_editing(model, ClearConversation, runner, host)
    ExportWorld => {
      let next = model.fork()
      match (host, model.current) {
        (Some(h), Some(folder)) => {
          next.push_log("正在导出世界「\{folder}」…")
          (
            next,
            export_world_effect(
              h,
              folder,
              bundle_encode(folder, commit_files(model, World)),
            ),
          )
        }
        (None, _) => {
          next.push_log("（未接入世界库）无法导出")
          (next, @moui.Effect::none())
        }
        (_, None) => {
          next.push_log("先打开一个世界再导出")
          (next, @moui.Effect::none())
        }
      }
    }
    WorldExported(ok) => {
      let next = model.fork()
      if ok {
        next.push_log(
          "世界已导出为一个 .aiworld.json 包（Markdown、对话、图片与事件，可直接分享）",
        )
      } else {
        next.push_log("导出取消或失败")
      }
      (next, @moui.Effect::none())
    }
    ImportWorld =>
      match host {
        Some(h) => (model, import_world_effect(h, model.worlds))
        None => {
          let next = model.fork()
          next.push_log("（未接入世界库）无法导入")
          (next, @moui.Effect::none())
        }
      }
    WorldImported(ok, folder, files) =>
      if !ok {
        let next = model.fork()
        next.push_log("导入取消，或所选文件不是有效的世界包")
        (next, @moui.Effect::none())
      } else {
        // The bundle carries the world's own file set, so the import goes
        // through exactly the same parse path as opening a folder.
        match parse_world_files(world_files_from_paths(files)) {
          Some(parsed) => {
            let name = if folder == "" {
              parsed.scenario.name()
            } else {
              folder
            }
            let next = model.fork()
            next.conversations.clear()
            next.memories.clear()
            next.log.clear()
            for conversation in parsed.conversations {
              next.conversations.set(conversation)
            }
            for memory in parsed.memories.entries {
              next.memories.set(memory)
            }
            for event in parsed.events {
              next.log.push(event)
            }
            let settled = {
              ..next,
              scenario: parsed.scenario,
              current: Some(world_folder_name(name)),
              world_epoch: model.world_epoch + 1,
              worlds: with_world(model.worlds, world_folder_name(name)),
              selected: None,
            }
            // Warnings first, the summary last: the log is newest-first, so
            // the "已导入" headline stays on top where the player looks.
            for warning in parsed.warnings {
              settled.push_log("导入提示：\{warning}")
            }
            settled.push_log(
              "已导入世界「\{parsed.scenario.name()}」：\{parsed.scenario.characters().length()} 个角色，\{parsed.conversations.length()} 段对话",
            )
            // Persist immediately: an imported world that only lives in memory
            // would vanish on reload, which is exactly what "file database"
            // promises not to happen.
            match host {
              Some(h) =>
                (
                  settled,
                  commit_world_effect(
                    h,
                    world_folder_name(name),
                    commit_files(settled, World),
                  ),
                )
              None => (settled, @moui.Effect::none())
            }
          }
          None => {
            let next = model.fork()
            next.push_log(
              "导入的文件不是有效的世界（缺 world.md 或名字行）",
            )
            (next, @moui.Effect::none())
          }
        }
      }
  }
}

///|
fn with_world(worlds : Array[String], name : String) -> Array[String] {
  let next : Array[String] = []
  for world in worlds {
    next.push(world)
  }
  if !next.contains(name) {
    next.push(name)
  }
  next
}

///|
/// Effects fly as one batch; a single effect skips the wrapper so tests can
/// observe a plain run.
fn pack_effects(effects : Array[@moui.Effect[Msg]]) -> @moui.Effect[Msg] {
  if effects.length() == 1 {
    effects[0]
  } else if effects.length() == 0 {
    @moui.Effect::none()
  } else {
    @moui.Effect::batch(effects)
  }
}

///|
/// Parse `{"memories":[…],"content":"…"}` replies into entries. Duplicates of
/// the curated book, of drafts already on the table, or of the selected
/// character's memory book are dropped; a malformed reply simply proposes
/// nothing.
fn parse_memory_proposals(
  text : String,
  book : Array[WorldEntry],
  drafts : Array[WorldEntry],
  memories : Array[String],
) -> Array[WorldEntry] {
  let result : Array[WorldEntry] = []
  let payload = match extract_json_object(text) {
    Some(json) => json
    None => return result
  }
  let parsed = @json.parse(payload) catch { _ => return result }
  let fields = match parsed {
    Object(values) => values
    _ => return result
  }
  let items = match fields.get("memories") {
    Some(Array(values)) => values
    _ => return result
  }
  for item in items {
    let obj = match item {
      Object(values) => values
      _ => continue
    }
    let content = match obj.get("content") {
      Some(String(value)) => value
      _ => continue
    }
    if content.trim() == "" {
      continue
    }
    let keys : Array[String] = []
    match obj.get("keys") {
      Some(Array(values)) =>
        for value in values {
          match value {
            String(key) => if key != "" { keys.push(key) }
            _ => ()
          }
        }
      _ => ()
    }
    let mut duplicate = false
    for existing in book {
      if existing.content() == content {
        duplicate = true
      }
    }
    for existing in drafts {
      if existing.content() == content {
        duplicate = true
      }
    }
    for known_content in memories {
      if known_content == content {
        duplicate = true
      }
    }
    for existing in result {
      if existing.content() == content {
        duplicate = true
      }
    }
    if !duplicate {
      result.push(WorldEntry::new(keys~, content~))
    }
  }
  result
}

///|
fn character_name(scenario : Scenario, id : String) -> String {
  // A scene transcript is keyed by location, so its "speaker" in the log is the
  // place rather than a person.
  if is_scene_key(id) {
    let location : String = id[6:].to_owned()
    return match scenario.location(location) {
      Some(place) => "场景「" + place.name() + "」"
      None => "场景「" + location + "」"
    }
  }
  // A branch is a sibling key (`林掌柜~2`); it is still that character, so the
  // log and prompt say their name with the branch number appended.
  match split_branch(id) {
    Some((base, number)) => {
      let name = match scenario.character(base) {
        Some(card) => card.name()
        None => base
      }
      return name + " · 分支 " + number.to_string()
    }
    None => ()
  }
  match scenario.character(id) {
    Some(card) => card.name()
    None => id
  }
}
