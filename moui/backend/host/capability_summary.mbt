///|
pub(all) struct HostCapabilitySummary {
  backend : HostBackendKind
  label : String
  services : HostServiceCapabilities
  input : HostInputCapabilities
  window_lifecycle : Bool
  multi_window : Bool
  text_input_ready : Bool
  ime_ready : Bool
  drag_drop_ready : Bool
  async_services : Bool
  native_accessibility_ready : Bool
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
  text_input_ready? : Bool = input.text_input,
  ime_ready? : Bool = input.ime,
  drag_drop_ready? : Bool = input.drag_drop,
  async_services? : Bool = false,
  native_accessibility_ready? : Bool = false,
  description? : String = "",
) -> HostCapabilitySummary {
  {
    backend,
    label,
    services,
    input,
    window_lifecycle,
    multi_window,
    text_input_ready,
    ime_ready,
    drag_drop_ready,
    async_services,
    native_accessibility_ready,
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
  text_input_ready? : Bool = input.text_input,
  ime_ready? : Bool = input.ime,
  drag_drop_ready? : Bool = input.drag_drop,
  async_services? : Bool = false,
  native_accessibility_ready? : Bool = false,
  description? : String = info.description,
) -> HostCapabilitySummary {
  HostCapabilitySummary::new(
    backend=info.backend,
    label~,
    services~,
    input~,
    window_lifecycle~,
    multi_window~,
    text_input_ready~,
    ime_ready~,
    drag_drop_ready~,
    async_services~,
    native_accessibility_ready~,
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
  bool_score(self.services.open_url) +
  bool_score(self.services.system_theme)
}

///|
pub fn HostCapabilitySummary::input_count(self : HostCapabilitySummary) -> Int {
  bool_score(self.input.pointer) +
  bool_score(self.input.scroll) +
  bool_score(self.input.keyboard) +
  bool_score(self.input.focus) +
  bool_score(self.text_input_ready) +
  bool_score(self.ime_ready) +
  bool_score(self.drag_drop_ready)
}

///|
pub fn HostBackendKind::label(self : HostBackendKind) -> String {
  match self {
    Native => "Native"
    Web => "Web"
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
