// Raw keyboard access for game-style shells.  The command pipeline
// (`ProgramCommand`) collapses press, repeat and release into one
// activation, which is right for menus and wrong for games: a fighting game
// needs the held set and the press edges separately.  This modifier keeps
// the shortcut-scope identity (so it receives every keyboard event before
// the command map sees any) and hands the event over untouched; the handler
// decides which key events become messages.

///|
priv struct RawKeyModifier[Msg] {
  handle : (KeyboardEvent) -> Msg?
}

///|
fn[Msg] RawKeyModifier::to_any_modifier(
  self : RawKeyModifier[Msg],
) -> AnyModifier[Msg] {
  let handle = self.handle
  {
    ..noop_modifier(),
    identity_kind: "KeyboardShortcut",
    focusable: true,
    event: fn(ctx) {
      match ctx.event {
        Keyboard(event) =>
          match handle(event) {
            Some(message) =>
              // `changed` alone routes the event through the shortcut branch
              // and delivers the message; `activated` stays off so a game's
              // key storm does not request an activation rebuild per key.
              {
                changed: true,
                activated: false,
                focused: false,
                captured: true,
                state: None,
                text_control: None,
                dirty: ViewClean,
                messages: [message],
              }
            None => ViewEventResult::ignored()
          }
        _ => ViewEventResult::ignored()
      }
    },
  }
}

///|
/// Observe every keyboard event (press, repeat, release) routed through the
/// shortcut scope.  Return `Some(message)` to consume the event and deliver
/// the message, or `None` to let it fall through.
pub fn[Msg] View::on_raw_key(
  self : View[Msg],
  handle : (KeyboardEvent) -> Msg?,
) -> View[Msg] {
  self.apply_modifier(RawKeyModifier::{ handle, }.to_any_modifier())
}
