///|
/// Message handling.
///
/// Every state change happens here and only here (P13). A world lives in one
/// folder of the player's library; all folder IO is injected through
/// `WorldHost`, all provider IO through `TurnRunner` — `update` only prepares
/// requests and consumes typed results, so a failed turn or a failed save is a
/// cosmetic event rather than a corrupted world.

///|
/// Top-level pages: the main three-stage layout and a full-width settings
/// page (the model configuration lives in `<世界库>/config.json`).
pub(all) enum Page {
  Main
  Settings
} derive(Eq, Debug)

///|
pub extend Page with Debug::{to_repr}

///|
pub extend Page with Eq::{not_equal, equal}

///|
pub(all) enum Msg {
  /// Select the character the player is talking to.
  Select(String?)
  /// Player edited the composer without sending yet.
  DraftChanged(String)
  /// Player typed a line and submitted it.
  Send(String)
  /// A provider reply arrived; `None` text means the call failed.
  Reply(String, String?)
  /// Open the settings page (re-reads `config.json` from the library).
  OpenSettings
  /// Back to the main layout.
  CloseSettings
  /// The library's `config.json` arrived; `None` = missing or unreadable.
  ConfigFileLoaded(String?)
  /// A settings-file write finished.
  SettingsSaved(Bool)
  /// Configuration field edits.
  EndpointChanged(String)
  ModelChanged(String)
  ApiKeyChanged(String)
  TemperatureChanged(String)
  /// Persist the current configuration through host settings.
  SaveConfig
  ConfigLoaded(String?)
  ConfigSaved
  /// Import a scenario JSON blob, replacing the current world.
  ImportScenario(String)
  // ---- world management (folder database) ----
  /// Re-list the library without interaction.
  SyncLibrary
  /// Ask the host to pick/point at the library root (a user gesture).
  PickWorldRoot
  /// The library listing arrived.
  WorldListArrived(Array[String])
  /// Open (or re-read) one world folder.
  OpenWorld(String)
  /// One world folder's files arrived.
  WorldFilesArrived(String, Bool, Array[(String, String)])
  /// The new-world name being typed.
  WorldNameChanged(String)
  /// Create the folder for a new world.
  NewWorld
  /// A world folder write finished.
  WorldCommitted(String, Bool)
  // ---- character creation ----
  ToggleCreator
  CreatorChanged(CharacterDraft)
  CharacterCreated
  // ---- AI world generation ----
  WorldIdeaChanged(String)
  GenerateWorld
  /// The provider answered a generation request (`None` = failure).
  WorldGenerated(String?)
  // ---- context & memory ----
  /// The context-budget preset changed from the settings page.
  ContextChanged(String)
  /// A memory-compression reply arrived; `None` = failure (retry later).
  SummaryArrived(String, Int, String?)
  /// A memory-extraction reply arrived; `None` = failure.
  MemoryProposalsArrived(String?)
  /// Adopt a proposed memory entry into the world book.
  AcceptMemory(Int)
  /// Drop a proposed memory entry.
  DiscardMemory(Int)
}

///|
pub struct WorldModel {
  scenario : Scenario
  conversations : ConversationBook
  config : ModelConfig
  /// The character the player is currently talking to.
  selected : String?
  /// The line the player is composing.
  draft : String
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
  /// The library config.json applied at least once (so the one-time read
  /// rides on the library listing arriving, past the boot race).
  config_file_loaded : Bool
  /// Long-term-memory entries proposed by the provider, awaiting the
  /// player's accept / discard decision. Nothing reaches the world book
  /// without that decision — the curated lore file stays the author's.
  memory_drafts : Array[WorldEntry]
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
    draft: "",
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
    config_file_loaded: false,
    memory_drafts: [],
  }
}

///|
pub fn WorldModel::scenario(self : WorldModel) -> Scenario {
  self.scenario
}

