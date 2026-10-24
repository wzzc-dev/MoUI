///|
/// Host effects: the typed bridges between `update` and the injected
/// `WorldHost`, plus the folder payload every commit writes.
///
/// These live outside `update.mbt` on purpose. A completion message
/// (`WorldFilesArrived`, `ConfigFileLoaded`, `WorldCommitted`, …) is only ever
/// constructed here, inside the effect callback the host calls — so keeping
/// the constructors next to the message declaration made every one of them
/// look like dead UI to the gate. With the protocol in `msg.mbt` and the
/// effect constructors here, both real construction sites are visible.

///|
/// Effect: list the library without interaction.
fn sync_library_effect(host : WorldHost) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="new-world:library",
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
    key="new-world:open",
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
    key="new-world:config-read",
    kind="filesystem",
    label="Load settings",
    run=dispatch => (host.read_config)(text => dispatch(ConfigFileLoaded(text))),
  )
}

///|
/// Effect: write the library-root config file.
fn write_config_effect(host : WorldHost, json : String) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="new-world:config-write",
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
    key="new-world:commit",
    kind="filesystem",
    label="Save world \{folder}",
    run=dispatch => {
      (host.write_world)(folder, files, ok => {
        dispatch(WorldCommitted(folder, ok))
        // A world-scope commit can bring a new picture into the folder: the
        // editor's 立绘 field points at a file the player just dropped in
        // beside the card. The model caches the world's portraits, so it has
        // to re-read them — otherwise the picture would only show up after a
        // restart of the app.
        if ok && files_hold_a_world_file(files) {
          (host.read_world)(folder, (read_ok, read_files) => {
            if read_ok {
              dispatch(WorldPortraitsRefreshed(portraits_of(read_files)))
            }
          })
        }
      })
    },
  )
}

///|
/// Does this commit rewrite the world's description (rather than only the
/// journal)? Only such a commit can change the world's portraits.
fn files_hold_a_world_file(files : Array[(String, String)]) -> Bool {
  for pair in files {
    if is_world_file_name(pair.0) {
      return true
    }
  }
  false
}

///|
/// The portrait assets among a folder's files: `(path, base64)`.
fn portraits_of(files : Array[(String, String)]) -> Array[(String, String)] {
  let portraits : Array[(String, String)] = []
  for pair in files {
    if is_portrait_file_name(pair.0) {
      portraits.push(pair)
    }
  }
  portraits
}

///|
/// Effect: put the prompt preview on the clipboard.
fn copy_prompt_effect(
  host : WorldHost,
  text : String,
) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="new-world:copy-prompt",
    kind="clipboard",
    label="Copy prompt",
    run=_dispatch => {
      (host.copy_to_clipboard)(text)
    },
  )
}

///|
/// What part of a world folder a commit has to rewrite.
///
/// Writing the whole folder on every turn is correct but wasteful: a world with
/// eight characters meant nine file writes for a single line of dialogue, and
/// the in-page fallback library re-serialized every world in one localStorage
/// key. The scope separates "the world description changed" (new world, new
/// character, AI generation, accepted memory) from "one conversation grew"
/// (send / reply), which is by far the hot path.
pub(all) enum CommitScope {
  /// `world.md`, `world_book.md`, and every character card.
  World
  /// Exactly one character's conversation file, plus the event log.
  Conversation(String)
  /// Exactly one character's memory file, plus the event log. A memory edit
  /// is rarer than a turn but hotter than a world rewrite.
  Memories(String)
} derive(Eq, Debug)

///|
pub extend CommitScope with Debug::{to_repr}

///|
pub extend CommitScope with Eq::{not_equal, equal}

///|
/// The journal files a scope rewrites, besides the Markdown world.
fn journal_files(
  model : WorldModel,
  scope : CommitScope,
) -> Array[(String, String)] {
  let files : Array[(String, String)] = []
  match scope {
    World => {
      // Every conversation, one file each, plus the index that says which of
      // them belong to this world. An empty conversation is still written: a
      // skipped file would leave the previous history on disk, so clearing a
      // chat would come back the next time the world loads. Hosts never delete
      // files, so "empty" has to be expressed as an empty document.
      for conversation in model.conversations.entries {
        files.push(
          (
            conversation_path(conversation.character_id()),
            conversation.to_json_text(),
          ),
        )
      }
      files.push(conversation_index(model))
    }
    Conversation(id) => {
      // Even when empty: this is how a clear reaches the disk.
      let conversation = model.conversations.for_character(id)
      files.push((conversation_path(id), conversation.to_json_text()))
    }
    // A memory edit carries no journal beyond the event log the notice rode
    // in on; the memory file itself is written by `commit_files`.
    Memories(_) => ()
  }
  files.push((events_file, events_json_text(model.log)))
  files
}

