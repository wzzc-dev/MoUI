// MenuItem, ActionItem, CommandMenuSection, WizardStep moved to controls/
// sub-package and re-exported here. PopoverPlacement and DropdownState live
// in the popover/ sub-package; they are re-exported to root from there.
///|
pub using @controls {
  type MenuItem,
  menu_item,
  type ActionItem,
  action_item,
  type CommandMenuSection,
  command_menu_section,
  type WizardStep,
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
pub fn[Msg] SidebarItem::new(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> SidebarItem[Msg] {
  { id, label, message, enabled }
}

///|
pub fn[Msg] sidebar_item(
  id~ : String,
  label~ : String,
  message~ : Msg,
  enabled? : Bool = true,
) -> SidebarItem[Msg] {
  SidebarItem::new(id~, label~, message~, enabled~)
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
pub fn[Msg] section_nav_item(
  id~ : String,
  label~ : String,
  message~ : Msg,
  summary? : String = "",
  enabled? : Bool = true,
) -> SectionNavItem[Msg] {
  SectionNavItem::new(id~, label~, message~, summary~, enabled~)
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
pub fn[Msg] breadcrumb_item(
  id~ : String,
  label~ : String,
  message? : Msg? = None,
) -> BreadcrumbItem[Msg] {
  BreadcrumbItem::new(id~, label~, message~)
}