///|
pub fn WorldModel::conversations(self : WorldModel) -> ConversationBook {
  self.conversations
}

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
pub fn WorldModel::draft(self : WorldModel) -> String {
  self.draft
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
pub fn WorldModel::world_name(self : WorldModel) -> String {
  self.world_name
}

///|
/// Which top-level page is on stage.
pub fn WorldModel::page(self : WorldModel) -> Page {
  self.page
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
  for pair in files {
    let path = pair.0.trim().to_owned()
    if path == "world.md" || path.has_suffix("/world.md") {
      world_md = pair.1
    } else if path == "world_book.md" || path.has_suffix("/world_book.md") {
      book_md = pair.1
    } else if path.has_prefix("characters/") {
      cards.push(pair)
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
    events_json,
  }
}

///|
/// Effect: list the library without interaction.
fn sync_library_effect(host : WorldHost) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="ai-world:library",
    kind="filesystem",
    label="List world library",
    run=dispatch => {
      (host.list_worlds)(names => dispatch(WorldListArrived(names)))
    },
  )
}

///|
/// Effect: read one world folder.
fn open_world_effect(host : WorldHost, folder : String) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="ai-world:open",
    kind="filesystem",
    label="Open world \{folder}",
    run=dispatch => {
      (host.read_world)(folder, (ok, files) => {
        dispatch(WorldFilesArrived(folder, ok, files))
      })
    },
  )
}

///|
/// Effect: read the library-root config file.
fn read_config_effect(host : WorldHost) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="ai-world:config-read",
    kind="filesystem",
    label="Load settings",
    run=dispatch => (host.read_config)(text => dispatch(ConfigFileLoaded(text))),
  )
}

///|
/// Effect: write the library-root config file.
fn write_config_effect(host : WorldHost, json : String) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="ai-world:config-write",
    kind="filesystem",
    label="Save settings",
    run=dispatch => (host.write_config)(json, ok => dispatch(SettingsSaved(ok))),
  )
}

///|
/// Effect: write every file of the current world folder.
fn commit_world_effect(
  host : WorldHost,
  folder : String,
  files : Array[(String, String)],
) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="ai-world:commit",
    kind="filesystem",
    label="Save world \{folder}",
    run=dispatch => {
      (host.write_world)(folder, files, ok => {
        dispatch(WorldCommitted(folder, ok))
      })
    },
  )
}

///|
/// The full folder payload: the Markdown world files plus the JSON journal
/// (conversations + event log). Every world mutation commits the journal too,
/// so the folder on disk is always a complete, replayable world.
fn commit_files(model : WorldModel) -> Array[(String, String)] {
  let files = model.scenario.world_files()
  files.push((conversations_file, model.conversations.to_json_text()))
  files.push((events_file, events_json_text(model.log)))
  files
}

