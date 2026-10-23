///|
/// The shell's own state: drawers, the message menu, the character rail, the
/// atmosphere view, and the backdrop.
///
/// Split out of `update.mbt` for the same reason as `library.mbt` and
/// `editing.mbt`: one cohesive feature, and a source-file budget that must keep
/// meaning something. Every arm here is session UI state — none of it is world
/// state, none of it persists, and none of it can lose a player's work: the
/// worst a stale drawer can do is show yesterday's card until it is reopened.

///|
/// Dispatch the shell-state arms.
pub fn update_ui(model : WorldModel, msg : Msg) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    OpenDrawer(kind) =>
      // Opening a drawer closes the message menu: two overlays at once is one
      // too many on a phone.
      (
        { ..model.fork(), drawer: Some(kind), message_menu: None, },
        @moui.Effect::none(),
      )
    CloseDrawer => ({ ..model, drawer: None, }, @moui.Effect::none())
    OpenMessageMenu(index) =>
      (
        { ..model.fork(), message_menu: Some(index), drawer: None, },
        @moui.Effect::none(),
      )
    CloseMessageMenu => ({ ..model, message_menu: None, }, @moui.Effect::none())
    ToggleRail =>
      // The rail is a medium/compact affordance; on wide it is always beside
      // the stage, and the toggle is a no-op there rather than a hidden state.
      (
        { ..model, rail_open: !model.rail_open, },
        @moui.Effect::none(),
      )
    ToggleAtmosphere =>
      (
        { ..model, atmosphere: !model.atmosphere, },
        @moui.Effect::none(),
      )
    SetBackdrop(on) => ({ ..model, backdrop: on, }, @moui.Effect::none())
    _ => (model, @moui.Effect::none())
  }
}
