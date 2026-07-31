// Shared state/action types used by controls/ and re-exported by root.
// These live here so controls/ can reference them without importing the
// parent package (which would be circular).

///|
pub struct StateViewAction[Msg] {
  label : String
  message : Msg
}

///|
pub fn[Msg] StateViewAction::new(
  label~ : String,
  message~ : Msg,
) -> StateViewAction[Msg] {
  { label, message }
}

///|
pub struct MenuItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub struct ActionItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub struct CommandMenuSection {
  title : String
  commands : Array[@core.ActionCommand]
}

///|
pub struct WizardStep[Msg] {
  id : String
  title : String
  subtitle : String
  content : @core.View[Msg]
  enabled : Bool
}

///|
pub fn[Msg] MenuItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> MenuItem[Msg] {
  { id, label, message, enabled }
}

///|
pub fn[Msg] menu_item(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> MenuItem[Msg] {
  MenuItem::new(id~, label~, message~, enabled~)
}

///|
pub fn[Msg] ActionItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> ActionItem[Msg] {
  { id, label, message, enabled }
}

///|
pub fn[Msg] action_item(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> ActionItem[Msg] {
  ActionItem::new(id~, label~, message~, enabled~)
}

///|
pub fn CommandMenuSection::new(
  title~ : String,
  commands~ : Array[@core.ActionCommand],
) -> CommandMenuSection {
  { title, commands }
}

///|
pub fn command_menu_section(
  title~ : String,
  commands~ : Array[@core.ActionCommand],
) -> CommandMenuSection {
  CommandMenuSection::new(title~, commands~)
}

///|
pub fn[Msg] WizardStep::new(
  id~ : String,
  title~ : String,
  subtitle? : String = "",
  content~ : @core.View[Msg],
  enabled? : Bool = true,
) -> WizardStep[Msg] {
  { id, title, subtitle, content, enabled }
}
