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
  config : ModelConfig
  /// The character the player is currently talking to.
  selected : String?
  /// The composer's three fields (说 / 做 / 旁白). Each field frames its own
  /// line, and one send composes the non-empty ones in order. Session UI state:
  /// switching characters or scenes starts a fresh turn.
  say_draft : String
  do_draft : String
  story_draft : String
  /// Newest-first log of provider/host events, so a failed turn is diagnosable.
  log : Array[String]
  /// World folders discovered in the library.
  worlds : Array[String]
  /// The world folder currently on stage.
  current : String?
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
  /// Which panel the medium/compact shell shows (the wide layout ignores it).
  /// Session UI state: a rotation or a resize picks a sensible default instead
  /// of restoring a tab the new width cannot show.
  shell_tab : CompactTab
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
  editing_line : Int?
  edit_buffer : String
  /// The one-line character idea in the creation wizard.
  character_idea : String
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
    config: ModelConfig::new(),
    selected: None,
    say_draft: "",
    do_draft: "",
    story_draft: "",
    log: [],
    worlds: [],
    current: None,
    library_missing: false,
    world_name: "",
    creator_open: false,
    creator_draft: CharacterDraft::new(),
    idea: "",
    generating: false,
    page: Main,
    shell_tab: Chat,
    config_file_loaded: false,
    memory_drafts: [],
    api_key_revealed: false,
    editing_line: None,
    edit_buffer: "",
    character_idea: "",
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
/// Can the composer send right now? Any non-empty field counts as content.
pub fn WorldModel::composer_ready(self : WorldModel) -> Bool {
  composer_has_content(self.say_draft, self.do_draft, self.story_draft)
}

///|
/// The history line being edited, if any.
pub fn WorldModel::editing_line(self : WorldModel) -> Int? {
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
fn last_reply_index(conversation : Conversation) -> Int? {
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
/// Which panel the narrow shell is showing.
pub fn WorldModel::shell_tab(self : WorldModel) -> CompactTab {
  self.shell_tab
}

///|
/// Performs one provider turn: the request plus a completion callback.
///
/// The platform entrypoint injects the native/web worker here. Without one, no
/// turn is ever started, which is exactly the behaviour a test build needs.
pub type TurnRunner = (LlmRequest, (String?) -> Unit) -> Unit

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
  /// a home for. The app hands over the exact folder contents (Markdown,
  /// journal, and — later — portraits), so the bundle is the world.
  /// `false` means the player cancelled or the write failed.
  export_world : (String, Array[(String, String)], (Bool) -> Unit) -> Unit
  /// Import a bundle into the library as a new world folder. The host picks
  /// the file, unpacks it, and returns `(ok, folder, files)` so the app can go
  /// on stage immediately.
  import_world : ((Bool, String, Array[(String, String)]) -> Unit) -> Unit
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
pub let world_log_limit : Int = 40

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
    .with_pending(false),
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
    .with_pending(false),
  )
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
    None => (_request, _on_reply) => ()
  }
  let host : WorldHost? = world_host
  match msg {
    Select(id) => {
      // Re-selecting the same character (a map tap on the selected marker, a
      // drag that ends in a click) must not discard a half-written line.
      let next = if model.selected == id {
        model
      } else {
        { ..model, selected: id, say_draft: "", do_draft: "", story_draft: "", }
      }
      (next, @moui.Effect::none())
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
            effects.push(
              @moui.Effect::run(
                key="new-world:memory",
                kind="provider",
                label="Extract memories",
                run=dispatch => {
                  runner(propose_request, reply => {
                    dispatch(MemoryProposalsArrived(reply))
                  })
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
    SaveConfig => update_settings(model, SaveConfig, host)
    ShellTabChanged(code) => update_settings(model, ShellTabChanged(code), host)
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
          let proposed = parse_memory_proposals(
            text,
            next.scenario.world_book(),
            next.memory_drafts,
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
    AcceptMemory(index) =>
      match model.memory_drafts.get(index) {
        None => (model, @moui.Effect::none())
        Some(entry) => {
          let book : Array[WorldEntry] = []
          for existing in model.scenario.world_book() {
            book.push(existing)
          }
          book.push(entry)
          let scenario = Scenario::new(
            id=model.scenario.id(),
            name=model.scenario.name(),
            background=model.scenario.background(),
            map_width=model.scenario.map_width(),
            map_height=model.scenario.map_height(),
            locations=model.scenario.locations(),
            characters=model.scenario.characters(),
            world_book=book,
          )
          let drafts : Array[WorldEntry] = []
          for i in 0..<model.memory_drafts.length() {
            if i != index {
              drafts.push(model.memory_drafts[i])
            }
          }
          let next = { ..model.fork(), scenario, memory_drafts: drafts, }
          next.push_log("已记住:「\{entry.content()}」")
          match (next.current, host) {
            (Some(folder), Some(h)) =>
              (next, commit_world_effect(h, folder, commit_files(next, World)))
            _ => (next, @moui.Effect::none())
          }
        }
      }
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
      (
        next,
        @moui.Effect::run(
          key="new-world:advance-time",
          kind="provider",
          label="Advance time",
          run=dispatch => {
            runner(request, reply => dispatch(TimeAdvanced(reply)))
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
    Regenerated(reply) =>
      update_editing(model, Regenerated(reply), runner, host)
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
          (next, export_world_effect(h, folder, commit_files(model, World)))
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
          "世界已导出为一个可分享的 .aiworld.json 文件",
        )
      } else {
        next.push_log("导出取消或失败")
      }
      (next, @moui.Effect::none())
    }
    ImportWorld =>
      match host {
        Some(h) => (model, import_world_effect(h))
        None => {
          let next = model.fork()
          next.push_log("（未接入世界库）无法导入")
          (next, @moui.Effect::none())
        }
      }
    WorldImported(ok, folder, files) =>
      if !ok {
        let next = model.fork()
        next.push_log("导入取消或文件无法读取")
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
            next.log.clear()
            for conversation in parsed.conversations {
              next.conversations.set(conversation)
            }
            for event in parsed.events {
              next.log.push(event)
            }
            let settled = {
              ..next,
              scenario: parsed.scenario,
              current: Some(world_folder_name(name)),
              worlds: with_world(model.worlds, world_folder_name(name)),
              selected: None,
            }
            settled.push_log(
              "已导入世界「\{parsed.scenario.name()}」：\{parsed.scenario.characters().length()} 个角色，\{parsed.conversations.length()} 段对话",
            )
            for warning in parsed.warnings {
              settled.push_log("导入提示：\{warning}")
            }
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
    DiscardMemory(index) => {
      let drafts : Array[WorldEntry] = []
      for i in 0..<model.memory_drafts.length() {
        if i != index {
          drafts.push(model.memory_drafts[i])
        }
      }
      let next = { ..model.fork(), memory_drafts: drafts, }
      next.push_log("已忽略一条记忆提议")
      (next, @moui.Effect::none())
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
/// Parse `{"memories":[{"keys":[…],"content":"…"}]}` into entries. Duplicates
/// of the curated book or of drafts already on the table are dropped; a
/// malformed reply simply proposes nothing.
fn parse_memory_proposals(
  text : String,
  book : Array[WorldEntry],
  drafts : Array[WorldEntry],
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
