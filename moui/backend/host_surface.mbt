///|
pub(all) enum HostCoordinateSpace {
  LogicalPixels
  PhysicalPixels
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostCoordinatePolicy {
  input_space : HostCoordinateSpace
  surface_space : HostCoordinateSpace
  scale_factor_applied : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostBackendKind {
  Native
  Web
  Wechat
  Test
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostAppInfo {
  backend : HostBackendKind
  uses_shared_event_model : Bool
  uses_shared_surface_model : Bool
  uses_shared_input_model : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostInputCapabilities {
  pointer : Bool
  scroll : Bool
  keyboard : Bool
  focus : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  drag_drop : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostServiceCapabilities {
  clipboard : Bool
  menus : Bool
  file_dialogs : Bool
  file_access : Bool
  open_url : Bool
  system_theme : Bool
  settings : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn HostCoordinatePolicy::logical(
  description? : String = "Host input and surface metrics use logical pixels after DPR scaling.",
) -> HostCoordinatePolicy {
  {
    input_space: HostCoordinateSpace::LogicalPixels,
    surface_space: HostCoordinateSpace::LogicalPixels,
    scale_factor_applied: true,
    description,
  }
}

///|
pub fn HostCoordinatePolicy::physical(
  description? : String = "Host input and surface metrics use physical pixels.",
) -> HostCoordinatePolicy {
  {
    input_space: HostCoordinateSpace::PhysicalPixels,
    surface_space: HostCoordinateSpace::PhysicalPixels,
    scale_factor_applied: false,
    description,
  }
}

///|
pub fn HostAppInfo::new(
  backend~ : HostBackendKind,
  description? : String = "",
  uses_shared_event_model? : Bool = true,
  uses_shared_surface_model? : Bool = true,
  uses_shared_input_model? : Bool = true,
) -> HostAppInfo {
  {
    backend,
    uses_shared_event_model,
    uses_shared_surface_model,
    uses_shared_input_model,
    description,
  }
}

///|
pub fn HostInputCapabilities::new(
  pointer? : Bool = true,
  scroll? : Bool = true,
  keyboard? : Bool = true,
  focus? : Bool = true,
  text_input? : Bool = true,
  ime? : Bool = false,
  clipboard? : Bool = false,
  drag_drop? : Bool = false,
) -> HostInputCapabilities {
  { pointer, scroll, keyboard, focus, text_input, ime, clipboard, drag_drop }
}

///|
pub fn HostInputCapabilities::none() -> HostInputCapabilities {
  {
    pointer: false,
    scroll: false,
    keyboard: false,
    focus: false,
    text_input: false,
    ime: false,
    clipboard: false,
    drag_drop: false,
  }
}

///|
pub fn HostServiceCapabilities::none() -> HostServiceCapabilities {
  {
    clipboard: false,
    menus: false,
    file_dialogs: false,
    file_access: false,
    open_url: false,
    system_theme: false,
    settings: false,
  }
}

///|
pub fn HostServiceCapabilities::new(
  clipboard? : Bool = false,
  menus? : Bool = false,
  file_dialogs? : Bool = false,
  file_access? : Bool = false,
  open_url? : Bool = false,
  system_theme? : Bool = false,
  settings? : Bool = false,
) -> HostServiceCapabilities {
  {
    clipboard,
    menus,
    file_dialogs,
    file_access,
    open_url,
    system_theme,
    settings,
  }
}

///|
