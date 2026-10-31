///|
/// Per-program action-command sync state (plan
/// hot-path-invalidation-boilerplate-convergence D1). `runtime_commands(model)`
/// is re-derived after every message, but the map and its dispatch handles only
/// need rebuilding when the derived command set actually changes: scroll and
/// pointer storms re-derive an unchanged list many times per frame, and a
/// rebuild would reallocate every closure each time.
///
/// Correctness with model-dependent messages: the fingerprint covers only the
/// `ActionCommand` list (intent, shortcut, label, enabled, ...). The handles do
/// not capture the message values from build time — they index into
/// `latest_commands`, which every sync refreshes, so a handle always dispatches
/// the message derived from the current model even when the map itself is
/// reused. A changed fingerprint (menu opened, command disabled, set edited)
/// rebuilds the map against the new list.
priv struct ProgramCommandSync[Msg] {
  latest_commands : Ref[Array[@core.ProgramCommand[Msg]]]
  mut cached_commands : Array[@core.ActionCommand]
  mut cached_map : ActionCommandMap?
}

///|
fn[Msg] ProgramCommandSync::new() -> ProgramCommandSync[Msg] {
  { latest_commands: Ref([]), cached_commands: [], cached_map: None, }
}

///|
/// Folds a freshly derived command list into the cache. Returns the map to
/// install, or `None` when the derived `ActionCommand` list equals the cached
/// one — the installed map is already current, so the caller skips
/// `set_action_commands` entirely.
fn[Msg] ProgramCommandSync::sync(
  self : ProgramCommandSync[Msg],
  commands : Array[@core.ProgramCommand[Msg]],
  dispatch : (Msg) -> Unit,
) -> ActionCommandMap? {
  self.latest_commands.val = commands
  let fingerprints = commands.map(command => command.command())
  match self.cached_map {
    Some(_) if fingerprints == self.cached_commands => {
      // Unchanged set: keep the closures and the map; refresh the fingerprint
      // copy so the cache does not pin the previous derivation's array.
      self.cached_commands = fingerprints
      None
    }
    _ => {
      let latest = self.latest_commands
      let bindings : Array[@core.CommandBinding] = []
      for index, program_command in commands {
        bindings.push(
          @core.CommandBinding::new(command=program_command.command(), handle=() => {
            let current = latest.val
            if index < current.length() {
              dispatch(current[index].message())
            }
          }),
        )
      }
      let map = ActionCommandMap::new(bindings~)
      self.cached_commands = fingerprints
      self.cached_map = Some(map)
      Some(map)
    }
  }
}
