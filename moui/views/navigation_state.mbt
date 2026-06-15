///|
pub struct MenuItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub struct CommandMenuSection {
  title : String
  commands : Array[ActionCommand]
}

///|
pub(all) enum PopoverPlacement {
  BottomStart
  BottomEnd
  TopStart
  TopEnd
}

///|
pub struct DropdownState {
  expanded : Bool
  selected : String
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
pub fn CommandMenuSection::new(
  title~ : String,
  commands~ : Array[ActionCommand],
) -> CommandMenuSection {
  { title, commands }
}

///|
pub fn DropdownState::new(
  expanded? : Bool = false,
  selected? : String = "",
) -> DropdownState {
  { expanded, selected }
}

///|
pub struct SidebarItem[Msg] {
  id : String
  label : String
  message : Msg
  enabled : Bool
}

///|
pub struct SectionNavItem[Msg] {
  id : String
  label : String
  summary : String
  message : Msg
  enabled : Bool
}

///|
pub struct BreadcrumbItem[Msg] {
  id : String
  label : String
  message : Msg?
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
pub fn[Msg] SidebarItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> SidebarItem[Msg] {
  { id, label, message, enabled }
}

///|
pub fn[Msg] SectionNavItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  summary? : String = "",
  enabled? : Bool = true,
) -> SectionNavItem[Msg] {
  { id, label, summary, message, enabled }
}

///|
pub fn[Msg] BreadcrumbItem::new(
  id~ : String,
  label~ : String,
  message? : Msg? = None,
) -> BreadcrumbItem[Msg] {
  { id, label, message }
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
