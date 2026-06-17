///|
pub(all) struct HostInputContract {
  capabilities : HostInputCapabilities
  coordinates : HostCoordinatePolicy
} derive(Eq, Debug, ToJson)

///|
pub(all) struct InputHostState {
  mut focused : Bool
  mut modifiers : @core.KeyModifiers
  contract : HostInputContract
}

///|
pub(all) enum HostScrollPhase {
  Started
  Moved
  Ended
  Cancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostScrollDelta {
  Lines(@core.Point)
  Pixels(@core.Point)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostScrollEvent {
  position : @core.Point
  delta : HostScrollDelta
  phase : HostScrollPhase
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostFocusEvent {
  focused : Bool
  pointer_cancel_position : @core.Point?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostEvent {
  Resized(HostSurfaceMetrics)
  Pointer(@core.PointerEvent)
  Scroll(HostScrollEvent)
  Focus(HostFocusEvent)
  Keyboard(@core.KeyboardEvent)
  TextInput(@core.TextInputEvent)
  DragDrop(@core.DragDropEvent)
  WebView(String, WebViewEvent)
  ThemeChanged(@core.ColorScheme)
  Command(@core.CommandIntent)
  RedrawRequested
  CloseRequested
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostEventResult {
  needs_rebuild : Bool
  needs_redraw : Bool
  redraw_requested : Bool
  close_requested : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn HostInputContract::new(
  capabilities? : HostInputCapabilities = HostInputCapabilities::new(),
  coordinates? : HostCoordinatePolicy = HostCoordinatePolicy::logical(),
) -> HostInputContract {
  { capabilities, coordinates }
}

///|
pub fn InputHostState::new(
  focused? : Bool = false,
  modifiers? : @core.KeyModifiers = @core.KeyModifiers::none(),
  contract? : HostInputContract = HostInputContract::new(),
) -> InputHostState {
  { focused, modifiers, contract }
}

///|
pub fn InputHostState::focus(self : InputHostState) -> Unit {
  self.focused = true
}

///|
pub fn InputHostState::blur(self : InputHostState) -> Unit {
  self.focused = false
}

///|
pub fn InputHostState::set_modifiers(
  self : InputHostState,
  modifiers : @core.KeyModifiers,
) -> Unit {
  self.modifiers = modifiers
}

///|
pub fn InputHostState::capabilities(
  self : InputHostState,
) -> HostInputCapabilities {
  self.contract.capabilities
}

///|
pub fn InputHostState::coordinate_policy(
  self : InputHostState,
) -> HostCoordinatePolicy {
  self.contract.coordinates
}

///|
pub fn InputHostState::focus_event(
  self : InputHostState,
  focused~ : Bool,
  pointer_cancel_position? : @core.Point? = None,
) -> HostEvent? {
  if self.contract.capabilities.focus {
    self.focused = focused
    Some(
      HostEvent::Focus(HostFocusEvent::new(focused~, pointer_cancel_position~)),
    )
  } else {
    None
  }
}

///|
pub fn InputHostState::keyboard_event(
  self : InputHostState,
  key~ : String,
  text? : String? = None,
  pressed? : Bool = true,
  repeat? : Bool = false,
) -> HostEvent? {
  if self.contract.capabilities.keyboard {
    Some(
      HostEvent::Keyboard(
        @core.KeyboardEvent::new(
          key~,
          text~,
          pressed~,
          repeat~,
          modifiers=self.modifiers,
        ),
      ),
    )
  } else {
    None
  }
}

///|
pub fn InputHostState::text_event(
  self : InputHostState,
  event : @core.TextInputEvent,
) -> HostEvent? {
  if self.focused && self.contract.capabilities.text_input {
    Some(HostEvent::TextInput(event))
  } else {
    None
  }
}

///|
pub fn InputHostState::insert_text(
  self : InputHostState,
  text : String,
) -> HostEvent? {
  self.text_event(@core.TextInputEvent::InsertText(text))
}

///|
pub fn HostScrollEvent::new(
  position~ : @core.Point,
  delta~ : HostScrollDelta,
  phase? : HostScrollPhase = HostScrollPhase::Moved,
) -> HostScrollEvent {
  { position, delta, phase }
}

///|
pub fn HostScrollDelta::to_logical_pixels(
  self : HostScrollDelta,
  line_extent? : Double = 40.0,
) -> @core.Point {
  match self {
    Pixels(delta) => delta
    Lines(delta) =>
      @core.Point::new(x=delta.x * line_extent, y=delta.y * line_extent)
  }
}

///|
pub fn HostScrollEvent::to_pointer_event(
  self : HostScrollEvent,
) -> @core.PointerEvent {
  @core.PointerEvent::new(
    position=self.position,
    phase=@core.PointerPhase::Move,
    wheel_delta=self.delta.to_logical_pixels(),
  )
}

///|
pub fn HostFocusEvent::new(
  focused~ : Bool,
  pointer_cancel_position? : @core.Point? = None,
) -> HostFocusEvent {
  { focused, pointer_cancel_position }
}

///|
pub fn HostFocusEvent::to_core(self : HostFocusEvent) -> @core.AppEvent? {
  match (self.focused, self.pointer_cancel_position) {
    (false, Some(position)) =>
      Some(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(position~, phase=@core.PointerPhase::Cancel),
        ),
      )
    _ => None
  }
}

///|
pub fn HostEvent::to_core(self : HostEvent) -> @core.AppEvent? {
  match self {
    Resized(metrics) => Some(@core.AppEvent::Resize(metrics.logical_size))
    Pointer(event) => Some(@core.AppEvent::Pointer(event))
    Scroll(event) => Some(@core.AppEvent::Pointer(event.to_pointer_event()))
    Focus(event) => event.to_core()
    Keyboard(event) => Some(@core.AppEvent::Keyboard(event))
    TextInput(event) => Some(@core.AppEvent::TextInput(event))
    DragDrop(event) => Some(@core.AppEvent::DragDrop(event))
    WebView(id, event) =>
      Some(@core.AppEvent::PlatformView(id, event.to_platform_event()))
    ThemeChanged(_) => None
    Command(_) => None
    RedrawRequested =>
      Some(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
    CloseRequested => Some(@core.AppEvent::CloseRequested)
  }
}
