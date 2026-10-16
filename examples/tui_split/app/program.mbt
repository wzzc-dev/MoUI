///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::new(
    init=() => (Model::new(), @moui.Effect::none()),
    update=(model, msg) => model.update(msg),
    view=model => model.view(),
  ).with_commands(commands=model => program_commands(model))
}

///|
/// Every key the demo claims, at program level. These run before the runtime's
/// built-in Tab traversal and before target-only keyboard dispatch, so the
/// arrows belong to the pane rather than to whichever control happens to hold
/// focus. The messages are modelled from the active pane, which is why this is a
/// function of the model and not a constant list.
pub fn program_commands(model : Model) -> Array[@moui.ProgramCommand[Msg]] {
  let page = scroll_line * 4.0
  [
    key_command("Next pane", "Tab", CyclePane(1)),
    key_command("Previous pane", "Tab", CyclePane(-1), shift=true),
    key_command("Left pane", "ArrowLeft", CyclePane(-1)),
    key_command("Right pane", "ArrowRight", CyclePane(1)),
    key_command("Move up", "ArrowUp", Move(-1)),
    key_command("Move down", "ArrowDown", Move(1)),
    key_command("Page up", "PageUp", ScrollBy(model.pane, 0.0 - page)),
    key_command("Page down", "PageDown", ScrollBy(model.pane, page)),
    key_command("Fold or unfold", "Enter", ToggleFocusedNode),
    key_command("Fold or unfold", " ", ToggleFocusedNode),
    key_command("Add entry at top", "n", InsertEntry),
    key_command("Add folder at top", "a", AddNode),
    key_command("Delete selected", "d", RemoveFocused),
  ]
}

///|
fn key_command(
  label : String,
  key : String,
  message : Msg,
  shift? : Bool = false,
  control? : Bool = false,
  meta? : Bool = false,
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