///|
/// The folder payload for one commit.
fn commit_files(
  model : WorldModel,
  scope : CommitScope,
) -> Array[(String, String)] {
  let files : Array[(String, String)] = match scope {
    World => {
      let world = model.scenario.world_files()
      // Portrait bytes are world content, not a UI cache: without them a world
      // exported to another machine comes back with every face missing. The
      // Markdown only carries the file *name* (`portrait:`), so the asset has
      // to ride alongside it or the reference dangles.
      for pair in model.portraits {
        // `pair.0` is already the folder-relative path the read side produced
        // (`characters/<名>.png`). Re-deriving it through `world_folder_name`
        // turned the separator into `_` and prefixed `characters/` again, so the
        // exported asset was written as `characters/characters_<名>.png` and no
        // card could resolve it. Portraits also live only under `characters/`.
        world.push((portrait_world_path(pair.0), pair.1))
      }
      // The interaction memories ride beside the cards, one file per
      // character — the same "readable folder" promise, and the reason a
      // memory edit survives a world-scope commit.
      for record in model.memories.entries {
        if !record.entries().is_empty() {
          world.push(
            (
              memory_path(record.character_id()),
              memory_md_text(record.entries()),
            ),
          )
        }
      }
      world
    }
    // A conversation turn does not touch the world description or the cards.
    Conversation(_) => []
    // A memory edit rewrites exactly one memory file; the card beside it is
    // untouched.
    Memories(id) => {
      let record = model.memories.for_character(id)
      [
        (memory_path(id), memory_md_text(record.entries())),
      ]
    }
  }
  let journal = journal_files(model, scope)
  for file in journal {
    files.push(file)
  }
  files
}

///|
/// The list of conversation files this world owns.
///
/// Written on every world-scope commit. Reading uses it to ignore orphaned
/// `conversations/*.json` left behind by a replaced world: without it, a
/// regenerated world that happens to reuse a character name would silently
/// inherit the previous world's history. Hosts never delete anything — the
/// files stay in the player's folder, which is the point of a folder database.
fn conversation_index(model : WorldModel) -> (String, String) {
  let paths : Array[Json] = []
  for conversation in model.conversations.entries {
    if !conversation.lines().is_empty() {
      paths.push(Json::string(conversation_path(conversation.character_id())))
    }
  }
  (
    conversation_index_file,
    Json::object({ "conversations": Json::array(paths) }).stringify(),
  )
}

///|
/// Commit the journal (and with it the world) when a world folder and a host
/// both exist; otherwise this is a no-op — running without a library still
/// plays fine, it just persists nothing.
fn commit_effect(
  model : WorldModel,
  world_host : WorldHost?,
  scope : CommitScope,
) -> @moui.Effect[Msg] {
  match (model.current, world_host) {
    (Some(folder), Some(host)) =>
      commit_world_effect(host, folder, commit_files(model, scope))
    _ => @moui.Effect::none()
  }
}

///|
/// Effect: write the current world out as a shareable bundle.
///
/// The payload is the same file set a world-scope commit writes, so the bundle
/// is the world folder — importing it elsewhere reproduces the world exactly,
/// including the journal. It deliberately excludes `config.json`: that file
/// holds the player's provider endpoint and belongs to the library, not to a
/// world.
fn export_world_effect(
  host : WorldHost,
  folder : String,
  files : Array[(String, String)],
) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="new-world:export",
    kind="filesystem",
    label="Export world \{folder}",
    run=dispatch => {
      (host.export_world)(folder, files, ok => dispatch(WorldExported(ok)))
    },
  )
}

///|
/// Effect: pick a bundle and add it to the library.
fn import_world_effect(host : WorldHost) -> @moui.Effect[Msg] {
  @moui.Effect::run(
    key="new-world:import",
    kind="filesystem",
    label="Import world",
    run=dispatch => {
      (host.import_world)((ok, folder, files) => {
        dispatch(WorldImported(ok, folder, files))
      })
    },
  )
}