///|
/// Commit the journal (and with it the world) when a world folder and a host
/// both exist; otherwise this is a no-op — running without a library still
/// plays fine, it just persists nothing.
fn journal_effect(
  model : WorldModel,
  world_host : WorldHost?,
) -> @moui.Effect[Msg] {
  match (model.current, world_host) {
    (Some(folder), Some(host)) =>
      commit_world_effect(host, folder, commit_files(model))
    _ => @moui.Effect::none()
  }
}

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
    Select(id) => ({ ..model, selected: id, draft: "", }, @moui.Effect::none())
    DraftChanged(value) => ({ ..model, draft: value, }, @moui.Effect::none())
    Send(text) => {
      let trimmed : String = text.trim().to_owned()
      if trimmed == "" {
        return (model, @moui.Effect::none())
      }
      // No selection means nothing to talk to; the view keeps Send unavailable
      // in that state, so this is a guard rather than a reachable branch.
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) =>
          match model.scenario.character(id) {
            None => (model, @moui.Effect::none())
            Some(card) => {
              let next = { ..model, draft: "", }
              append_player(next, id, trimmed)
              next.push_log(
                "you → \{character_name(next.scenario, id)}: \{trimmed}",
              )
              if next.config.llm_enabled() {
                // The provider turn is an effect, not a side effect here: the
                // runner is injected by the host, the reply arrives as a
                // typed message, and the pending flag keeps the UI honest.
                let conversation = next.conversations.for_character(id)
                next.conversations.set(conversation.with_pending(true))
                let plan = plan_messages(
                  next.scenario,
                  card,
                  conversation,
                  trimmed,
                  budget=next.config.context_budget(),
                )
                let request = LlmRequest::new(
                  character_id=id,
                  endpoint=next.config.endpoint(),
                  api_key=next.config.api_key(),
                  model=next.config.model(),
                  temperature=next.config.temperature(),
                  system=plan.messages[0].1,
                  user=plan.messages[plan.messages.length() - 1].1,
                )
                let effects : Array[@moui.Effect[Msg]] = [
                  @moui.Effect::run(
                    key="ai-world:turn",
                    kind="provider",
                    label="Provider turn",
                    run=dispatch => {
                      runner(request, reply => dispatch(Reply(id, reply)))
                    },
                  ),
                ]
                // The player's line is world state: commit the journal
                // alongside the turn, whatever the reply turns out to be.
                effects.push(journal_effect(next, host))
                // When history overflows its budget (or the cap), fold the
                // evicted tail into the rolling summary for next time.
                if needs_compression(conversation, plan.evicted.length()) {
                  let marker = conversation.appended()
                  let source = compression_source(conversation)
                  let (summary_system, summary_user) = summarize_prompt(
                    character_name=character_name(next.scenario, id),
                    prior_summary=conversation.summary(),
                    source_lines=source,
                  )
                  let summary_request = LlmRequest::new(
                    character_id=id,
                    endpoint=next.config.endpoint(),
                    api_key=next.config.api_key(),
                    model=next.config.model(),
                    temperature=next.config.temperature(),
                    system=summary_system,
                    user=summary_user,
                  )
                  effects.push(
                    @moui.Effect::run(
                      key="ai-world:compress",
                      kind="provider",
                      label="Compress memory",
                      run=dispatch => {
                        runner(summary_request, reply => {
                          dispatch(SummaryArrived(id, marker, reply))
                        })
                      },
                    ),
                  )
                }
                (next, pack_effects(effects))
              } else {
                // No key: the world still answers, deterministically. The turn
                // completes inside this update, so nothing can dangle.
                append_reply(
                  next,
                  id,
                  scripted_reply(next.scenario, card, trimmed),
                )
                next.push_log(
                  "（本地剧本）\{character_name(next.scenario, id)} 已回应",
                )
                (next, journal_effect(next, host))
              }
            }
          }
      }
    }
    Reply(character_id, text) =>
      match text {
        Some(reply) => {
          let next = { ..model, }
          let cleaned = llm_clean_reply(
            reply,
            character_name(next.scenario, character_id),
          )
          append_reply(next, character_id, cleaned)
          next.push_log(
            "\{character_name(next.scenario, character_id)}: \{cleaned}",
          )
          let effects : Array[@moui.Effect[Msg]] = [journal_effect(next, host)]
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
            let propose_request = LlmRequest::new(
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
                key="ai-world:memory",
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
          let next = { ..model, }
          let conversation = next.conversations.for_character(character_id)
          next.conversations.set(conversation.with_pending(false))
          let name = character_name(next.scenario, character_id)
          next.push_log("no reply from provider for \{name}")
          (next, journal_effect(next, host))
        }
      }
    EndpointChanged(value) =>
      (
        { ..model, config: model.config.with_endpoint(value), },
        @moui.Effect::none(),
      )
    ModelChanged(value) =>
      (
        { ..model, config: model.config.with_model(value), },
        @moui.Effect::none(),
      )
    ApiKeyChanged(value) =>
      (
        { ..model, config: model.config.with_api_key(value), },
        @moui.Effect::none(),
      )
    TemperatureChanged(value) =>
      (
        {
          ..model,
          config: model.config.with_temperature(
            parse_double(value, model.config.temperature()),
          ),
        },
        @moui.Effect::none(),
      )
    SaveConfig =>
      // The model config persists as JSON at the library root, next to the
      // world folders — the player's own data folder, not a project file.
      match host {
        Some(h) => (model, write_config_effect(h, model.config.to_json()))
        None => {
          let next = { ..model, }
          next.push_log(
            "（未接入世界库）设置仅保存在本会话内存中",
          )
          (next, @moui.Effect::none())
        }
      }
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
              ..model,
              config: ModelConfig::from_json(json),
              config_file_loaded: true,
            }
            next.push_log("已从世界库 config.json 载入模型设置")
            (next, @moui.Effect::none())
          }
        None => (model, @moui.Effect::none())
      }
    SettingsSaved(ok) => {
      let next = { ..model, }
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
    ConfigLoaded(text) =>
      match text {
        Some(value) =>
          (
            { ..model, config: ModelConfig::from_json(value), },
            @moui.Effect::none(),
          )
        None => (model, @moui.Effect::none())
      }
    ConfigSaved => {
      let next = { ..model, }
      next.push_log("configuration saved")
      (next, @moui.Effect::none())
    }
    ImportScenario(text) => {
      let scenario = Scenario::try_from_json(text).unwrap_or(default_scenario())
      let next = { ..model, scenario, selected: None, }
      next.push_log("scenario replaced: \{scenario.name()}")
      (next, @moui.Effect::none())
    }
    // ---- world management ----
    SyncLibrary =>
      match host {
        Some(h) => (model, sync_library_effect(h))
        None => (model, @moui.Effect::none())
      }
    PickWorldRoot =>
      match host {
        Some(h) =>
          (
            model,
            @moui.Effect::run(
              key="ai-world:pick-root",
              kind="filesystem",
              label="Pick world library",
              run=dispatch => {
                (h.pick_root)(names => dispatch(WorldListArrived(names)))
              },
            ),
          )
        None => (model, @moui.Effect::none())
      }
    WorldListArrived(names) => {
      let next = { ..model, worlds: names, library_missing: false, }
      // The config load rides on the first listing: this message can only be
      // dispatched once the host bridge is fully past the boot race.
      let config_effect = match host {
        Some(h) =>
          if next.config_file_loaded {
            @moui.Effect::none()
          } else {
            read_config_effect(h)
          }
        None => @moui.Effect::none()
      }
      // First sync after launch opens the newest-known world so the product
      // boots straight into a conversation instead of an empty catalogue.
      let next = if next.config_file_loaded {
        next
      } else {
        { ..next, config_file_loaded: true, }
      }
      if next.current is None && names.length() > 0 {
        match host {
          Some(h) =>
            (
              next,
              @moui.Effect::batch([
                open_world_effect(h, names[0]),
                config_effect,
              ]),
            )
          None => (next, @moui.Effect::none())
        }
      } else {
        (next, config_effect)
      }
    }
    OpenWorld(folder) =>
      match host {
        Some(h) => (model, open_world_effect(h, folder))
        None => (model, @moui.Effect::none())
      }
    WorldFilesArrived(folder, ok, files) =>
      if !ok {
        let next = { ..model, }
        next.push_log(
          "无法读取世界库「\{folder}」——先选择一个文件夹作为世界库",
        )
        ({ ..next, library_missing: true, }, @moui.Effect::none())
      } else {
        match parse_world_files(world_files_from_paths(files)) {
          Some(parsed) => {
            // A different folder means a different world: conversations are
            // keyed by character id and must not leak across worlds. Re-reading
            // the same folder keeps the current history.
            let fresh = match model.current {
              Some(opened) => opened != folder
              None => true
            }
            let next = {
              ..model,
              scenario: parsed.scenario,
              current: Some(folder),
            }
            if fresh {
              next.conversations.clear()
              // The folder is the source of truth at open time: the world's
              // own journal replaces whatever is in memory.
              next.log.clear()
              for event in parsed.events {
                next.log.push(event)
              }
              for conversation in parsed.conversations {
                next.conversations.set(conversation)
              }
            }
            for warning in parsed.warnings {
              next.push_log("世界书提示：\{warning}")
            }
            next.push_log(
              "已载入「\{folder}」：\{parsed.scenario.characters().length()} 个角色，\{parsed.scenario.world_book().length()} 条世界书",
            )
            (next, @moui.Effect::none())
          }
          None => {
            let next = { ..model, }
            next.push_log(
              "「\{folder}」不是世界文件夹（缺 world.md 或名字行）",
            )
            (next, @moui.Effect::none())
          }
        }
      }
    WorldNameChanged(value) =>
      ({ ..model, world_name: value, }, @moui.Effect::none())
    NewWorld => {
      let name : String = model.world_name.trim().to_owned()
      if name == "" {
        let next = { ..model, }
        next.push_log("先给新世界起个名字")
        return (next, @moui.Effect::none())
      }
      if model.worlds.contains(name) {
        let next = { ..model, }
        next.push_log("「\{name}」已存在——直接打开它即可")
        return (next, @moui.Effect::none())
      }
      let next = {
        ..model,
        scenario: blank_world(name),
        current: Some(name),
        worlds: with_world(model.worlds, name),
        world_name: "",
        selected: None,
      }
      next.conversations.clear()
      next.push_log("新世界「\{name}」已建立")
      match host {
        Some(h) => (next, commit_world_effect(h, name, commit_files(next)))
        None => (next, @moui.Effect::none())
      }
    }
    WorldCommitted(folder, ok) => {
      let next = { ..model, }
      if ok {
        next.push_log("已保存到世界库：\{folder}")
      } else {
        next.push_log(
          "写入失败：\{folder}（世界仍在内存中，可重试或检查文件夹权限）",
        )
      }
      (next, @moui.Effect::none())
    }
    // ---- character creation ----
    ToggleCreator =>
      (
        {
          ..model,
          creator_open: !model.creator_open,
          creator_draft: CharacterDraft::new(),
        },
        @moui.Effect::none(),
      )
    CreatorChanged(draft) =>
      ({ ..model, creator_draft: draft, }, @moui.Effect::none())
    CharacterCreated => {
      let mut name : String = model.creator_draft.name.trim().to_owned()
      if name == "" {
        name = "无名旅人"
      }
      let mut count = 2
      let mut id = name
      while model.scenario.character(id) is Some(_) {
        id = "\{name} (\{count})"
        count += 1
      }
      let card = { ..model.creator_draft, name: id, }.to_card(
        point=first_free_spot(model.scenario),
      )
      let characters : Array[CharacterCard] = []
      for existing in model.scenario.characters() {
        characters.push(existing)
      }
      characters.push(card)
      let scenario = Scenario::new(
        id=model.scenario.id(),
        name=model.scenario.name(),
        background=model.scenario.background(),
        map_width=model.scenario.map_width(),
        map_height=model.scenario.map_height(),
        locations=model.scenario.locations(),
        characters~,
        world_book=model.scenario.world_book(),
      )
      let next = {
        ..model,
        scenario,
        selected: Some(id),
        draft: "",
        creator_open: false,
        creator_draft: CharacterDraft::new(),
      }
      next.push_log("\{id} 加入了这个世界")
      match model.current {
        Some(folder) =>
          match host {
            Some(h) =>
              (next, commit_world_effect(h, folder, commit_files(next)))
            None => (next, @moui.Effect::none())
          }
        None => (next, @moui.Effect::none())
      }
    }
    // ---- AI world generation ----
    WorldIdeaChanged(value) => ({ ..model, idea: value, }, @moui.Effect::none())
    GenerateWorld => {
      let idea : String = model.idea.trim().to_owned()
      if idea == "" {
        let next = { ..model, }
        next.push_log(
          "先写一句话设定世界（例如：雨夜江南小镇的当铺）",
        )
        return (next, @moui.Effect::none())
      }
      if model.generating {
        (model, @moui.Effect::none())
      } else if model.config.llm_enabled() {
        let next = { ..model, generating: true, }
        let prompt = world_idea_prompt(idea)
        let request = LlmRequest::new(
          character_id="!world",
          endpoint=next.config.endpoint(),
          api_key=next.config.api_key(),
          model=next.config.model(),
          temperature=next.config.temperature(),
          system=prompt.system,
          user=prompt.user,
        )
        (
          next,
          @moui.Effect::run(
            key="ai-world:generate",
            kind="provider",
            label="Generate world",
            run=dispatch => {
              runner(request, reply => dispatch(WorldGenerated(reply)))
            },
          ),
        )
      } else {
        // Offline branch: the idea still becomes a world, deterministically.
        let world = fallback_world(idea)
        let folder = world.name()
        let next = {
          ..model,
          scenario: world,
          current: Some(folder),
          idea: "",
          generating: false,
          worlds: with_world(model.worlds, folder),
          selected: None,
        }
        next.conversations.clear()
        next.push_log(
          "（无 key）本地生成了世界「\{folder}」；配置模型后可让AI重新生成",
        )
        match host {
          Some(h) => (next, commit_world_effect(h, folder, commit_files(next)))
          None => (next, @moui.Effect::none())
        }
      }
    }
    WorldGenerated(reply) => {
      let next = { ..model, generating: false, }
      match reply {
        None => {
          next.push_log(
            "AI 生成失败——检查端点与 key，再试一次",
          )
          (next, @moui.Effect::none())
        }
        Some(text) =>
          match extract_json_object(text) {
            None => {
              next.push_log(
                "AI 返回的内容不是可解析的世界 JSON——再试一次或换个说法",
              )
              (next, @moui.Effect::none())
            }
            Some(json) =>
              match Scenario::try_from_json(json) {
                None => {
                  next.push_log(
                    "AI 返回的内容不是可解析的世界 JSON——再试一次或换个说法",
                  )
                  (next, @moui.Effect::none())
                }
                Some(world) => {
                  // The generation lands in the current folder when a world is
                  // open; otherwise it becomes its own new world folder.
                  let folder = match model.current {
                    Some(folder) => folder
                    None => md_safe_name(world.name())
                  }
                  // Keep the world's folder identity stable for future saves.
                  let named = Scenario::new(
                    id=folder,
                    name=world.name(),
                    background=world.background(),
                    map_width=world.map_width(),
                    map_height=world.map_height(),
                    locations=world.locations(),
                    characters=world.characters(),
                    world_book=world.world_book(),
                  )
                  let settled = {
                    ..next,
                    scenario: named,
                    current: Some(folder),
                    idea: "",
                    worlds: with_world(next.worlds, folder),
                    selected: None,
                  }
                  settled.conversations.clear()
                  settled.push_log(
                    "AI 生成了世界「\{world.name()}」（\{world.characters().length()} 角色）",
                  )
                  match host {
                    Some(h) =>
                      (
                        settled,
                        commit_world_effect(h, folder, commit_files(settled)),
                      )
                    None => (settled, @moui.Effect::none())
                  }
                }
              }
          }
      }
    }
    ContextChanged(value) =>
      (
        { ..model, config: model.config.with_context_preset(value), },
        @moui.Effect::none(),
      )
    SummaryArrived(character_id, marker, text) =>
      match text {
        Some(reply) => {
          let next = { ..model, }
          let conversation = next.conversations.for_character(character_id)
          let summary = clip_chars(llm_clean_reply(reply, ""), 600)
          next.conversations.set(conversation.with_summary(summary, marker))
          next.push_log(
            "已压缩 \{character_name(next.scenario, character_id)} 的记忆笔记",
          )
          (next, @moui.Effect::none())
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
          let next = { ..model, }
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
          let next = { ..model, scenario, memory_drafts: drafts, }
          next.push_log("已记住:「\{entry.content()}」")
          match (next.current, host) {
            (Some(folder), Some(h)) =>
              (next, commit_world_effect(h, folder, commit_files(next)))
            _ => (next, @moui.Effect::none())
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
      let next = { ..model, memory_drafts: drafts, }
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
  match scenario.character(id) {
    Some(card) => card.name()
    None => id
  }
}
