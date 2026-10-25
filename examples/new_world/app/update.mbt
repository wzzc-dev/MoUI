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
