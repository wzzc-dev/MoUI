///|
#derive(Eq, Debug, ToJson)
pub(all) enum CommandIntent {
  Activate
  Submit
  Cancel
  Copy
  Cut
  Paste
  Undo
  Redo
  SelectAll
  OpenContextMenu
}

///|
pub extend CommandIntent with Debug::{to_repr}

///|
pub extend CommandIntent with Eq::{not_equal, equal}

///|
pub extend CommandIntent with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct ActionCommand {
  intent : CommandIntent
  shortcut : KeyboardShortcut?
  label : String
  enabled : Bool
  group : String
  description : String
  context_menu : Bool
}

///|
pub extend ActionCommand with Debug::{to_repr}

///|
pub extend ActionCommand with Eq::{not_equal, equal}

///|
pub extend ActionCommand with ToJson::{to_json}

///|
struct CommandBinding {
  command : ActionCommand
  handle : () -> Unit
}

///|
struct ActionCommandMap {
  bindings : Array[CommandBinding]
}

///|
pub fn ActionCommand::new(
  intent~ : CommandIntent,
  label~ : String = "",
  shortcut~ : KeyboardShortcut? = None,
  enabled~ : Bool = true,
  group~ : String = "",
  description~ : String = "",
  context_menu~ : Bool = false,
) -> ActionCommand {
  { intent, shortcut, label, enabled, group, description, context_menu, }
}

///|
pub fn ActionCommand::display_label(self : ActionCommand) -> String {
  if self.label != "" {
    self.label
  } else {
    self.intent.display_label()
  }
}

///|
pub fn ActionCommand::shortcut_label(self : ActionCommand) -> String {
  match self.shortcut {
    Some(shortcut) => shortcut.display_label()
    None => ""
  }
}

///|
pub fn CommandIntent::display_label(self : CommandIntent) -> String {
  match self {
    Activate => "Activate"
    Submit => "Submit"
    Cancel => "Cancel"
    Copy => "Copy"
    Cut => "Cut"
    Paste => "Paste"
    Undo => "Undo"
    Redo => "Redo"
    SelectAll => "Select All"
    OpenContextMenu => "Open Context Menu"
  }
}

///|
pub fn KeyboardShortcut::display_label(self : KeyboardShortcut) -> String {
  let parts : Array[String] = []
  if self.modifiers.control {
    parts.push("Ctrl")
  }
  if self.modifiers.alt {
    parts.push("Alt")
  }
  if self.modifiers.shift {
    parts.push("Shift")
  }
  if self.modifiers.meta {
    parts.push("Meta")
  }
  parts.push(keyboard_shortcut_key_label(self.key))
  parts.join("+")
}

///|
fn keyboard_shortcut_key_label(key : String) -> String {
  match key {
    " " => "Space"
    "Escape" => "Esc"
    "ArrowLeft" => "Left"
    "ArrowRight" => "Right"
    "ArrowUp" => "Up"
    "ArrowDown" => "Down"
    _ => key
  }
}

///|
pub fn ActionCommand::matches(
  self : ActionCommand,
  event : KeyboardEvent,
) -> Bool {
  if !self.enabled {
    false
  } else {
    match self.shortcut {
      Some(shortcut) => shortcut.matches(event)
      None => false
    }
  }
}

///|
pub fn CommandBinding::new(
  command~ : ActionCommand,
  handle~ : () -> Unit,
) -> CommandBinding {
  { command, handle, }
}

///|
pub fn ActionCommandMap::new(
  bindings~ : Array[CommandBinding] = [],
) -> ActionCommandMap {
  { bindings, }
}

///|
pub fn ActionCommandMap::commands(
  self : ActionCommandMap,
) -> Array[ActionCommand] {
  self.bindings.map(binding => binding.command)
}

///|
pub fn ActionCommandMap::find_shortcut(
  self : ActionCommandMap,
  event : KeyboardEvent,
) -> ActionCommand? {
  for binding in self.bindings {
    if binding.command.matches(event) {
      return Some(binding.command)
    }
  }
  None
}

///|
pub fn ActionCommandMap::dispatch_shortcut(
  self : ActionCommandMap,
  event : KeyboardEvent,
) -> CommandIntent? {
  for binding in self.bindings {
    if binding.command.matches(event) {
      (binding.handle)()
      return Some(binding.command.intent)
    }
  }
  None
}

///|
pub fn ActionCommandMap::dispatch_intent(
  self : ActionCommandMap,
  intent : CommandIntent,
) -> Bool {
  for binding in self.bindings {
    if binding.command.enabled && binding.command.intent == intent {
      (binding.handle)()
      return true
    }
  }
  false
}

///|
pub fn ActionCommandMap::dispatch_command(
  self : ActionCommandMap,
  command : ActionCommand,
) -> Bool {
  for binding in self.bindings {
    if binding.command.enabled && binding.command == command {
      (binding.handle)()
      return true
    }
  }
  false
}

///|
pub fn default_text_commands() -> Array[ActionCommand] {
  [
    ActionCommand::new(
      intent=Copy,
      label="Copy",
      group="Edit",
      description="Copy the current selection.",
      shortcut=Some(
        KeyboardShortcut::new(key="c", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=Cut,
      label="Cut",
      group="Edit",
      description="Cut the current selection.",
      shortcut=Some(
        KeyboardShortcut::new(key="x", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=Paste,
      label="Paste",
      group="Edit",
      description="Paste clipboard text.",
      shortcut=Some(
        KeyboardShortcut::new(key="v", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=Undo,
      label="Undo",
      group="Edit",
      description="Undo the last text edit.",
      shortcut=Some(
        KeyboardShortcut::new(key="z", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=Redo,
      label="Redo",
      group="Edit",
      description="Redo the last undone text edit.",
      shortcut=Some(
        KeyboardShortcut::new(
          key="z",
          modifiers=KeyModifiers::new(shift=true, meta=true),
        ),
      ),
    ),
    ActionCommand::new(
      intent=SelectAll,
      label="Select All",
      group="Edit",
      description="Select all text in the focused input.",
      shortcut=Some(
        KeyboardShortcut::new(key="a", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
  ]
}
