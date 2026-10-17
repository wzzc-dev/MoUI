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

