///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::new(
    init=() => (Model::new(), @moui.Effect::none()),
    update=(model, msg) => model.update(msg),
    view=model => model.view(),
  ).with_commands(commands=model => program_commands(model))
}

///|
/// Every key this demo claims, at program level. Program commands run before the
/// runtime's built-in Tab traversal and before target-only keyboard dispatch, so
/// the arrows belong to the active pane rather than to whichever control happens
/// to hold focus.
///
/// Two rules here are load-bearing, and both exist so the filter box can be typed
/// into:
/// - **no plain letter is claimed.** The terminal decoder emits a `Keyboard` *and*
///   a `TextInput` event for every printable byte
///   (`moui_terminal_host/decode.mbt::emit_text_key`), so claiming `n` would both
///   fire a command and steal the character. Structural keys are `Ctrl` chords,
///   which arrive as `Keyboard` only.
/// - **`Space` and `Enter` are released once the model is in the filter pane.**
///   Otherwise the same press would both toggle a layer and insert a space.
///
/// Arrows stay claimed even in the filter pane: routing them per-role instead of
/// per-pane is the two-rules-in-one-grid mistake the S5 addendum already rejected,
/// so the caret does not move and backspace is the edit key that still works.
pub fn program_commands(model : Model) -> Array[@moui.ProgramCommand[Msg]] {
  let page = scroll_line * 4.0
  let typing = model.pane == FilterPane
  let pane_keys = [
    key_command("Next pane", "Tab", CyclePane(1)),
    key_command("Previous pane", "Tab", CyclePane(-1), shift=true),
    key_command("Left pane", "ArrowLeft", CyclePane(-1)),
    key_command("Right pane", "ArrowRight", CyclePane(1)),
    key_command("Move up", "ArrowUp", Move(-1)),
    key_command("Move down", "ArrowDown", Move(1)),
    key_command("Page up", "PageUp", ScrollBy(model.pane, 0.0 - page)),
    key_command("Page down", "PageDown", ScrollBy(model.pane, page)),
  ]
  let structure = [
    key_command("New layer", "n", AddLayer, control=true),
    key_command("Hide or show layer", "b", ToggleFocused, control=true),
    key_command("Delete layer", "x", RemoveLayer, control=true),
    key_command("New folder", "a", AddNode, control=true),
  ]
  let toggles = [
    key_command("Fold or toggle", "Enter", ToggleFocused),
    key_command("Fold or toggle", " ", ToggleFocused),
  ]
  if typing {
    pane_keys + structure
  } else {
    toggles + pane_keys + structure
  }
}

///|
fn key_command(
  label : String,
  key : String,
  message : Msg,
  shift~ : Bool = false,
  control~ : Bool = false,
  meta~ : Bool = false,
) -> @moui.ProgramCommand[Msg] {
  @moui.ProgramCommand::new(
    command=@views.ActionCommand::new(
      intent=@views.CommandIntent::Activate,
      label~,
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key~,
          modifiers=@views.KeyModifiers::new(shift~, control~, meta~),
        ),
      ),
    ),
    message~,
  )
}
