///|
/// Program assembly: the TEA root.
///
/// The shared app package is a pure TEA package and never performs IO itself.
/// The platform entrypoint injects a `TurnRunner` (the provider worker) and a
/// `WorldHost` (the folder database). Both injections are optional: without
/// them the world still runs, with the library unavailable and the provider
/// path replaced by local scripted replies.

///|
pub fn program(
  turn_runner? : TurnRunner,
  world_host? : WorldHost,
) -> @moui.Program[WorldModel, Msg] {
  @moui.Program::new(
    init=() => {
      let model = WorldModel::new()
      // Kick one library sync: the first world opens automatically, and the
      // settings load rides on the listing arrival (`WorldListArrived`), when
      // the host bridge is fully past the boot race.
      let effect = match world_host {
        Some(host) => sync_library_effect(host)
        None => @moui.Effect::none()
      }
      (model, effect)
    },
    update=(model, msg) => update(model, msg, turn_runner?, world_host?),
    view=model => view(model),
  )
}
