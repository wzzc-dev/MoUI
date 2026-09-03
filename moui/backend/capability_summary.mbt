///|
pub(all) struct HostCapabilitySummary {
  backend : HostBackendKind
  label : String
  services : HostServiceCapabilities
  input : HostInputCapabilities
  window_lifecycle : Bool
  multi_window : Bool
  text_input_available : Bool
  ime_available : Bool
  drag_drop_available : Bool
  async_services : Bool
  native_accessibility_available : Bool
  web_view_available : Bool
  host_modal_available : Bool
  web_view_description : String
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn HostCapabilitySummary::new(
  backend~ : HostBackendKind,
  label? : String = "Host",
  services? : HostServiceCapabilities = HostServiceCapabilities::none(),
  input? : HostInputCapabilities = HostInputCapabilities::none(),
  window_lifecycle? : Bool = false,
  multi_window? : Bool = false,
  text_input_available? : Bool = input.text_input,
  ime_available? : Bool = input.ime,
  drag_drop_available? : Bool = input.drag_drop,
  async_services? : Bool = false,
  native_accessibility_available? : Bool = false,
  web_view_available? : Bool = false,
  host_modal_available? : Bool = false,
  web_view_description? : String = "Native WebView is unavailable on this host.",
  description? : String = "",
) -> HostCapabilitySummary {
  {
    backend,
    label,
    services,
    input,
    window_lifecycle,
    multi_window,
    text_input_available,
    ime_available,
    drag_drop_available,
    async_services,
    native_accessibility_available,
    web_view_available,
    host_modal_available,
    web_view_description,
    description,
  }
}

///|
pub fn HostCapabilitySummary::from_contracts(
  info~ : HostAppInfo,
  services~ : HostServiceCapabilities,
  input~ : HostInputCapabilities,
  label? : String = info.backend.label(),
  window_lifecycle? : Bool = true,
  multi_window? : Bool = false,
  text_input_available? : Bool = input.text_input,
  ime_available? : Bool = input.ime,
  drag_drop_available? : Bool = input.drag_drop,
  async_services? : Bool = false,
  native_accessibility_available? : Bool = false,
  web_view_available? : Bool = false,
  host_modal_available? : Bool = false,
  web_view_description? : String = "Native WebView is unavailable on this host.",
  description? : String = info.description,
) -> HostCapabilitySummary {
  HostCapabilitySummary::new(
    backend=info.backend,
    label~,
    services~,
    input~,
    window_lifecycle~,
    multi_window~,
    text_input_available~,
    ime_available~,
    drag_drop_available~,
    async_services~,
    native_accessibility_available~,
    web_view_available~,
    host_modal_available~,
    web_view_description~,
    description~,
  )
}

///|
pub fn HostCapabilitySummary::unavailable(
  label? : String = "Unavailable host",
  description? : String = "No platform host capability summary is available.",
) -> HostCapabilitySummary {
  HostCapabilitySummary::new(
    backend=HostBackendKind::Test,
    label~,
    description~,
  )
}

///|
pub fn HostCapabilitySummary::test_host(
  label? : String = "Test host",
) -> HostCapabilitySummary {
  HostCapabilitySummary::from_contracts(
    info=HostAppInfo::new(
      backend=HostBackendKind::Test,
      description="In-process test host using shared runtime contracts.",
    ),
    services=HostServiceCapabilities::none(),
    input=HostInputCapabilities::new(
      pointer=true,
      scroll=true,
      keyboard=true,
      focus=true,
      text_input=true,
    ),
    label~,
    window_lifecycle=false,
  )
}

///|
pub fn HostCapabilitySummary::has_required_app_basics(
  self : HostCapabilitySummary,
) -> Bool {
  self.input.pointer &&
  self.input.keyboard &&
  self.input.focus &&
  self.window_lifecycle
}

///|
pub fn HostCapabilitySummary::service_count(
  self : HostCapabilitySummary,
) -> Int {
  bool_score(self.services.clipboard) +
  bool_score(self.services.menus) +
  bool_score(self.services.file_dialogs) +
  bool_score(self.services.file_access) +
  bool_score(self.services.open_url) +
  bool_score(self.services.system_theme)
}

///|
pub fn HostCapabilitySummary::input_count(self : HostCapabilitySummary) -> Int {
  bool_score(self.input.pointer) +
  bool_score(self.input.scroll) +
  bool_score(self.input.keyboard) +
  bool_score(self.input.focus) +
  bool_score(self.text_input_available) +
  bool_score(self.ime_available) +
  bool_score(self.drag_drop_available)
}

///|
pub fn HostCapabilitySummary::preflight_fields(
  self : HostCapabilitySummary,
) -> String {
  "host=\{self.label}; host_services=\{host_capability_label_list(self.services.enabled_labels())}; host_input=\{host_capability_label_list(self.input.enabled_labels())}; clipboard=\{host_capability_available_label(self.services.clipboard)}; menu_service=\{host_capability_available_label(self.services.menus)}; file_dialogs=\{host_capability_available_label(self.services.file_dialogs)}; file_access=\{host_capability_available_label(self.services.file_access)}; open_url=\{host_capability_available_label(self.services.open_url)}; system_theme=\{host_capability_available_label(self.services.system_theme)}; async_services=\{host_capability_available_label(self.async_services)}; window_lifecycle=\{host_capability_available_label(self.window_lifecycle)}; multi_window=\{host_capability_available_label(self.multi_window)}; text_input=\{host_capability_available_label(self.text_input_available)}; ime=\{host_capability_available_label(self.ime_available)}; drag_drop=\{host_capability_available_label(self.drag_drop_available)}; native_context_menu=\{host_capability_available_label(self.services.menus)}; host_modal=\{host_capability_available_label(self.host_modal_available)}; native_accessibility=\{host_capability_available_label(self.native_accessibility_available)}; web_view=\{host_capability_available_label(self.web_view_available)}"
}

///|
pub fn HostBackendKind::label(self : HostBackendKind) -> String {
  match self {
    Native => "Native"
    Web => "Web"
    Wechat => "WeChat"
    Test => "Test"
  }
}

///|
pub fn HostServiceCapabilities::enabled_labels(
  self : HostServiceCapabilities,
) -> Array[String] {
  let labels : Array[String] = []
  if self.clipboard {
    labels.push("clipboard")
  }
  if self.menus {
    labels.push("menus")
  }
  if self.file_dialogs {
    labels.push("file dialogs")
  }
  if self.file_access {
    labels.push("file access")
  }
  if self.open_url {
    labels.push("open URL")
  }
  if self.system_theme {
    labels.push("system theme")
  }
  labels
}

///|
pub fn HostInputCapabilities::enabled_labels(
  self : HostInputCapabilities,
) -> Array[String] {
  let labels : Array[String] = []
  if self.pointer {
    labels.push("pointer")
  }
  if self.scroll {
    labels.push("scroll")
  }
  if self.keyboard {
    labels.push("keyboard")
  }
  if self.focus {
    labels.push("focus")
  }
  if self.text_input {
    labels.push("text input")
  }
  if self.ime {
    labels.push("IME")
  }
  if self.clipboard {
    labels.push("clipboard shortcuts")
  }
  if self.drag_drop {
    labels.push("drag/drop")
  }
  labels
}

///|
fn bool_score(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}

///|
fn host_capability_label_list(labels : Array[String]) -> String {
  if labels.is_empty() {
    "none"
  } else {
    labels.join(",")
  }
}

///|
fn host_capability_available_label(value : Bool) -> String {
  if value {
    "available"
  } else {
    "gap"
  }
}
