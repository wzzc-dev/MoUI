///|
/// Window-hosted mobile capability defaults shared verbatim by the Android,
/// iOS, and HarmonyOS backends. Every capability value lives here exactly
/// once; the platform packages declare only their deviations (the first
/// capability-matrix field name — `embedded_view` on iOS vs
/// `embedded_surface` on Android/HarmonyOS — and their typed surface
/// bindings).

///|
/// Input capabilities of the window-hosted mobile runtimes: full
/// pointer/scroll/keyboard/focus/text-input/IME/clipboard support and no
/// drag-drop.
pub fn mobile_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=true,
    focus=true,
    text_input=true,
    ime=true,
    clipboard=true,
    drag_drop=false,
  )
}

///|
/// Service capabilities of the window-hosted mobile runtimes. Platform
/// callbacks supply window-hosted services; matching-device/simulator
/// evidence remains partial (see each backend's readiness status).
pub fn mobile_service_capabilities() -> @host.HostServiceCapabilities {
  @host.HostServiceCapabilities::new(clipboard=true)
}

///|
/// Canonical capability-matrix values of the window-hosted mobile runtimes.
/// `embedded_view` is the canonical first-field name (iOS); Android and
/// HarmonyOS publish the same value under `embedded_surface`.
pub struct MobileEmbeddedCapabilities {
  embedded_view : Bool
  external_event_loop : Bool
  surface_binding : Bool
  pointer : Bool
  scroll : Bool
  keyboard : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  system_theme : Bool
  accessibility : Bool
  async_image : Bool
}

///|
pub fn mobile_embedded_capabilities() -> MobileEmbeddedCapabilities {
  {
    embedded_view: true,
    external_event_loop: true,
    surface_binding: true,
    pointer: true,
    scroll: true,
    keyboard: true,
    text_input: true,
    ime: true,
    clipboard: true,
    system_theme: false,
    accessibility: true,
    async_image: true,
  }
}
